import json
import io
import os
import sqlite3
import datetime
import pickle
import numpy as np
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, Depends, HTTPException, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
import pdfplumber
import spacy
from fastapi.responses import FileResponse
from nlp_service import nlp_service 

APP_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(APP_DIR, 'career.db')

# --- GLOBAL VARIABLES (RAM) ---
JOB_VECTORS = [] 
JOB_TITLES = {} # YENİ: Başlıkları hafızada tutacağız {job_id: "title"}
JOB_REQUIREMENTS_CACHE = {} 

# --- AUTH CONFIG ---
SECRET_KEY = "Syu0T/+4fEe7SPgWRDatwpQ1Gg4V7CNLkiyGqqnnaE/zqsfibUPcyWsTrIzqHHLJL"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- APP SETUP ---
app = FastAPI(title="Career AI Final Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- STARTUP: LOAD DATA ---
@app.on_event("startup")
def load_job_vectors():
    print(">>> [Startup] Loading Job Data (Vectors + Titles)...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    # Title bilgisini de çekiyoruz
    cursor.execute("SELECT job_id, vector_blob, requirements_json, title FROM jobs")
    rows = cursor.fetchall()
    
    global JOB_VECTORS
    global JOB_TITLES
    global JOB_REQUIREMENTS_CACHE
    
    JOB_VECTORS = []
    JOB_TITLES = {}
    JOB_REQUIREMENTS_CACHE = {}
    
    count = 0
    for row in rows:
        jid = row[0]
        blob = row[1]
        req_json = row[2]
        title = row[3]
        
        # 1. Vector
        if blob:
            try:
                vector = pickle.loads(blob)
                JOB_VECTORS.append((jid, vector))
                count += 1
            except: pass
        
        # 2. Requirements
        if req_json:
            try:
                JOB_REQUIREMENTS_CACHE[jid] = json.loads(req_json)
            except:
                JOB_REQUIREMENTS_CACHE[jid] = {}

        # 3. Titles (Lowercased for matching)
        if title:
            JOB_TITLES[jid] = title.lower().strip()

    conn.close()
    print(f">>> [Startup] Loaded {count} jobs. Ready.")

# --- DB HELPER ---
def get_db():
    db = None
    try:
        db = sqlite3.connect(DB_PATH, check_same_thread=False, timeout=15)
        db.row_factory = sqlite3.Row
        yield db
    except sqlite3.Error:
        raise HTTPException(status_code=500, detail="Database connection error.")
    finally:
        if db: db.close()

# --- MODELS ---
class Job(BaseModel):
    job_id: int 
    title: Optional[str] = None 
    location: Optional[str] = None
    description: Optional[str] = None
    company: Optional[str] = None
    employer_id: Optional[int] = None
    requirements: Optional[str] = None
    benefits: Optional[str] = None
    company_profile: Optional[str] = None
    is_favorite: Optional[bool] = False

class User(BaseModel):
    id: int
    email: str
    role: str

class UserCreate(BaseModel):
    email: str
    password: str
    role: str

class Token(BaseModel):
    access_token: str
    token_type: str

class JobCreate(BaseModel):
    title: str
    location: str
    description: str
    company: str

class RecommendedJob(Job):
    match_score: float
    matched_skills: List[str]
    missing_skills: List[str]

class ManualProfile(BaseModel):
    title: str
    skills: str 
    summary: str 

# --- AUTH HELPERS ---
def get_user_by_email(db, email):
    cur = db.cursor()
    cur.execute("SELECT * FROM users WHERE email = ?", (email,))
    row = cur.fetchone()
    if row: return User(id=row['id'], email=row['email'], role=row['role']), row['hashed_password']
    return None, None

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme), db: sqlite3.Connection = Depends(get_db)) -> User:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
    except JWTError: raise HTTPException(401, "Invalid token")
    user, _ = get_user_by_email(db, email)
    if not user: raise HTTPException(401, "User not found")
    return user

async def get_current_employer(u: User = Depends(get_current_user)):
    if u.role != "employer": raise HTTPException(403, "Employer access required")
    return u

