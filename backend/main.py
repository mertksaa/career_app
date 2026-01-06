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

# --- GLOBAL VECTOR CACHE (RAM) ---
JOB_VECTORS = [] 
JOB_REQUIREMENTS_CACHE = {} 

# --- AUTH CONFIG ---
SECRET_KEY = "Syu0T/+4fEe7SPgWRDatwpQ1Gg4V7CNLkiyGqqnnaE/zqsfibUPcyWsTrIzqHHLJL"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- APP SETUP ---
app = FastAPI(title="Career AI Professional Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- STARTUP: LOAD VECTORS ---
@app.on_event("startup")
def load_job_vectors():
    print(">>> [Startup] İş vektörleri RAM'e yükleniyor...")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT job_id, vector_blob, requirements_json FROM jobs")
    rows = cursor.fetchall()
    
    global JOB_VECTORS
    global JOB_REQUIREMENTS_CACHE
    JOB_VECTORS = []
    JOB_REQUIREMENTS_CACHE = {}
    
    count = 0
    for row in rows:
        jid = row[0]
        blob = row[1]
        req_json = row[2]
        
        if blob:
            try:
                vector = pickle.loads(blob)
                JOB_VECTORS.append((jid, vector))
                count += 1
            except: pass
        
        if req_json:
            try:
                JOB_REQUIREMENTS_CACHE[jid] = json.loads(req_json)
            except:
                JOB_REQUIREMENTS_CACHE[jid] = {}

    conn.close()
    print(f">>> [Startup] {count} adet iş vektörü RAM'e yüklendi. Hızlı aramaya hazır.")

# --- DB ---
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
# Frontend ile uyumlu olması için job_id kullanıyoruz (id yerine)
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

# --- HELPERS ---
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

# --- CORE LOGIC: FAST SCORING (DÜZELTİLDİ) ---
def _calculate_scores_fast(user_id: int, user_skills: list, raw_text: str, db_path: str):
    """
    In-Memory Vector Search. Yetenek bulamazsa raw_text kullanır.
    """
    print(f"[Scoring] Kullanıcı {user_id} için HIZLI hesaplama başladı. Yetenekler: {len(user_skills)}.")
    
    # 1. Kullanıcı Vektörü (Yetenek yoksa metni kullan)
    if user_skills:
        user_input_text = " ".join(user_skills)
    else:
        print("[Scoring] Yetenek listesi boş. Tüm CV metni kullanılarak vektör oluşturuluyor...")
        user_input_text = raw_text[:5000] # Çok uzun metinleri kırp

    try:
        user_doc = nlp_service.nlp(user_input_text)
        user_vector = user_doc.vector
    except:
        print("[Scoring] Vektör oluşturma hatası.")
        return 

    # 2. Vektör Benzerliği
    scores = []
    user_norm = np.linalg.norm(user_vector)
    if user_norm == 0: 
        print("[Scoring] Kullanıcı vektörü sıfır. Hesaplama yapılamıyor.")
        return

    for job_id, job_vector in JOB_VECTORS:
        job_norm = np.linalg.norm(job_vector)
        if job_norm == 0: continue
        
        dot_product = np.dot(user_vector, job_vector)
        similarity = dot_product / (user_norm * job_norm)
        
        # Skill Bonus (Sadece yetenek varsa hesaplanır)
        skill_bonus = 0.0
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
                user_skills_set = set(s.lower() for s in user_skills)
                matches = 0
                for js in job_skills_set:
                    if js.lower() in user_skills_set: matches += 1
                skill_bonus = matches / len(job_skills_set)
        
# Eğer yetenek yoksa sadece vektör benzerliğine güven
        if not user_skills:
            final_score = float(similarity)
        else:
            sim_val = max(0.0, float(similarity))
            final_score = (sim_val * 0.70) + (skill_bonus * 0.30)
        
        # --- DÜZELTME: TEST İÇİN BARAJI KALDIRDIK ---
        # 0.0 ve üzeri her şeyi kaydet ki düşük puanları da görelim.
        if final_score >= 0.0: 
            scores.append((user_id, job_id, final_score))
    
    # 3. Kaydet
    scores.sort(key=lambda x: x[2], reverse=True)
    top_scores = scores[:100]
    
    if top_scores:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM job_recommendation_scores WHERE user_id = ?", (user_id,))
        cursor.executemany("INSERT INTO job_recommendation_scores VALUES (?,?,?)", top_scores)
        conn.commit()
        conn.close()
        print(f"[Scoring] {len(top_scores)} adet eşleşme başarıyla kaydedildi.")
    else:
        print("[Scoring] Eşik değeri (%15) geçen ilan bulunamadı.")

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

@app.post("/users/me/cv")
async def upload_cv(bg: BackgroundTasks, file: UploadFile = File(...), u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    if not file.filename.lower().endswith(".pdf"): raise HTTPException(400, "PDF only")
    content = await file.read()
    
    text = ""
    with pdfplumber.open(io.BytesIO(content)) as pdf:
        for p in pdf.pages: 
            if p.extract_text(): text += p.extract_text() + "\n"
    
    analysis = nlp_service.analyze_text(text)
    
    # Hata önleyici kontrol
    user_skills = []
    if isinstance(analysis, list):
        user_skills = analysis
    elif isinstance(analysis, dict):
        user_skills = analysis.get("skills", [])

    js = json.dumps(analysis)
    
    cur = db.cursor()
    cur.execute("INSERT INTO user_profiles (user_id, has_cv, cv_analysis_json, last_updated) VALUES (?,1,?,?) ON CONFLICT(user_id) DO UPDATE SET has_cv=1, cv_analysis_json=excluded.cv_analysis_json", (u.id, js, datetime.datetime.now().isoformat()))
    db.commit()
    
    # Text'i de gönderiyoruz ki yetenek yoksa fallback yapsın
    bg.add_task(_calculate_scores_fast, u.id, user_skills, text, DB_PATH)
    
    return {"message": "CV Uploaded & Analyzing"}

@app.get("/users/me/cv/status")
async def get_cv_status(u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT has_cv FROM user_profiles WHERE user_id=?", (u.id,))
    row = cur.fetchone()
    return {"has_cv": True if row and row['has_cv'] else False}

@app.post("/jobs", response_model=Job, status_code=201)
async def create_job(j: JobCreate, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    combined_text = f"{j.title} {j.description}"
    reqs = nlp_service.analyze_job_description(combined_text)
    req_json = json.dumps(reqs)
    
    doc = nlp_service.nlp(combined_text)
    vector_blob = pickle.dumps(doc.vector)
    
    cur = db.cursor()
    cur.execute("INSERT INTO jobs (title, location, description, company, employer_id, requirements_json, vector_blob) VALUES (?,?,?,?,?,?,?)",
                (j.title, j.location, j.description, j.company, u.id, req_json, vector_blob))
    jid = cur.lastrowid
    db.commit()
    
    JOB_VECTORS.append((jid, doc.vector))
    JOB_REQUIREMENTS_CACHE[jid] = reqs
    
    return Job(job_id=jid, **j.model_dump(), employer_id=u.id, requirements=req_json)

@app.get("/jobs/recommended", response_model=List[RecommendedJob])
async def get_recommended_jobs(
    location: Optional[str] = None, # <-- Yeni Parametre
    u: User = Depends(get_current_user), 
    db: sqlite3.Connection = Depends(get_db)
):
    cur = db.cursor()
    
    # 1. Kullanıcı profili ve yeteneklerini çek (Eşleşen yetenekleri göstermek için)
    cur.execute("SELECT cv_analysis_json FROM user_profiles WHERE user_id=?", (u.id,))
    prof = cur.fetchone()
    user_skills = set()
    if prof and prof['cv_analysis_json']:
        try:
            d = json.loads(prof['cv_analysis_json'])
            if isinstance(d, list): user_skills = set(d)
            elif isinstance(d, dict): user_skills = set(d.get("skills", []))
        except: pass

    # 2. SQL Sorgusu (Filtreli)
    query = """
        SELECT j.*, s.match_score FROM job_recommendation_scores s
        JOIN jobs j ON s.job_id = j.job_id
        WHERE s.user_id = ?
    """
    params = [u.id]

    # Eğer lokasyon filtresi varsa sorguya ekle
    if location and location != "All":
        query += " AND j.location LIKE ?"
        params.append(f"%{location}%")
    
    query += " ORDER BY s.match_score DESC LIMIT 50"
    
    cur.execute(query, params)
    
    res = []
    for row in cur.fetchall():
        d = dict(row)
        # Mapping gerek yok, Pydantic halleder (job_id)
        
        # Skill Diff (Eksik/Eşleşen yetenek hesaplama)
        job_skills = set()
        if d['requirements_json']:
            try:
                jd = json.loads(d['requirements_json'])
                if isinstance(jd, list): job_skills = set(jd)
                elif isinstance(jd, dict): 
                    job_skills.update(jd.get("must_have", []))
                    job_skills.update(jd.get("normal", []))
            except: pass
            
        res.append(RecommendedJob(
            **Job(**d).model_dump(),
            match_score=d['match_score'],
            matched_skills=sorted(list(user_skills & job_skills)),
            missing_skills=sorted(list(job_skills - user_skills))
        ))
    return res

@app.get("/users/me/jobs", response_model=List[Job])
async def my_jobs(u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    cur.execute("SELECT * FROM jobs WHERE employer_id=? ORDER BY job_id DESC", (u.id,))
    res = []
    for r in cur.fetchall():
        # Mapping YOK.
        res.append(Job(**dict(r)))
    return res

@app.get("/jobs/{jid}", response_model=Job)
async def job_det(jid: int, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    
    # 1. İlanı Çek
    cur.execute("SELECT * FROM jobs WHERE job_id=?", (jid,))
    r = cur.fetchone()
    if not r: raise HTTPException(404)
    job_data = dict(r)
    
    # 2. Favori mi diye kontrol et
    cur.execute("SELECT * FROM favorites WHERE user_id=? AND job_id=?", (u.id, jid))
    fav_row = cur.fetchone()
    
    # 3. Veriyi birleştir
    job_data['is_favorite'] = True if fav_row else False
    
    return Job(**job_data)

@app.get("/jobs", response_model=List[RecommendedJob]) # Return Type değişti
async def all_jobs(search: Optional[str]=None, page: int=1, size: int=20, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    off = (page-1)*size
    
    # SQL SORGUSU DEĞİŞTİ: Left Join ile skorları da çekiyoruz
    base_query = """
        SELECT j.*, s.match_score 
        FROM jobs j
        LEFT JOIN job_recommendation_scores s ON j.job_id = s.job_id AND s.user_id = ?
    """
    
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
        # ID Mapping
        if 'job_id' in d:
            d['job_id'] = d['job_id'] # Pydantic modelindeki isimlendirme
            
        # Eğer skor yoksa (NULL ise) 0.0 ata
        if d['match_score'] is None:
            d['match_score'] = 0.0
            
        # Skills (Boş gönderebiliriz, listede detay gerekmiyor)
        d['matched_skills'] = []
        d['missing_skills'] = []
        
        # Mapping işlemi
        job_data = Job(**d).model_dump()
        job_data['match_score'] = d['match_score']
        job_data['matched_skills'] = []
        job_data['missing_skills'] = []
        
        res.append(RecommendedJob(**job_data))
        
    return res

@app.post("/jobs/{job_id}/apply")
async def apply_for_job(job_id: int, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    """İş arayanın ilana başvurmasını sağlar."""
    cur = db.cursor()
    
    # 1. Zaten başvurdu mu?
    cur.execute("SELECT * FROM applications WHERE user_id=? AND job_id=?", (u.id, job_id))
    if cur.fetchone():
        raise HTTPException(status_code=400, detail="Already applied to this job.")
    
    # 2. Kaydet
    try:
        cur.execute(
            "INSERT INTO applications (user_id, job_id, application_date) VALUES (?, ?, ?)",
            (u.id, job_id, datetime.datetime.now().isoformat())
        )
        db.commit()
        return {"message": "Application successful"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/jobs/{job_id}/applicants")
async def get_job_applicants(job_id: int, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    """İşverenin, kendi ilanına başvuranları ve uyum skorlarını görmesini sağlar."""
    cur = db.cursor()
    
    # 1. Bu ilan gerçekten bu işverenin mi?
    cur.execute("SELECT employer_id FROM jobs WHERE job_id=?", (job_id,))
    job = cur.fetchone()
    if not job or job['employer_id'] != u.id:
        raise HTTPException(status_code=403, detail="Not authorized for this job.")
    
    # 2. Başvuranları, profillerini ve skorlarını çek (JOIN şov)
    query = """
        SELECT 
            u.id as user_id, 
            u.email, 
            app.application_date,
            s.match_score
        FROM applications app
        JOIN users u ON app.user_id = u.id
        LEFT JOIN job_recommendation_scores s ON s.user_id = u.id AND s.job_id = app.job_id
        WHERE app.job_id = ?
        ORDER BY s.match_score DESC
    """
    cur.execute(query, (job_id,))
    
    applicants = []
    for row in cur.fetchall():
        d = dict(row)
        # Skor yoksa 0 ata
        if d['match_score'] is None: d['match_score'] = 0.0
        applicants.append(d)
        
    return applicants

@app.get("/users/{user_id}/cv_download")
async def download_user_cv(user_id: int, u: User = Depends(get_current_user)):
    """CV PDF dosyasını indirir."""
    # Güvenlik: Sadece işverenler veya kullanıcının kendisi indirebilir (Basitlik için şimdilik açık)
    
    cv_filename = f"cv_{user_id}.pdf"
    # APP_DIR burada main.py'nin olduğu klasör
    cv_path = os.path.join(APP_DIR, "user_cvs", cv_filename) # user_cvs klasörü backend içinde olmalı
    
    # Eğer user_cvs ana dizindeyse ve main.py backend içindeyse path'i ayarla
    # Bizim yapımızda 'cv_path' upload_cv fonksiyonunda nasıl kaydedildiyse öyle okunmalı.
    # upload_cv içinde: os.path.join(APP_DIR, "user_cvs", cv_filename) kullanmıştık.
    # Eğer o klasör yoksa hata döner.
    
    if os.path.exists(cv_path):
        return FileResponse(cv_path, media_type='application/pdf', filename=cv_filename)
    else:
        raise HTTPException(status_code=404, detail="CV file not found.")

@app.delete("/jobs/{job_id}")
async def delete_job(job_id: int, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    """İlanı siler ve RAM'deki vektör listesinden kaldırır."""
    cur = db.cursor()
    
    # 1. İlan bu işverenin mi?
    cur.execute("SELECT employer_id FROM jobs WHERE job_id=?", (job_id,))
    row = cur.fetchone()
    if not row or row['employer_id'] != u.id:
        raise HTTPException(status_code=403, detail="Not authorized.")
    
    # 2. İlişkili verileri sil (Önce child tablolar)
    cur.execute("DELETE FROM applications WHERE job_id=?", (job_id,))
    cur.execute("DELETE FROM job_recommendation_scores WHERE job_id=?", (job_id,))
    cur.execute("DELETE FROM favorites WHERE job_id=?", (job_id,))
    
    # 3. İlanı sil
    cur.execute("DELETE FROM jobs WHERE job_id=?", (job_id,))
    db.commit()
    
    # 4. RAM Cache'den Sil (Hızlı Arama İçin)
    global JOB_VECTORS
    global JOB_REQUIREMENTS_CACHE
    # List comprehension ile o ID'yi listeden atıyoruz
    JOB_VECTORS = [v for v in JOB_VECTORS if v[0] != job_id]
    if job_id in JOB_REQUIREMENTS_CACHE:
        del JOB_REQUIREMENTS_CACHE[job_id]
        
    return {"success": True, "message": "Job deleted"}

@app.put("/jobs/{job_id}")
async def update_job(job_id: int, j: JobCreate, u: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    """İlanı günceller ve NLP vektörünü yeniden hesaplar."""
    cur = db.cursor()
    
    # 1. Yetki Kontrolü
    cur.execute("SELECT employer_id FROM jobs WHERE job_id=?", (job_id,))
    row = cur.fetchone()
    if not row or row['employer_id'] != u.id:
        raise HTTPException(status_code=403, detail="Not authorized.")
    
    # 2. Yeni Metin Analizi (NLP)
    combined_text = f"{j.title} {j.description}"
    
    # Gereksinimleri Çıkar
    reqs = nlp_service.analyze_job_description(combined_text)
    req_json = json.dumps(reqs)
    
    # Vektörü Hesapla
    doc = nlp_service.nlp(combined_text)
    vector_blob = pickle.dumps(doc.vector)
    
    # 3. DB Güncelle
    cur.execute("""
        UPDATE jobs 
        SET title=?, location=?, description=?, company=?, requirements_json=?, vector_blob=?
        WHERE job_id=?
    """, (j.title, j.location, j.description, j.company, req_json, vector_blob, job_id))
    db.commit()
    
    # 4. RAM Cache Güncelle (Eskisini sil, yenisini ekle)
    global JOB_VECTORS
    global JOB_REQUIREMENTS_CACHE
    
    # Önce RAM'den eskisini çıkar
    JOB_VECTORS = [v for v in JOB_VECTORS if v[0] != job_id]
    # Yenisini ekle
    JOB_VECTORS.append((job_id, doc.vector))
    JOB_REQUIREMENTS_CACHE[job_id] = reqs
    
    return {"success": True, "message": "Job updated"}

@app.post("/jobs/{job_id}/favorite")
async def toggle_favorite(job_id: int, u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    # Önce var mı bak
    cur.execute("SELECT * FROM favorites WHERE user_id=? AND job_id=?", (u.id, job_id))
    row = cur.fetchone()
    
    if row:
        # Varsa sil (Favoriden çıkar)
        cur.execute("DELETE FROM favorites WHERE user_id=? AND job_id=?", (u.id, job_id))
        db.commit()
        return {"success": True, "message": "Removed from favorites", "is_favorite": False}
    else:
        # Yoksa ekle
        cur.execute("INSERT INTO favorites (user_id, job_id) VALUES (?, ?)", (u.id, job_id))
        db.commit()
        return {"success": True, "message": "Added to favorites", "is_favorite": True}

# 2. Favorilerimi Getir
@app.get("/me/favorites", response_model=List[Job])
async def get_my_favorites(u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    # Favoriler tablosu ile Jobs tablosunu birleştir
    cur.execute("""
        SELECT j.* FROM favorites f
        JOIN jobs j ON f.job_id = j.job_id
        WHERE f.user_id = ?
        ORDER BY f.id DESC
    """, (u.id,))
    
    res = []
    for row in cur.fetchall():
        res.append(Job(**dict(row)))
    return res

# 3. Başvurularımı Getir
@app.get("/me/applications", response_model=List[Job])
async def get_my_applications(u: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cur = db.cursor()
    # Applications tablosu ile Jobs tablosunu birleştir
    cur.execute("""
        SELECT j.* FROM applications a
        JOIN jobs j ON a.job_id = j.job_id
        WHERE a.user_id = ?
        ORDER BY a.application_date DESC
    """, (u.id,))
    
    res = []
    for row in cur.fetchall():
        res.append(Job(**dict(row)))
    return res