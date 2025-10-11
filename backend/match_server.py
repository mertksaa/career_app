# backend/match_server.py
import sqlite3
from fastapi import FastAPI, Depends, HTTPException, status
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional, List, Literal  # <-- HATA DÜZELTMESİ: Literal buraya eklendi
from contextlib import asynccontextmanager

# Kendi modüllerimizden importlar
from match_utils import load_jobs_from_sqlite, Matcher

# --- Global Değişkenler ---
matcher: Optional[Matcher] = None

# --- FastAPI Başlangıç Olayı (Lifespan) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Application startup: Loading models and data...")
    global matcher
    jobs, texts = load_jobs_from_sqlite(limit=2000)
    if jobs and texts:
        matcher = Matcher(texts, jobs)
        print("Matcher initialized successfully.")
    else:
        print("Warning: Matcher could not be initialized because no jobs were loaded.")
    yield
    print("Application shutdown.")

# --- FastAPI Uygulamasını ve Güvenlik Ayarlarını Tanımlama ---
app = FastAPI(lifespan=lifespan)

SECRET_KEY = "zMnBkyVUoOxMjcYQSfPf6YxooAk4iyU5"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
# --- Pydantic Modelleri ---
class UserCreate(BaseModel):
    email: str
    password: str
    role: Literal['job_seeker', 'employer']

class Token(BaseModel):
    access_token: str
    token_type: str

class MatchRequest(BaseModel):
    text: str
    top_k: int = 20

# --- CORS Middleware ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Veritabanı ve Güvenlik Fonksiyonları ---
def get_db_conn():
    conn = sqlite3.connect('career.db')
    return conn

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# --- API ENDPOINT'LERİ ---

@app.get("/")
def read_root():
    return {"status": "Career AI Backend is running"}

@app.post("/register", status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate):
    conn = get_db_conn()
    cursor = conn.cursor()
    cursor.execute("SELECT email FROM users WHERE email = ?", (user_data.email,))
    if cursor.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = get_password_hash(user_data.password)
    cursor.execute(
        "INSERT INTO users (email, hashed_password, role) VALUES (?, ?, ?)",
        (user_data.email, hashed_password, user_data.role)
    )
    conn.commit()
    conn.close()
    return {"message": "User created successfully"}