# --- CORE LOGIC: ULTIMATE SCORING (Title + Semantic + Skill) ---
def _calculate_scores_fast(user_id: int, user_skills: list, raw_text: str, db_path: str):
    """
    1. Unvan Eşleşmesi (Varsa taban puan 0.70)
    2. Vektör + Skill (Sıralamayı belirler +0.30)
    """
    print(f"[Scoring] User {user_id} calculation started.")
    
    # A. Kullanıcının Unvanını Bul (Manual veya PDF'ten çıkarılmış)
    # Biz bunu user_profiles tablosuna 'manual_info' -> 'title' olarak kaydetmiştik.
    # Ancak burada raw_text yerine veritabanından çekmek daha temiz olurdu.
    # Yine de performans için raw_text içinden basitçe parse edebiliriz veya
    # upload sırasında "Job Title: X" formatını koruduğumuz için oradan çekebiliriz.
    
    user_title_tokens = set()
    raw_lower = raw_text.lower()
    
    # PDF veya Manual yüklemede "Job Title: ..." formatı eklemiştik.
    if "job title:" in raw_lower:
        try:
            # "job title: truck driver." -> "truck driver"
            extracted = raw_lower.split("job title:")[1].split(".")[0].split("\n")[0].strip()
            user_title_tokens = set(extracted.split())
        except: pass
    
    # B. Kullanıcı Vektörü
    if user_skills:
        # Prompt Engineering: Title ve Skill'i başa al
        title_str = " ".join(user_title_tokens) if user_title_tokens else ""
        user_input_text = f"{title_str} {title_str} {' '.join(user_skills)} {raw_text[:1000]}"
    else:
        user_input_text = raw_text[:5000]

    try:
        user_doc = nlp_service.nlp(user_input_text)
        user_vector = user_doc.vector
        user_norm = np.linalg.norm(user_vector)
    except:
        return 

    scores = []
    
    for job_id, job_vector in JOB_VECTORS:
        # 1. TITLE MATCH SCORE (Unvan Uyumu)
        title_score = 0.0
        job_title_str = JOB_TITLES.get(job_id, "")
        
        if user_title_tokens and job_title_str:
            job_tokens = set(job_title_str.split())
            intersection = user_title_tokens.intersection(job_tokens)
            if intersection:
                # Jaccard benzerliği
                union = user_title_tokens.union(job_tokens)
                if len(union) > 0:
                    title_score = len(intersection) / len(union)
        
        # 2. SKILL MATCH SCORE (Yetenek Uyumu)
        skill_score = 0.0
        if user_skills:
            reqs = JOB_REQUIREMENTS_CACHE.get(job_id, {})
            job_skills_set = set()
            if isinstance(reqs, dict):
                job_skills_set.update(reqs.get("must_have", []))
                job_skills_set.update(reqs.get("nice_to_have", []))
                job_skills_set.update(reqs.get("normal", []))
            elif isinstance(reqs, list):
                job_skills_set.update(reqs)
            
            if job_skills_set:
                user_matches = set(s.lower() for s in user_skills).intersection(set(js.lower() for js in job_skills_set))
                skill_score = len(user_matches) / len(job_skills_set)

        # 3. VECTOR MATCH SCORE (Anlamsal Uyum)
        vector_score = 0.0
        job_norm = np.linalg.norm(job_vector)
        if user_norm > 0 and job_norm > 0:
            vector_score = float(np.dot(user_vector, job_vector) / (user_norm * job_norm))
            vector_score = max(0.0, vector_score)

        # --- FİNAL FORMÜL ---
        
        # Senaryo 1: Unvan Tutuyor (Kapıdan Girdi)
        if title_score >= 0.33: # Örn: "Truck Driver" vs "Driver" (1/2 = 0.5) tutar
            # Taban Puan: 0.70
            # Sıralama Puanı: %20 Skill + %10 Vector
            # Böylece doğru ilanlar hep tepede olur, ama kendi aralarında yetenekli olan üste çıkar.
            base = 0.70
            final_score = base + (skill_score * 0.20) + (vector_score * 0.10)
            
            # Bonus: Tam unvan eşleşmesi varsa (Örn: Truck Driver == Truck Driver)
            if title_score > 0.8:
                final_score += 0.05
                
        # Senaryo 2: Unvan Tutmuyor ama Yetenekler Mükemmel
        elif skill_score > 0.4:
            # Standart Hibrit
            final_score = (skill_score * 0.60) + (vector_score * 0.40)
        
        # Senaryo 3: Hiçbiri yok (Sadece Vektör)
        else:
            final_score = (vector_score * 0.70) + (skill_score * 0.30)
            # Alakasızları cezalandır
            if final_score < 0.45: final_score = 0.0

        final_score = min(0.99, final_score)
        
        if final_score > 0.0:
            scores.append((user_id, job_id, final_score))
    
    # KAYDET
    scores.sort(key=lambda x: x[2], reverse=True)
    top_scores = scores[:5000]
    
    if top_scores:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM job_recommendation_scores WHERE user_id = ?", (user_id,))
        cursor.executemany("INSERT INTO job_recommendation_scores VALUES (?,?,?)", top_scores)
        conn.commit()
        conn.close()
        print(f"[Scoring] {len(top_scores)} matches saved.")

