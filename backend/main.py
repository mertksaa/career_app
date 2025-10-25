
# backend/main.py
import json
import io
import re
import os
import sqlite3
import datetime
from typing import List, Optional, Any

from fastapi import FastAPI, UploadFile, File, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

# --- JWT ve Auth Kütüphaneleri ---
from jose import JWTError, jwt
from passlib.context import CryptContext

# --- Proje İçi Importlar ---
# from match_utils import ... -> KALDIRILDI (Hata buradaydı)
import pdfplumber
# NLP SERVİSİMİZ
from nlp_service import analyze_text 

APP_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(APP_DIR, 'career.db')

# --- 1. KİMLİK DOĞRULAMA (AUTHENTICATION) AYARLARI ---
SECRET_KEY = "Syu0T/+4fEe7SPgWRDatwpQ1Gg4V7CNLkiyGqqnnaE/zqsfibUPcyWsTrIzqHHLJL"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7 # 7 gün

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- 2. VERİTABANI BAĞLANTISI ---

def get_db():
    """FastAPI Dependency: Veritabanı bağlantısını açar ve kapatır."""
    db = None
    try:
        # DÜZELTME: FastAPI'nin çoklu iş parçacığı (multi-thread) erişimine
        # izin vermek için check_same_thread=False eklendi.
        # Kilitlenme (lock) durumunda bekleme süresini 15 saniyeye çıkardık.
        db = sqlite3.connect(DB_PATH, check_same_thread=False, timeout=15)
        
        db.row_factory = sqlite3.Row
        yield db
    except sqlite3.Error as e:
        # Hata durumunda daha detaylı loglama
        print(f"!!! Veritabanı Hatası (get_db): {e}")
        raise HTTPException(status_code=500, detail="Veritabanı bağlantı hatası.")
    finally:
        if db:
            db.close()

# --- 3. PYDANTIC MODELLERİ (Veri Şemaları) ---

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
    # Not: requirements ve benefits'i de buraya ekleyebiliriz
    # ama şimdilik analiz için description'ı kullanacağız.
    # Adım 1.5 (backfill) için DB'de olmaları yeterli.

class Applicant(BaseModel):
    user_id: int
    email: str
    application_date: str
    has_cv: bool

class RecommendedJob(Job):
    """
    İş ilanına ek olarak eşleştirme skorunu ve yetenekleri de içeren 
    zenginleştirilmiş model.
    """
    match_score: float
    matched_skills: List[str]
    missing_skills: List[str]

class SkillAnalysisResponse(BaseModel):
    """
    Tek bir ilan ve kullanıcı arasındaki yetenek karşılaştırmasının
    sonucunu döndüren model.
    """
    match_score: float
    matched_skills: List[str]
    missing_skills: List[str]
    user_skills_found: bool
    job_skills_found: bool  

# --- 4. KULLANICI VE TOKEN YÖNETİMİ ---

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
        detail="Giriş bilgileri doğrulanamadı",
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
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Bu işlem için işveren yetkisi gerekli.")
    return current_user


# --- 5. FastAPI UYGULAMASI VE ENDPOINT'LER ---

