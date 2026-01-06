import sqlite3
import csv
import json
import os
import sys
import pickle
import numpy as np

# Backend klasörünü path'e ekle
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

from nlp_service import nlp_service

# Ayarlar
DB_PATH = os.path.join(current_dir, 'career.db')
CSV_PATH = os.path.join(current_dir, 'fake_job_postings.csv')

# --- LİMİT YOK (Tüm İlanlar) ---
LIMIT = None 

def setup_database():
    print(f">>> PROFESYONEL Veritabanı kurulumu başlıyor... (Hedef: TÜM İLANLAR)")
    
    # Eski DB'yi sil (Temiz başlangıç)
    if os.path.exists(DB_PATH):
        try:
            os.remove(DB_PATH)
            print(">>> Eski veritabanı temizlendi.")
        except PermissionError:
            print("!!! HATA: Sunucuyu kapatın (uvicorn). DB dosyası kilitli.")
            return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # --- TABLOLAR ---
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        hashed_password TEXT NOT NULL,
        role TEXT NOT NULL
    )
    """)
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_profiles (
        user_id INTEGER PRIMARY KEY,
        has_cv INTEGER DEFAULT 0,
        cv_analysis_json TEXT,
        last_updated TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )
    """)
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
        vector_blob BLOB, 
        FOREIGN KEY(employer_id) REFERENCES users(id)
    )
    """)
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
    cursor.execute("CREATE TABLE IF NOT EXISTS applications (id INTEGER PRIMARY KEY, user_id INTEGER, job_id INTEGER, application_date TEXT)")
    cursor.execute("CREATE TABLE IF NOT EXISTS favorites (id INTEGER PRIMARY KEY, user_id INTEGER, job_id INTEGER)")
    
    conn.commit()

    # Varsayılan İşveren Hesabı
    employer_pass = "$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxwKc.6IymVFt7H.t1.R9R1.F1.2."
    cursor.execute("INSERT INTO users (email, hashed_password, role) VALUES (?, ?, ?)", 
                   ("employer@test.com", employer_pass, "employer"))
    employer_id = cursor.lastrowid

    # --- CSV İŞLEME ---
    if os.path.exists(CSV_PATH):
        print(f">>> CSV okunuyor ve NLP vektörleri hesaplanıyor...")
        print(">>> NOT: Bu işlem veri boyutuna göre 2-5 dakika sürebilir. Lütfen bekleyin...")
        
        try:
            with open(CSV_PATH, 'r', encoding='utf-8', errors='ignore') as f:
                reader = csv.DictReader(f)
                jobs_data = []
                
                for i, row in enumerate(reader):
                    # --- DÜZELTME BURADA ---
                    # Eğer LIMIT None değilse ve i sınırı geçtiyse dur.
                    # LIMIT None ise sonsuza kadar git.
                    if LIMIT is not None and i >= LIMIT: 
                        break
                    
                    title = row.get('title', 'Untitled')
                    desc = row.get('description', '')
                    reqs = row.get('requirements', '')
                    loc = row.get('location', 'Remote')
                    benefits = row.get('benefits', '')
                    comp_profile = row.get('company_profile', '')
                    company = "Confidential Company" 

                    combined_text = f"{title} {desc} {reqs}"
                    
                    # 1. NLP Analizi (JSON)
                    # Çok yavaşlamaması için sadece basit temizlik yapıyoruz
                    requirements_json = json.dumps({}) 
                    # İstersen nlp_service.analyze_job_description çağırabilirsin 
                    # ama 17.000 ilanda çok uzun sürer. Şimdilik boş geçiyoruz.

                    # 2. VEKTÖR HESAPLAMA (En Önemlisi)
                    try:
                        doc = nlp_service.nlp(combined_text)
                        vector = doc.vector
                        vector_blob = pickle.dumps(vector)
                    except Exception as e:
                        vector_blob = pickle.dumps(np.zeros(300))

                    jobs_data.append((
                        title, loc, desc, company, employer_id, requirements_json, benefits, comp_profile, vector_blob
                    ))
                    
                    if (i + 1) % 1000 == 0:
                        print(f"    ... {i + 1} ilan işlendi.")

                if jobs_data:
                    cursor.executemany("""
                        INSERT INTO jobs (title, location, description, company, employer_id, requirements_json, benefits, company_profile, vector_blob) 
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, jobs_data)
                    conn.commit()
                    print(f">>> BAŞARILI: {len(jobs_data)} ilan veri tabanına eklendi!")
                    
        except Exception as e:
            print(f">>> CSV OKUMA HATASI: {e}")
    else:
        print(f">>> CSV dosyası bulunamadı: {CSV_PATH}")

    conn.close()

if __name__ == "__main__":
    setup_database()