# --- ENDPOINTS ---

@app.post("/register", response_model=User, status_code=201)
async def register(u: UserCreate, db: sqlite3.Connection = Depends(get_db)):
    existing, _ = get_user_by_email(db, u.email)
    if existing: raise HTTPException(400, "Email taken")
    hashed = pwd_context.hash(u.password)
    cur = db.cursor()
    cur.execute("INSERT INTO users (email, hashed_password, role) VALUES (?,?,?)", (u.email, hashed, u.role))
    uid = cur.lastrowid
    cur.execute("INSERT INTO user_profiles (user_id, has_cv) VALUES (?, 0)", (uid,))
    db.commit()
    return User(id=uid, email=u.email, role=u.role)

@app.post("/token", response_model=Token)
async def login(form: OAuth2PasswordRequestForm = Depends(), db: sqlite3.Connection = Depends(get_db)):
    user, hashed = get_user_by_email(db, form.username)
    if not user or not pwd_context.verify(form.password, hashed):
        raise HTTPException(401, "Invalid credentials")
    return {"access_token": create_access_token({"sub": user.email}), "token_type": "bearer"}

@app.get("/users/me/", response_model=User)
async def read_users_me(u: User = Depends(get_current_user)): return u

# --- UPLOAD CV (METHOD 2: INFERENCE) ---
@app.post("/users/me/cv")
async def upload_cv(bg: BackgroundTasks, file: UploadFile = File(...), u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    if not file.filename.lower().endswith(".pdf"): raise HTTPException(400, "PDF only")
    content = await file.read()
    
    # 1. Extract Text
    text = ""
    with pdfplumber.open(io.BytesIO(content)) as pdf:
        for p in pdf.pages: 
            if p.extract_text(): text += p.extract_text() + "\n"
    
    # 2. NLP Analysis (Skills)
    analysis = nlp_service.analyze_text(text)
    user_skills = []
    if isinstance(analysis, list): user_skills = analysis
    elif isinstance(analysis, dict): user_skills = analysis.get("skills", [])
    
    # 3. TITLE INFERENCE (Yöntem 2)
    # Metnin içinde, veritabanımızdaki bilinen iş başlıkları geçiyor mu?
    inferred_title = "General"
    text_lower = text.lower()[:3000] # İlk 3000 karaktere bak (Header kısmı genelde buradadır)
    
    # En uzun başlıkları önce kontrol et (örn: "Senior Truck Driver" > "Driver")
    # JOB_TITLES values'larını al, unique yap, uzunluğa göre sırala
    known_titles = sorted(list(set(JOB_TITLES.values())), key=len, reverse=True)
    
    for t in known_titles:
        if len(t) > 3 and t in text_lower: # Çok kısa (örn: "it") kelimeleri atla
            inferred_title = t
            break # En uzun ve ilk bulduğunu al
            
    print(f"[Upload] User {u.id} inferred title: {inferred_title}")

    # 4. Prepare JSON Data (Manual Info formatında sakla ki scoring kullansın)
    final_data = {
        "skills": user_skills,
        "manual_info": {
            "title": inferred_title,  # Çıkarılan unvan
            "summary": "Extracted from PDF",
            "raw_skills": ", ".join(user_skills)
        }
    }
    js = json.dumps(final_data)
    
    # 5. Save DB
    cur = db.cursor()
    cur.execute("INSERT INTO user_profiles (user_id, has_cv, cv_analysis_json, last_updated) VALUES (?,1,?,?) ON CONFLICT(user_id) DO UPDATE SET has_cv=1, cv_analysis_json=excluded.cv_analysis_json, last_updated=excluded.last_updated", (u.id, js, datetime.datetime.now().isoformat()))
    db.commit()
    
    # 6. Start Scoring (Metne "Job Title: ..." ekleyerek gönderiyoruz)
    enriched_text = f"Job Title: {inferred_title}. \n {text}"
    bg.add_task(_calculate_scores_fast, u.id, user_skills, enriched_text, DB_PATH)
    
    return {"message": f"CV Uploaded. Detected Role: {inferred_title.title()}"}

@app.delete("/users/me/cv")
async def delete_my_cv(u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cv_filename = f"cv_{u.id}.pdf"
    cv_path = os.path.join(APP_DIR, "user_cvs", cv_filename)
    if os.path.exists(cv_path):
        try: os.remove(cv_path)
        except: pass
    cur.execute("UPDATE user_profiles SET has_cv=0, cv_analysis_json=NULL, last_updated=? WHERE user_id=?", (datetime.datetime.now().isoformat(), u.id))
    cur.execute("DELETE FROM job_recommendation_scores WHERE user_id=?", (u.id,))
    db.commit()
    return {"success": True, "message": "CV deleted successfully."}

@app.post("/users/me/profile_manual")
async def update_profile_manual(p: ManualProfile, bg: BackgroundTasks, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    # 1. Metin
    raw_text = (
        f"Job Title: {p.title}. "
        f"I am a professional {p.title}. "
        f"Skills: {p.skills}. "
        f"Summary: {p.summary} "
        f"{p.title} {p.title}" 
    )
    # 2. NLP
    analysis = nlp_service.analyze_text(raw_text)
    manual_skills = [s.strip() for s in p.skills.split(",") if s.strip()]
    final_skills = []
    if isinstance(analysis, list): final_skills = analysis + manual_skills
    elif isinstance(analysis, dict): final_skills = analysis.get("skills", []) + manual_skills
    final_skills = list(set(final_skills))

    # 3. Save JSON
    final_data = {
        "skills": final_skills,
        "manual_info": {
            "title": p.title,
            "summary": p.summary,
            "raw_skills": p.skills
        }
    }
    js = json.dumps(final_data)
    
    cur = db.cursor()
    cur.execute("INSERT INTO user_profiles (user_id, has_cv, cv_analysis_json, last_updated) VALUES (?, 2, ?, ?) ON CONFLICT(user_id) DO UPDATE SET has_cv=2, cv_analysis_json=excluded.cv_analysis_json, last_updated=excluded.last_updated", (u.id, js, datetime.datetime.now().isoformat()))
    db.commit()
    bg.add_task(_calculate_scores_fast, u.id, final_skills, raw_text, DB_PATH)
    return {"success": True, "message": "Profile updated manually."}

@app.get("/users/me/cv/status")
async def get_cv_status(u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT has_cv FROM user_profiles WHERE user_id=?", (u.id,))
    row = cur.fetchone()
    return {"has_cv": True if row and row['has_cv'] else False}

# --- JOB ENDPOINTS ---

@app.post("/jobs", response_model=Job, status_code=201)
async def create_job(j: JobCreate, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    combined_text = f"{j.title} {j.description}"
    reqs = nlp_service.analyze_job_description(combined_text)
    req_json = json.dumps(reqs)
    doc = nlp_service.nlp(combined_text)
    vector_blob = pickle.dumps(doc.vector)
    
    cur = db.cursor()
    cur.execute("INSERT INTO jobs (title, location, description, company, employer_id, requirements_json, vector_blob) VALUES (?,?,?,?,?,?,?)", (j.title, j.location, j.description, j.company, u.id, req_json, vector_blob))
    jid = cur.lastrowid
    db.commit()
    
    # Update Globals
    JOB_VECTORS.append((jid, doc.vector))
    JOB_REQUIREMENTS_CACHE[jid] = reqs
    JOB_TITLES[jid] = j.title.lower().strip() # YENİ
    
    return Job(job_id=jid, **j.model_dump(), employer_id=u.id, requirements=req_json)

@app.get("/jobs/recommended", response_model=List[RecommendedJob])
async def get_recommended_jobs(location: Optional[str] = None, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    
    # Yetenekleri çek (Arayüzde eşleşenleri göstermek için)
    cur.execute("SELECT cv_analysis_json FROM user_profiles WHERE user_id=?", (u.id,))
    prof = cur.fetchone()
    user_skills = set()
    if prof and prof['cv_analysis_json']:
        try:
            d = json.loads(prof['cv_analysis_json'])
            # Yapı değiştiği için kontrol et
            if 'skills' in d: user_skills = set(d['skills'])
            elif isinstance(d, list): user_skills = set(d)
        except: pass

    query = """
        SELECT j.*, s.match_score FROM job_recommendation_scores s
        JOIN jobs j ON s.job_id = j.job_id
        WHERE s.user_id = ?
    """
    params = [u.id]
    if location and location != "All":
        query += " AND j.location LIKE ?"
        params.append(f"%{location}%")
    query += " ORDER BY s.match_score DESC LIMIT 50"
    
    cur.execute(query, params)
    res = []
    for row in cur.fetchall():
        d = dict(row)
        job_skills = set()
        if d['requirements_json']:
            try:
                jd = json.loads(d['requirements_json'])
                if isinstance(jd, list): job_skills = set(jd)
                elif isinstance(jd, dict): 
                    job_skills.update(jd.get("must_have", []))
                    job_skills.update(jd.get("normal", []))
            except: pass
        res.append(RecommendedJob(**Job(**d).model_dump(), match_score=d['match_score'], matched_skills=sorted(list(user_skills & job_skills)), missing_skills=sorted(list(job_skills - user_skills))))
    return res

@app.get("/users/me/jobs", response_model=List[Job])
async def my_jobs(u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT * FROM jobs WHERE employer_id=? ORDER BY job_id DESC", (u.id,))
    res = []
    for r in cur.fetchall(): res.append(Job(**dict(r)))
    return res

@app.get("/jobs/{jid}", response_model=Job)
async def job_det(jid: int, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT * FROM jobs WHERE job_id=?", (jid,))
    r = cur.fetchone()
    if not r: raise HTTPException(404)
    job_data = dict(r)
    cur.execute("SELECT * FROM favorites WHERE user_id=? AND job_id=?", (u.id, jid))
    fav_row = cur.fetchone()
    job_data['is_favorite'] = True if fav_row else False
    return Job(**job_data)

@app.get("/jobs", response_model=List[RecommendedJob]) 
async def all_jobs(search: Optional[str]=None, page: int=1, size: int=20, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    off = (page-1)*size
    base_query = "SELECT j.*, s.match_score FROM jobs j LEFT JOIN job_recommendation_scores s ON j.job_id = s.job_id AND s.user_id = ?"
    params = [u.id]
    if search:
        base_query += " WHERE j.title LIKE ?"
        params.append(f"%{search}%")
    base_query += " ORDER BY j.job_id DESC LIMIT ? OFFSET ?"
    params.extend([size, off])
    cur.execute(base_query, params)
    res = []
    for row in cur.fetchall():
        d = dict(row)
        if 'job_id' in d: d['job_id'] = d['job_id'] 
        if d['match_score'] is None: d['match_score'] = 0.0
        job_data = Job(**d).model_dump()
        job_data['match_score'] = d['match_score']
        job_data['matched_skills'] = []
        job_data['missing_skills'] = []
        res.append(RecommendedJob(**job_data))
    return res

@app.post("/jobs/{job_id}/apply")
async def apply_for_job(job_id: int, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT * FROM applications WHERE user_id=? AND job_id=?", (u.id, job_id))
    if cur.fetchone(): raise HTTPException(status_code=400, detail="Already applied to this job.")
    try:
        cur.execute("INSERT INTO applications (user_id, job_id, application_date) VALUES (?, ?, ?)", (u.id, job_id, datetime.datetime.now().isoformat()))
        db.commit()
        return {"message": "Application successful"}
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))

@app.get("/jobs/{job_id}/applicants")
async def get_job_applicants(job_id: int, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT employer_id FROM jobs WHERE job_id=?", (job_id,))
    job = cur.fetchone()
    if not job or job['employer_id'] != u.id: raise HTTPException(status_code=403, detail="Not authorized.")
    
    query = """
        SELECT u.id as user_id, u.email, app.application_date, s.match_score, up.has_cv, up.cv_analysis_json
        FROM applications app
        JOIN users u ON app.user_id = u.id
        LEFT JOIN job_recommendation_scores s ON s.user_id = u.id AND s.job_id = app.job_id
        LEFT JOIN user_profiles up ON up.user_id = u.id
        WHERE app.job_id = ?
        ORDER BY s.match_score DESC
    """
    cur.execute(query, (job_id,))
    applicants = []
    for row in cur.fetchall():
        d = dict(row)
        if d['match_score'] is None: d['match_score'] = 0.0
        if d['cv_analysis_json']:
            try: d['profile_data'] = json.loads(d['cv_analysis_json'])
            except: d['profile_data'] = {}
        else: d['profile_data'] = {}
        if 'cv_analysis_json' in d: del d['cv_analysis_json']
        applicants.append(d)
    return applicants

@app.get("/users/{user_id}/cv_download")
async def download_user_cv(user_id: int, u: User = Depends(get_current_user)):
    cv_filename = f"cv_{user_id}.pdf"
    cv_path = os.path.join(APP_DIR, "user_cvs", cv_filename) 
    if os.path.exists(cv_path): return FileResponse(cv_path, media_type='application/pdf', filename=cv_filename)
    else: raise HTTPException(status_code=404, detail="CV file not found.")

@app.delete("/jobs/{job_id}")
async def delete_job(job_id: int, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT employer_id FROM jobs WHERE job_id=?", (job_id,))
    row = cur.fetchone()
    if not row or row['employer_id'] != u.id: raise HTTPException(status_code=403, detail="Not authorized.")
    cur.execute("DELETE FROM applications WHERE job_id=?", (job_id,))
    cur.execute("DELETE FROM job_recommendation_scores WHERE job_id=?", (job_id,))
    cur.execute("DELETE FROM favorites WHERE job_id=?", (job_id,))
    cur.execute("DELETE FROM jobs WHERE job_id=?", (job_id,))
    db.commit()
    
    global JOB_VECTORS, JOB_REQUIREMENTS_CACHE, JOB_TITLES
    JOB_VECTORS = [v for v in JOB_VECTORS if v[0] != job_id]
    if job_id in JOB_REQUIREMENTS_CACHE: del JOB_REQUIREMENTS_CACHE[job_id]
    if job_id in JOB_TITLES: del JOB_TITLES[job_id]
        
    return {"success": True, "message": "Job deleted"}

@app.put("/jobs/{job_id}")
async def update_job(job_id: int, j: JobCreate, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT employer_id FROM jobs WHERE job_id=?", (job_id,))
    row = cur.fetchone()
    if not row or row['employer_id'] != u.id: raise HTTPException(status_code=403, detail="Not authorized.")
    combined_text = f"{j.title} {j.description}"
    reqs = nlp_service.analyze_job_description(combined_text)
    req_json = json.dumps(reqs)
    doc = nlp_service.nlp(combined_text)
    vector_blob = pickle.dumps(doc.vector)
    cur.execute("UPDATE jobs SET title=?, location=?, description=?, company=?, requirements_json=?, vector_blob=? WHERE job_id=?", (j.title, j.location, j.description, j.company, req_json, vector_blob, job_id))
    db.commit()
    
    global JOB_VECTORS, JOB_REQUIREMENTS_CACHE, JOB_TITLES
    JOB_VECTORS = [v for v in JOB_VECTORS if v[0] != job_id]
    JOB_VECTORS.append((job_id, doc.vector))
    JOB_REQUIREMENTS_CACHE[job_id] = reqs
    JOB_TITLES[job_id] = j.title.lower().strip() # YENİ
    
    return {"success": True, "message": "Job updated"}

@app.post("/jobs/{job_id}/favorite")
async def toggle_favorite(job_id: int, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT * FROM favorites WHERE user_id=? AND job_id=?", (u.id, job_id))
    row = cur.fetchone()
    if row:
        cur.execute("DELETE FROM favorites WHERE user_id=? AND job_id=?", (u.id, job_id))
        db.commit()
        return {"success": True, "message": "Removed from favorites", "is_favorite": False}
    else:
        cur.execute("INSERT INTO favorites (user_id, job_id) VALUES (?, ?)", (u.id, job_id))
        db.commit()
        return {"success": True, "message": "Added to favorites", "is_favorite": True}

@app.get("/me/favorites", response_model=List[Job])
async def get_my_favorites(u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT j.* FROM favorites f JOIN jobs j ON f.job_id = j.job_id WHERE f.user_id = ? ORDER BY f.id DESC", (u.id,))
    res = []
    for row in cur.fetchall(): res.append(Job(**dict(row)))
    return res

@app.get("/me/applications", response_model=List[Job])
async def get_my_applications(u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT j.* FROM applications a JOIN jobs j ON a.job_id = j.job_id WHERE a.user_id = ? ORDER BY a.application_date DESC", (u.id,))
    res = []
    for row in cur.fetchall(): res.append(Job(**dict(row)))
    return res