app = FastAPI(title="Career AI Backend (Tam Sürüm)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- TF-IDF Başlangıç Yüklemesi -> KALDIRILDI ---
print("NLP Service (spaCy) ve Model nlp_service.py içinde yüklendi.")
print("FastAPI sunucusu başlıyor...")


# === 1. ESKİ NLP ENDPOINT'LERİ (Hala Kullanılabilir) ===
# Not: Bu /analyze endpoint'i 'job_roles.json' kullanır
# ve bizim yeni NLP sistemimizden bağımsızdır.
# Proje sonunda bunu da kaldırabilir veya entegre edebiliriz.

@app.get("/ping")
def ping():
    return {"msg": "pong"}

# ... (Mevcut /analyze ve ilgili 'job_roles' kodları burada kalabilir) ...
JOB_ROLES_PATH = os.path.join(APP_DIR, "job_roles.json")
with open(JOB_ROLES_PATH, "r", encoding="utf-8") as f:
    job_roles = json.load(f)
_master_skills = set()
for r in job_roles:
    for s in r.get("skills", []):
        _master_skills.add(s.lower())
master_skills = sorted(list(_master_skills), key=lambda x: -len(x))
class AnalyzeRequest(BaseModel):
    text: Optional[str] = None
    skills: Optional[List[str]] = None
def extract_skills_from_text(text: str):
    if not text: return []
    t = text.lower()
    found = set()
    t = re.sub(r"[-_/]", " ", t)
    for skill in master_skills:
        pattern = r"(?<!\w)" + re.escape(skill) + r"(?!\w)"
        if re.search(pattern, t, flags=re.IGNORECASE):
            found.add(skill)
    return sorted(list(found))
@app.post("/analyze")
async def analyze(req: AnalyzeRequest):
    if req.skills and isinstance(req.skills, list) and len(req.skills) > 0:
        user_skills = [s.strip().lower() for s in req.skills if s and isinstance(s, str)]
    else:
        user_skills = extract_skills_from_text(req.text or "")
    user_skills_set = set(user_skills)
    results = []
    for r in job_roles:
        required = [s.lower() for s in r.get("skills", [])]
        req_set = set(required)
        matched = sorted(list(req_set.intersection(user_skills_set)))
        match_ratio = round(len(matched) / len(req_set), 2) if len(req_set) > 0 else 0.0
        missing = sorted(list(req_set - user_skills_set))
        results.append({
            "name": r.get("name"),
            "match": match_ratio,
            "matched": matched,
            "missing": missing
        })
    results_sorted = sorted(results, key=lambda x: x["match"], reverse=True)
    return {"roles": results_sorted, "detected_skills": sorted(list(user_skills_set))}
# ... (Eski /analyze kodunun sonu) ...


# === 2. KULLANICI KAYIT VE GİRİŞ ENDPOINT'LERİ ===

@app.post("/register", response_model=User, status_code=status.HTTP_201_CREATED)
async def register_user(user: UserCreate, db: sqlite3.Connection = Depends(get_db)):
    db_user = get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Bu e-posta adresi zaten kayıtlı.")
    hashed_password = get_password_hash(user.password)
    try:
        cursor = db.cursor()
        cursor.execute(
            "INSERT INTO users (email, hashed_password, role) VALUES (?, ?, ?)",
            (user.email, hashed_password, user.role)
        )
        user_id = cursor.lastrowid
        cursor.execute(
            "INSERT INTO user_profiles (user_id, has_cv) VALUES (?, 0)",
            (user_id,)
        )
        db.commit()
        return User(id=user_id, email=user.email, role=user.role)
    except sqlite3.IntegrityError as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Veritabanı hatası: {e}")
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Kayıt sırasında hata: {e}")

@app.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(), 
    db: sqlite3.Connection = Depends(get_db)
):
    user = get_user_by_email(db, email=form_data.username)
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Geçersiz e-posta veya parola",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = datetime.timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me/", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

# === 3. CV YÖNETİMİ ===

@app.post("/users/me/cv")
async def upload_user_cv(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Sadece PDF dosyaları yüklenebilir.")
    content = await file.read()
    text = ""
    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF okunurken hata: {e}")
    if not text.strip():
        raise HTTPException(status_code=400, detail="PDF dosyasından metin çıkarılamadı (boş içerik).")
    
    print(f"Kullanıcı {current_user.email} için CV analizi başlıyor...")
    analysis_result = analyze_text(text)
    analysis_json = json.dumps(analysis_result, ensure_ascii=False)
    print("CV analizi tamamlandı.")
    
    try:
        cursor = db.cursor()
        current_time = datetime.datetime.now().isoformat()
        cursor.execute("""
            INSERT INTO user_profiles (user_id, has_cv, cv_analysis_json, last_updated)
            VALUES (?, 1, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                has_cv = 1,
                cv_analysis_json = excluded.cv_analysis_json,
                last_updated = excluded.last_updated
        """, (current_user.id, analysis_json, current_time))
        db.commit()
    except sqlite3.Error as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"CV analizi kaydedilirken hata: {e}")
    
    return {
        "filename": file.filename,
        "message": "CV başarıyla analiz edildi ve profilinize kaydedildi.",
        "analysis_summary": {
            "detected_skills_count": len(analysis_result.get("skills", [])),
        }
    }

