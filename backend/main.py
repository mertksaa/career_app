import json
import io
import os
import sqlite3
import datetime
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File, Depends, HTTPException, status, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
import pdfplumber
import spacy
from fastapi.responses import FileResponse
import mimetypes

# --- YENİ IMPORT: Class tabanlı servis ---
from nlp_service import nlp_service 

APP_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(APP_DIR, 'career.db')

# --- 0. DATABASE INITIALIZATION (TABLOLARI OLUŞTURMA) ---
def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Users Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        hashed_password TEXT NOT NULL,
        role TEXT NOT NULL
    )
    """)
    
    # User Profiles Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_profiles (
        user_id INTEGER PRIMARY KEY,
        has_cv INTEGER DEFAULT 0,
        cv_analysis_json TEXT,
        last_updated TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )
    """)
    
    # Jobs Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS jobs (
        job_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        location TEXT,
        description TEXT,
        company TEXT,
        employer_id INTEGER,
        requirements_json TEXT,
        benefits TEXT,
        company_profile TEXT,
        FOREIGN KEY(employer_id) REFERENCES users(id)
    )
    """)
    
    # Applications Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS applications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        job_id INTEGER,
        application_date TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(job_id) REFERENCES jobs(job_id)
    )
    """)
    
    # Favorites Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        job_id INTEGER,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(job_id) REFERENCES jobs(job_id)
    )
    """)
    
    # Scores Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS job_recommendation_scores (
        user_id INTEGER,
        job_id INTEGER,
        match_score REAL,
        PRIMARY KEY (user_id, job_id),
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(job_id) REFERENCES jobs(job_id)
    )
    """)
    
    conn.commit()
    conn.close()
    print("Database initialized successfully.")

# Uygulama başlamadan DB'yi kontrol et
init_db()

# --- 1. AUTH CONFIG ---
SECRET_KEY = "Syu0T/+4fEe7SPgWRDatwpQ1Gg4V7CNLkiyGqqnnaE/zqsfibUPcyWsTrIzqHHLJL"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- 2. DB CONNECTION ---
def get_db():
    db = None
    try:
        db = sqlite3.connect(DB_PATH, check_same_thread=False, timeout=15)
        db.row_factory = sqlite3.Row
        yield db
    except sqlite3.Error as e:
        print(f"!!! DB Error (get_db): {e}")
        raise HTTPException(status_code=500, detail="Database connection error.")
    finally:
        if db:
            db.close()

# --- 3. PYDANTIC MODELS ---
class User(BaseModel):
    id: int
    email: str
    role: str

class UserCreate(BaseModel):
    email: str
    password: str
    role: str

class UserInDB(User):
    hashed_password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class Job(BaseModel):
    job_id: int
    title: Optional[str] = None 
    location: Optional[str] = None
    description: Optional[str] = None
    company: Optional[str] = None
    employer_id: Optional[int] = None
    requirements: Optional[str] = None
    benefits: Optional[str] = None

class JobCreate(BaseModel):
    title: str
    location: str
    description: str
    company: str

class Applicant(BaseModel):
    user_id: int
    email: str
    application_date: str
    has_cv: bool

class RecommendedJob(Job):
    match_score: float
    matched_skills: List[str]
    missing_skills: List[str]

class SkillAnalysisResponse(BaseModel):
    match_score: float
    matched_skills: List[str]
    missing_skills: List[str]
    user_skills_found: bool
    job_skills_found: bool  

# --- 4. AUTH HELPERS ---
def get_user_by_email(db: sqlite3.Connection, email: str) -> Optional[UserInDB]:
    cursor = db.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    user_row = cursor.fetchone()
    if user_row:
        return UserInDB(**user_row)
    return None

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[datetime.timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.datetime.now(datetime.timezone.utc) + expires_delta
    else:
        expire = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme), db: sqlite3.Connection = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = get_user_by_email(db, email=email)
    if user is None:
        raise credentials_exception
    return User(id=user.id, email=user.email, role=user.role)