@app.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    conn = get_db_conn()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (form_data.username,))
    user = cursor.fetchone()
    conn.close()

    if not user or not verify_password(form_data.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(data={"sub": user["email"]})
    return {"access_token": access_token, "token_type": "bearer"}


@app.post('/match_text')
async def match_text(req: MatchRequest):
    if not matcher:
        raise HTTPException(status_code=503, detail="Matcher is not available or still loading.")
    results = matcher.find_matches(req.text, top_k=req.top_k)
    return {'results': results}

# Bu yeni endpoint'i dosyanın en altına ekle

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Token'ı çözer ve veritabanından kullanıcıyı getirir."""
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
    
    conn = get_db_conn()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = ?", (email,))
    user = cursor.fetchone()
    conn.close()
    
    if user is None:
        raise credentials_exception
    return user

@app.get("/users/me/")
async def read_users_me(current_user: dict = Depends(get_current_user)):
    """Giriş yapmış olan kullanıcının bilgilerini döndürür."""
    # Pydantic modeline ihtiyaç duymadan doğrudan dict döndürüyoruz
    return {"id": current_user["id"], "email": current_user["email"], "role": current_user["role"]}

@app.get("/jobs", response_model=List[dict])
def get_all_jobs(limit: int = 100):
    """Veritabanındaki tüm iş ilanlarını listeler."""
    conn = get_db_conn()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    # Şimdilik sadece temel bilgileri alıyoruz, detay sayfası için daha fazlasını alabiliriz.
    cursor.execute("SELECT job_id, title, company, location FROM jobs ORDER BY job_id DESC LIMIT ?", (limit,))
    jobs = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return jobs

@app.post("/jobs/{job_id}/favorite", status_code=status.HTTP_201_CREATED)
def toggle_favorite(job_id: int, current_user: dict = Depends(get_current_user)):
    """Bir iş ilanını kullanıcının favorilerine ekler veya çıkarır."""
    user_id = current_user["id"]
    
    conn = get_db_conn()
    cursor = conn.cursor()
    
    # İlanın zaten favorilerde olup olmadığını kontrol et
    cursor.execute("SELECT id FROM favorites WHERE user_id = ? AND job_id = ?", (user_id, job_id))
    favorite = cursor.fetchone()
    
    if favorite:
        # Zaten favorilerdeyse, kaldır
        cursor.execute("DELETE FROM favorites WHERE id = ?", (favorite[0],))
        message = "İlan favorilerden kaldırıldı."
    else:
        # Favorilerde değilse, ekle
        cursor.execute("INSERT INTO favorites (user_id, job_id) VALUES (?, ?)", (user_id, job_id))
        message = "İlan favorilere eklendi."
        
    conn.commit()
    conn.close()
    return {"message": message}

@app.get("/me/favorites", response_model=List[dict])
def get_user_favorites(current_user: dict = Depends(get_current_user)):
    """Giriş yapmış kullanıcının favori ilanlarını listeler."""
    user_id = current_user["id"]
    
    conn = get_db_conn()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # Favori ilanların ID'lerini jobs tablosuyla birleştirerek tam bilgileri al
    query = """
    SELECT j.job_id, j.title, j.company, j.location 
    FROM jobs j 
    INNER JOIN favorites f ON j.job_id = f.job_id 
    WHERE f.user_id = ?
    """
    cursor.execute(query, (user_id,))
    
    favorite_jobs = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return favorite_jobs

@app.get("/jobs/{job_id}", response_model=dict)
def get_job_by_id(job_id: int):
    """ID'si verilen tek bir iş ilanının tüm detaylarını döndürür."""
    conn = get_db_conn()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM jobs WHERE job_id = ?", (job_id,))
    job = cursor.fetchone()
    conn.close()
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
        
    return dict(job)

@app.post("/jobs/{job_id}/apply", status_code=status.HTTP_201_CREATED)
def apply_for_job(job_id: int, current_user: dict = Depends(get_current_user)):
    """Bir kullanıcının iş ilanına başvurusunu kaydeder."""
    user_id = current_user["id"]
    
    conn = get_db_conn()
    cursor = conn.cursor()
    
    # Kullanıcının bu ilana daha önce başvurup başvurmadığını kontrol et
    cursor.execute("SELECT id FROM applications WHERE user_id = ? AND job_id = ?", (user_id, job_id))
    application = cursor.fetchone()
    
    if application:
        conn.close()
        raise HTTPException(status_code=400, detail="Bu ilana zaten başvurdunuz.")
    
    # Yeni başvuruyu ekle
    application_date = datetime.utcnow().isoformat()
    # TODO: CV dosyası yüklendiğinde buraya dosya yolunu da ekleyeceğiz.
    cursor.execute(
        "INSERT INTO applications (user_id, job_id, application_date) VALUES (?, ?, ?)",
        (user_id, job_id, application_date)
    )
    
    conn.commit()
    conn.close()
    return {"message": "Başvurunuz başarıyla alındı."}

@app.get("/me/applications", response_model=List[dict])
def get_user_applications(current_user: dict = Depends(get_current_user)):
    """Giriş yapmış kullanıcının başvurduğu ilanları listeler."""
    user_id = current_user["id"]
    
    conn = get_db_conn()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    query = """
    SELECT j.job_id, j.title, j.company, j.location 
    FROM jobs j 
    INNER JOIN applications a ON j.job_id = a.job_id 
    WHERE a.user_id = ?
    """
    cursor.execute(query, (user_id,))
    
    applied_jobs = [dict(row) for row in cursor.fetchall()]
    conn.close()
    return applied_jobs