@app.get("/users/me/cv/status")
async def get_cv_status(
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    cursor = db.cursor()
    cursor.execute("SELECT has_cv FROM user_profiles WHERE user_id = ?", (current_user.id,))
    profile = cursor.fetchone()
    if profile and profile['has_cv']:
        return {"has_cv": True}
    return {"has_cv": False}


# === 4. İŞ İLANI YÖNETİMİ (İŞVEREN) ===

@app.post("/jobs", response_model=Job, status_code=status.HTTP_201_CREATED)
async def create_job(
    job: JobCreate,
    current_user: User = Depends(get_current_employer),
    db: sqlite3.Connection = Depends(get_db)
):
    print(f"İşveren {current_user.email} için ilan analizi başlıyor...")
    # NLP analizi için hem başlığı hem de açıklamayı birleştir
    combined_text = f"{job.title} {job.description}"
    analysis_result = analyze_text(combined_text)
    requirements_json = json.dumps(analysis_result, ensure_ascii=False)
    print("İlan analizi tamamlandı.")
    
    try:
        cursor = db.cursor()
        cursor.execute(
            """
            INSERT INTO jobs (title, location, description, company, employer_id, requirements_json)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            # Not: Yeni zengin CSV'den gelen 'requirements' ve 'benefits' 
            # henüz 'jobs' tablosunda değil. Bunu bir sonraki adımda (ETL) düzelteceğiz.
            # Şimdilik sadece description'ı kaydediyoruz.
            (job.title, job.location, job.description, job.company, current_user.id, requirements_json)
        )
        job_id = cursor.lastrowid
        db.commit()
        return Job(
            job_id=job_id,
            title=job.title,
            location=job.location,
            description=job.description,
            company=job.company,
            employer_id=current_user.id
        )
    except sqlite3.Error as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"İlan oluşturulurken hata: {e}")

@app.put("/jobs/{job_id}", response_model=Job)
async def update_job(
    job_id: int,
    job: JobCreate,
    current_user: User = Depends(get_current_employer),
    db: sqlite3.Connection = Depends(get_db)
):
    print(f"İlan (ID: {job_id}) güncelleme analizi başlıyor...")
    combined_text = f"{job.title} {job.description}"
    analysis_result = analyze_text(combined_text)
    requirements_json = json.dumps(analysis_result, ensure_ascii=False)
    print("İlan güncelleme analizi tamamlandı.")
    
    try:
        cursor = db.cursor()
        cursor.execute(
            """
            UPDATE jobs 
            SET title = ?, location = ?, description = ?, company = ?, requirements_json = ?
            WHERE job_id = ? AND employer_id = ?
            """,
            (job.title, job.location, job.description, job.company, requirements_json, job_id, current_user.id)
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="İlan bulunamadı veya bu ilanı güncelleme yetkiniz yok.")
        
        db.commit()
        return Job(
            job_id=job_id,
            title=job.title,
            location=job.location,
            description=job.description,
            company=job.company,
            employer_id=current_user.id
        )
    except sqlite3.Error as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"İlan güncellenirken hata: {e}")

@app.delete("/jobs/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_job(
    job_id: int,
    current_user: User = Depends(get_current_employer),
    db: sqlite3.Connection = Depends(get_db)
):
    try:
        cursor = db.cursor()
        cursor.execute("SELECT employer_id FROM jobs WHERE job_id = ?", (job_id,))
        job = cursor.fetchone()
        if not job:
            raise HTTPException(status_code=4404, detail="İlan bulunamadı.")
        if job['employer_id'] != current_user.id:
            raise HTTPException(status_code=403, detail="Bu ilanı silme yetkiniz yok.")
        
        cursor.execute("DELETE FROM applications WHERE job_id = ?", (job_id,))
        cursor.execute("DELETE FROM favorites WHERE job_id = ?", (job_id,))
        cursor.execute("DELETE FROM jobs WHERE job_id = ?", (job_id,))
        db.commit()
        return
    except sqlite3.Error as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"İlan silinirken hata: {e}")

@app.get("/employer/me/jobs", response_model=List[Job])
async def get_my_jobs(
    current_user: User = Depends(get_current_employer),
    db: sqlite3.Connection = Depends(get_db)
):
    cursor = db.cursor()
    cursor.execute("SELECT * FROM jobs WHERE employer_id = ? ORDER BY job_id DESC", (current_user.id,))
    jobs = [Job(**row) for row in cursor.fetchall()]
    return jobs

@app.get("/jobs/{job_id}/applicants", response_model=List[Applicant])
async def get_job_applicants(
    job_id: int,
    current_user: User = Depends(get_current_employer),
    db: sqlite3.Connection = Depends(get_db)
):
    cursor = db.cursor()
    cursor.execute("SELECT employer_id FROM jobs WHERE job_id = ?", (job_id,))
    job = cursor.fetchone()
    if not job:
        raise HTTPException(status_code=404, detail="İlan bulunamadı.")
    if job['employer_id'] != current_user.id:
        raise HTTPException(status_code=403, detail="Bu ilanın başvuranlarını görme yetkiniz yok.")
    
    cursor.execute("""
        SELECT 
            u.id as user_id, 
            u.email, 
            a.application_date, 
            up.has_cv
        FROM applications a
        JOIN users u ON a.user_id = u.id
        LEFT JOIN user_profiles up ON u.id = up.user_id
        WHERE a.job_id = ?
    """, (job_id,))
    applicants = [Applicant(**row) for row in cursor.fetchall()]
    return applicants


# === 5. İŞ ARAMA (İŞ ARAYAN) ENDPOINT'LERİ ===

@app.get("/jobs/recommended", response_model=List[RecommendedJob])
async def get_recommended_jobs(
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    (İŞ ARAYAN) Kullanıcının CV'sine göre kişiselleştirilmiş ve 
    skorlanmış iş ilanlarını getirir.
    """
    
    # 1. Kullanıcının CV analizini (yeteneklerini) al
    cursor = db.cursor()
    cursor.execute(
        "SELECT has_cv, cv_analysis_json FROM user_profiles WHERE user_id = ?", 
        (current_user.id,)
    )
    user_profile = cursor.fetchone()
    
    if not user_profile or not user_profile['has_cv'] or not user_profile['cv_analysis_json']:
        # Kullanıcının CV'si yoksa veya analiz edilmemişse boş liste döndür
        # Flutter tarafı bunu yakalayıp "Önce CV yükleyin" diyecek
        return []

    try:
        user_skills_data = json.loads(user_profile['cv_analysis_json'])
        user_skills = set(user_skills_data.get("skills", []))
    except json.JSONDecodeError:
        user_skills = set() # JSON bozuksa
        
    if not user_skills:
        # CV var ama 0 yetenek bulunduysa (boş CV vb.)
        return []

    # 2. Analiz edilmiş tüm iş ilanlarını al (backfill sayesinde dolu)
    cursor.execute(
        "SELECT * FROM jobs WHERE requirements_json IS NOT NULL"
    )
    all_jobs = cursor.fetchall()
    
    recommendations = []
    
    # 3. Her ilan ile kullanıcının yeteneklerini karşılaştır
    for job_row in all_jobs:
        job = Job(**job_row) # Pydantic Job modeline çevir
        
        try:
            job_skills_data = json.loads(job_row['requirements_json'])
            job_skills = set(job_skills_data.get("skills", []))
        except (json.JSONDecodeError, TypeError):
            job_skills = set()
            
        if not job_skills:
            # İlanın gerektirdiği yetenek listesi boşsa, eşleştirme yapma
            continue
            
        # 4. Eşleştirme Mantığı (KALP)
        matched_skills = user_skills.intersection(job_skills)
        missing_skills = job_skills.difference(user_skills)
        
        # Uygunluk Skoru: (Eşleşen Yetenek Sayısı / İlanın İstediği Toplam Yetenek Sayısı)
        # Örn: İlan 10 yetenek istiyor, kullanıcı 3'üne sahip -> Skor = 3 / 10 = 0.3 (%30)
        match_score = round(len(matched_skills) / len(job_skills), 2)
        
        # Sadece %0'dan büyük bir uyum varsa listeye ekle
        if match_score > 0:
            recommendations.append(
                RecommendedJob(
                    **job.model_dump(), # Job modelinin tüm alanlarını kopyala
                    match_score=match_score,
                    matched_skills=sorted(list(matched_skills)),
                    missing_skills=sorted(list(missing_skills))
                )
            )
            
    # 5. İlanları en yüksek skordan en düşüğe doğru sırala
    recommendations_sorted = sorted(recommendations, key=lambda j: j.match_score, reverse=True)
    
    return recommendations_sorted

@app.get("/jobs", response_model=List[Job])
async def get_all_jobs(
    search: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    cursor = db.cursor()
    query = "SELECT * FROM jobs"
    params = []
    if search:
        query += " WHERE title LIKE ?"
        params.append(f"%{search}%")
    query += " ORDER BY job_id DESC"
    cursor.execute(query, params)
    jobs = [Job(**row) for row in cursor.fetchall()]
    return jobs

@app.get("/jobs/{job_id}", response_model=Job)
async def get_job_details(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    cursor = db.cursor()
    cursor.execute("SELECT * FROM jobs WHERE job_id = ?", (job_id,))
    job = cursor.fetchone()
    if not job:
        raise HTTPException(status_code=404, detail="İlan bulunamadı.")
    return Job(**job)

@app.get("/jobs/{job_id}/analysis", response_model=SkillAnalysisResponse)
async def get_job_skill_analysis(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    """
    (İŞ ARAYAN) Belirli bir iş ilanı (job_id) ile mevcut kullanıcının
    CV'si arasındaki Yetenek Açığı (Skill Gap) analizini yapar.
    """
    cursor = db.cursor()
    
    # 1. Kullanıcının CV analizini (yeteneklerini) al
    cursor.execute(
        "SELECT has_cv, cv_analysis_json FROM user_profiles WHERE user_id = ?", 
        (current_user.id,)
    )
    user_profile = cursor.fetchone()
    
    user_skills = set()
    user_skills_found = False
    if user_profile and user_profile['has_cv'] and user_profile['cv_analysis_json']:
        try:
            user_skills_data = json.loads(user_profile['cv_analysis_json'])
            user_skills = set(user_skills_data.get("skills", []))
            if user_skills:
                user_skills_found = True
        except json.JSONDecodeError:
            pass # user_skills boş set olarak kalır

    # 2. İş ilanının analizini (gereken yetenekleri) al
    cursor.execute(
        "SELECT requirements_json FROM jobs WHERE job_id = ?",
        (job_id,)
    )
    job_row = cursor.fetchone()
    
    if not job_row:
        raise HTTPException(status_code=404, detail="İlan bulunamadı.")
        
    job_skills = set()
    job_skills_found = False
    if job_row['requirements_json']:
        try:
            job_skills_data = json.loads(job_row['requirements_json'])
            job_skills = set(job_skills_data.get("skills", []))
            if job_skills:
                job_skills_found = True
        except (json.JSONDecodeError, TypeError):
            pass # job_skills boş set olarak kalır

    # 3. Eşleştirme Mantığı
    if not job_skills_found or not user_skills_found:
        # Karşılaştırma yapılamıyorsa (CV yoksa, ilanda yetenek yoksa vb.)
        return SkillAnalysisResponse(
            match_score=0.0,
            matched_skills=[],
            missing_skills=sorted(list(job_skills)), # Eksik olarak ilanın tüm yeteneklerini göster
            user_skills_found=user_skills_found,
            job_skills_found=job_skills_found
        )

    matched_skills = user_skills.intersection(job_skills)
    missing_skills = job_skills.difference(user_skills)
    
    # Uygunluk Skoru
    match_score = round(len(matched_skills) / len(job_skills), 2)
    
    return SkillAnalysisResponse(
        match_score=match_score,
        matched_skills=sorted(list(matched_skills)),
        missing_skills=sorted(list(missing_skills)),
        user_skills_found=user_skills_found,
        job_skills_found=job_skills_found
    )


@app.post("/jobs/{job_id}/favorite", status_code=200)
async def toggle_favorite(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    try:
        cursor = db.cursor()
        cursor.execute("SELECT id FROM favorites WHERE user_id = ? AND job_id = ?", (current_user.id, job_id))
        favorite = cursor.fetchone()
        if favorite:
            cursor.execute("DELETE FROM favorites WHERE id = ?", (favorite['id'],))
            message = "İlan favorilerden kaldırıldı."
        else:
            cursor.execute("INSERT INTO favorites (user_id, job_id) VALUES (?, ?)", (current_user.id, job_id))
            message = "İlan favorilere eklendi."
        db.commit()
        return {"message": message}
    except sqlite3.Error as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Favori işlemi sırasında hata: {e}")

@app.get("/me/favorites", response_model=List[Job])
async def get_my_favorites(
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    cursor = db.cursor()
    cursor.execute("""
        SELECT j.* FROM jobs j
        JOIN favorites f ON j.job_id = f.job_id
        WHERE f.user_id = ?
        ORDER BY f.id DESC
    """, (current_user.id,))
    jobs = [Job(**row) for row in cursor.fetchall()]
    return jobs

@app.post("/jobs/{job_id}/apply", status_code=201)
async def apply_for_job(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    if current_user.role != 'job_seeker':
        raise HTTPException(status_code=403, detail="Sadece iş arayanlar başvurabilir.")
    try:
        cursor = db.cursor()
        cursor.execute("SELECT has_cv FROM user_profiles WHERE user_id = ?", (current_user.id,))
        profile = cursor.fetchone()
        if not profile or not profile['has_cv']:
            raise HTTPException(status_code=400, detail="Başvuru yapabilmek için önce profilinizden CV yüklemelisiniz.")
        cursor.execute("SELECT id FROM applications WHERE user_id = ? AND job_id = ?", (current_user.id, job_id))
        application = cursor.fetchone()
        if application:
            raise HTTPException(status_code=400, detail="Bu ilana zaten başvurmuşsunuz.")
        current_date = datetime.datetime.now().isoformat()
        cursor.execute(
            "INSERT INTO applications (user_id, job_id, application_date) VALUES (?, ?, ?)",
            (current_user.id, job_id, current_date)
        )
        db.commit()
        return {"message": "Başvurunuz başarıyla alındı."}
    except sqlite3.IntegrityError:
        db.rollback()
        raise HTTPException(status_code=404, detail="İlan bulunamadı.")
    except sqlite3.Error as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Başvuru sırasında hata: {e}")

@app.get("/me/applications", response_model=List[Job])
async def get_my_applications(
    current_user: User = Depends(get_current_user),
    db: sqlite3.Connection = Depends(get_db)
):
    cursor = db.cursor()
    cursor.execute("""
        SELECT j.* FROM jobs j
        JOIN applications a ON j.job_id = a.job_id
        WHERE a.user_id = ?
        ORDER BY a.application_date DESC
    """, (current_user.id,))
    jobs = [Job(**row) for row in cursor.fetchall()]
    return jobs