async def get_current_employer(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "employer":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Employer privileges required.")
    return current_user

# --- 5. APP SETUP ---
app = FastAPI(title="Career AI Backend")

# spaCy load check (optional, handled in service)
try:
    nlp = spacy.load("en_core_web_md")
    print("--- spaCy 'en_core_web_md' loaded successfully. ---")
except IOError:
    print("--- WARNING: 'en_core_web_md' not found. ---")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 6. HİBRİT SKOR HESAPLAMA (Final Model) ---
def calculate_hybrid_match(user_doc, job_doc, user_skills: list, job_requirements: dict) -> float:
    # 1. Vector Similarity (%70 weight)
    vector_score = float(user_doc.similarity(job_doc))
    if vector_score < 0: vector_score = 0.0

    # 2. Skill Match (%30 weight)
    skill_score = 0.0
    
    must_have = []
    nice_to_have = []
    normal = []
    
    if isinstance(job_requirements, list):
        normal = job_requirements
    elif isinstance(job_requirements, dict):
        must_have = job_requirements.get("must_have", [])
        nice_to_have = job_requirements.get("nice_to_have", [])
        normal = job_requirements.get("normal", [])
        
    all_job_skills = set(must_have + nice_to_have + normal)
    
    if all_job_skills:
        user_skill_set = set(s.lower() for s in user_skills)
        current_points = 0.0
        max_points = 0.0
        
        for s in must_have:
            max_points += 3.0
            if s.lower() in user_skill_set: current_points += 3.0
            
        for s in normal:
            max_points += 1.0
            if s.lower() in user_skill_set: current_points += 1.0
            
        for s in nice_to_have:
            max_points += 0.5
            if s.lower() in user_skill_set: current_points += 0.5
            
        if max_points > 0:
            skill_score = current_points / max_points
    else:
        skill_score = vector_score

    # 3. Final Weighted Score
    final_score = (vector_score * 0.70) + (skill_score * 0.30)
    return final_score

# --- 7. BACKGROUND TASKS ---
def _recalculate_scores_for_user(user_id: int, db_path: str):
    print(f"[Background] Scoring started for User {user_id}...")
    db = None
    try:
        db = sqlite3.connect(db_path, check_same_thread=False, timeout=15)
        db.row_factory = sqlite3.Row
        cursor = db.cursor()

        cursor.execute("SELECT cv_analysis_json FROM user_profiles WHERE user_id = ?", (user_id,))
        user_profile = cursor.fetchone()
        
        if not user_profile or not user_profile['cv_analysis_json']: return

        user_skills_data = json.loads(user_profile['cv_analysis_json'])
        user_skills_list = user_skills_data.get("skills", [])
        
        user_text_for_vector = " ".join(user_skills_list)
        if not user_text_for_vector: return
        user_doc = nlp(user_text_for_vector)

        cursor.execute("SELECT job_id, title, description, requirements_json FROM jobs")
        all_jobs = cursor.fetchall()
        
        scores_to_insert = []
        
        for job_row in all_jobs:
            try:
                job_full_text = f"{job_row['title']} {job_row['description']}"
                job_doc = nlp(job_full_text)
                
                job_requirements = {}
                if job_row['requirements_json']:
                    job_requirements = json.loads(job_row['requirements_json'])
                
                final_score = calculate_hybrid_match(user_doc, job_doc, user_skills_list, job_requirements)
                
                if final_score > 0.15:
                    scores_to_insert.append((user_id, job_row['job_id'], final_score))
            except Exception:
                continue
        
        if scores_to_insert:
            cursor.execute("DELETE FROM job_recommendation_scores WHERE user_id = ?", (user_id,))
            cursor.executemany("INSERT INTO job_recommendation_scores (user_id, job_id, match_score) VALUES (?, ?, ?)", scores_to_insert)
            db.commit()
        
        print(f"[Background] User {user_id} scoring completed.")

    except Exception as e:
        print(f"[Background] Error: {e}")
        if db: db.rollback()
    finally:
        if db: db.close()

def _recalculate_scores_for_job(job_id: int, db_path: str):
    print(f"[Background] Scoring started for Job {job_id}...")
    db = None
    try:
        db = sqlite3.connect(db_path, check_same_thread=False, timeout=15)
        db.row_factory = sqlite3.Row
        cursor = db.cursor()

        cursor.execute("SELECT title, description, requirements_json FROM jobs WHERE job_id = ?", (job_id,))
        job_row = cursor.fetchone()
        if not job_row: return

        job_full_text = f"{job_row['title']} {job_row['description']}"
        job_doc = nlp(job_full_text)
        
        job_requirements = {}
        if job_row['requirements_json']:
            job_requirements = json.loads(job_row['requirements_json'])

        cursor.execute("SELECT user_id, cv_analysis_json FROM user_profiles WHERE has_cv = 1")
        all_user_profiles = cursor.fetchall()
        
        scores_to_insert = []
        
        for user_profile in all_user_profiles:
            try:
                if not user_profile['cv_analysis_json']: continue
                user_skills_data = json.loads(user_profile['cv_analysis_json'])
                user_skills_list = user_skills_data.get("skills", [])
                
                user_text_for_vector = " ".join(user_skills_list)
                if not user_text_for_vector: continue
                user_doc = nlp(user_text_for_vector)
                
                final_score = calculate_hybrid_match(user_doc, job_doc, user_skills_list, job_requirements)
                
                if final_score > 0.15: 
                    scores_to_insert.append((user_profile['user_id'], job_id, final_score))
            except Exception:
                continue
        
        if scores_to_insert:
            cursor.execute("DELETE FROM job_recommendation_scores WHERE job_id = ?", (job_id,))
            cursor.executemany("INSERT INTO job_recommendation_scores (user_id, job_id, match_score) VALUES (?, ?, ?)", scores_to_insert)
            db.commit()
        
        print(f"[Background] Job {job_id} scoring completed.")

    except Exception as e:
        print(f"[Background] Error: {e}")
        if db: db.rollback()
    finally:
        if db: db.close()

# --- 8. ENDPOINTS ---

@app.get("/ping")
def ping():
    return {"msg": "pong"}

@app.post("/register", response_model=User, status_code=status.HTTP_201_CREATED)
async def register_user(user: UserCreate, db: sqlite3.Connection = Depends(get_db)):
    db_user = get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered.")
    hashed_password = get_password_hash(user.password)
    try:
        cursor = db.cursor()
        cursor.execute("INSERT INTO users (email, hashed_password, role) VALUES (?, ?, ?)", (user.email, hashed_password, user.role))
        user_id = cursor.lastrowid
        cursor.execute("INSERT INTO user_profiles (user_id, has_cv) VALUES (?, 0)", (user_id,))
        db.commit()
        return User(id=user_id, email=user.email, role=user.role)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Registration error: {e}")

@app.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: sqlite3.Connection = Depends(get_db)):
    user = get_user_by_email(db, email=form_data.username)
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password", headers={"WWW-Authenticate": "Bearer"})
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me/", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@app.post("/users/me/cv")
async def upload_user_cv(background_tasks: BackgroundTasks, file: UploadFile = File(...), current_user: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are allowed.")
    
    content = await file.read()
    cv_filename = f"cv_{current_user.id}.pdf"
    cv_path = os.path.join(APP_DIR, "user_cvs", cv_filename)
    os.makedirs(os.path.dirname(cv_path), exist_ok=True)
    
    with open(cv_path, "wb") as f: f.write(content)

    text = ""
    with pdfplumber.open(io.BytesIO(content)) as pdf:
        for page in pdf.pages:
            if page.extract_text(): text += page.extract_text() + "\n"
        
    if not text.strip():
        raise HTTPException(status_code=400, detail="Could not extract text from PDF.")
    
    # NLP Class Usage
    analysis_result = nlp_service.analyze_text(text)
    analysis_json = json.dumps(analysis_result, ensure_ascii=False)
    
    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO user_profiles (user_id, has_cv, cv_analysis_json, last_updated)
        VALUES (?, 1, ?, ?)
        ON CONFLICT(user_id) DO UPDATE SET
            has_cv = 1, cv_analysis_json = excluded.cv_analysis_json, last_updated = excluded.last_updated
    """, (current_user.id, analysis_json, datetime.datetime.now().isoformat()))
    db.commit()
    
    background_tasks.add_task(_recalculate_scores_for_user, user_id=current_user.id, db_path=DB_PATH)

    return {"message": "CV analyzed. Recommendations will be updated shortly."}

@app.get("/users/me/cv/status")
async def get_cv_status(current_user: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cursor = db.cursor()
    cursor.execute("SELECT has_cv FROM user_profiles WHERE user_id = ?", (current_user.id,))
    profile = cursor.fetchone()
    return {"has_cv": True if profile and profile['has_cv'] else False}

@app.post("/jobs", response_model=Job, status_code=status.HTTP_201_CREATED)
async def create_job(job: JobCreate, background_tasks: BackgroundTasks, current_user: User = Depends(get_current_employer), db: sqlite3.Connection = Depends(get_db)):
    combined_text = f"{job.title} {job.description}"
    # NLP Class Usage
    requirements_data = nlp_service.analyze_job_description(combined_text)
    requirements_json = json.dumps(requirements_data, ensure_ascii=False)
    
    cursor = db.cursor()
    cursor.execute("INSERT INTO jobs (title, location, description, company, employer_id, requirements_json) VALUES (?, ?, ?, ?, ?, ?)",
                   (job.title, job.location, job.description, job.company, current_user.id, requirements_json))
    job_id = cursor.lastrowid
    db.commit()
    
    background_tasks.add_task(_recalculate_scores_for_job, job_id=job_id, db_path=DB_PATH)
    return Job(job_id=job_id, title=job.title, location=job.location, description=job.description, company=job.company, employer_id=current_user.id)

@app.get("/jobs/recommended", response_model=List[RecommendedJob])
async def get_recommended_jobs(current_user: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cursor = db.cursor()
    cursor.execute("SELECT cv_analysis_json FROM user_profiles WHERE user_id = ?", (current_user.id,))
    user_profile = cursor.fetchone()
    
    user_skills = set()
    if user_profile and user_profile['cv_analysis_json']:
        data = json.loads(user_profile['cv_analysis_json'])
        user_skills = set(data.get("skills", []))

    cursor.execute("""
        SELECT j.*, s.match_score FROM job_recommendation_scores s
        JOIN jobs j ON s.job_id = j.job_id
        WHERE s.user_id = ?
        ORDER BY s.match_score DESC LIMIT 50 
    """, (current_user.id,))
    
    recommendations = []
    for row in cursor.fetchall():
        job_row = dict(row)
        job_skills = set()
        if job_row['requirements_json']:
            data = json.loads(job_row['requirements_json'])
            # Support both list and dict formats
            if isinstance(data, list): job_skills = set(data)
            elif isinstance(data, dict): job_skills = set(data.get("all_skills", []))

        recommendations.append(RecommendedJob(
            **Job(**job_row).model_dump(),
            match_score=job_row['match_score'],
            matched_skills=sorted(list(user_skills.intersection(job_skills))),
            missing_skills=sorted(list(job_skills.difference(user_skills)))
        ))
    return recommendations

@app.get("/jobs", response_model=List[Job])
async def get_all_jobs(search: Optional[str] = None, page: int = 1, size: int = 20, current_user: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cursor = db.cursor()
    offset = (page - 1) * size
    query = "SELECT * FROM jobs"
    params = []
    if search:
        query += " WHERE title LIKE ?"
        params.append(f"%{search}%")
    query += " ORDER BY job_id DESC LIMIT ? OFFSET ?"
    params.extend([size, offset])
    
    cursor.execute(query, params)
    return [Job(**dict(row)) for row in cursor.fetchall()]

@app.get("/jobs/{job_id}", response_model=Job)
async def get_job_details(job_id: int, current_user: User = Depends(get_current_user), db: sqlite3.Connection = Depends(get_db)):
    cursor = db.cursor()
    cursor.execute("SELECT * FROM jobs WHERE job_id = ?", (job_id,))
    row = cursor.fetchone()
    if not row: raise HTTPException(status_code=404, detail="Job not found.")
    return Job(**dict(row))