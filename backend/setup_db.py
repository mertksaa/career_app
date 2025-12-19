import sqlite3
import pandas as pd
import json
import os
import spacy
from nlp_service import nlp_service  # Senin NLP servisini kullanıyoruz

# Ayarlar
DB_PATH = 'career.db'
CSV_PATH = 'fake_job_postings.csv'

def setup_database():
    print(">>> Veritabanı kurulumu başlıyor...")
    
    # 1. Eski DB varsa sil (Temiz başlangıç)
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        print(">>> Eski veritabanı silindi.")

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 2. Tabloları Oluştur (Main.py'deki yapının aynısı)
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
        FOREIGN KEY(employer_id) REFERENCES users(id)
    )
    """)
    # (Diğer tablolar: applications, favorites, job_recommendation_scores... 
    # Bunlar boş kalacak, şimdilik sadece Jobs ve Users lazım)
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
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        job_id INTEGER,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(job_id) REFERENCES jobs(job_id)
    )
    """)

    # 3. Default İşveren Oluştur
    # Şifre: 123456
    employer_pass = "$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxwKc.6IymVFt7H.t1.R9R1.F1.2."
    cursor.execute("INSERT INTO users (email, hashed_password, role) VALUES (?, ?, ?)", 
                   ("employer@test.com", employer_pass, "employer"))
    employer_id = cursor.lastrowid
    print(">>> İşveren hesabı oluşturuldu.")

    # 4. CSV'den Veri Yükle ve Analiz Et
    if os.path.exists(CSV_PATH):
        print(f">>> '{CSV_PATH}' okunuyor...")
        df = pd.read_csv(CSV_PATH)
        
        # Boş verileri temizle
        df = df.fillna('')
        
        # Performans için ilk 500 ilanı alalım (İstersen limiti kaldırabilirsin)
        # df = df.head(500) 
        print(f">>> Toplam {len(df)} ilan analiz edilecek. Bu biraz sürebilir...")

        jobs_data = []
        for index, row in df.iterrows():
            title = row['title']
            desc = row['description']
            reqs = row['requirements']
            
            # NLP Analizi (Metni birleştirip servise gönderiyoruz)
            full_text = f"{title} {desc} {reqs}"
            
            try:
                # Senin yeni NLP servisin burada devreye giriyor
                # Sonuç: {"must_have": [...], "nice_to_have": [...]}
                analysis_result = nlp_service.analyze_job_description(full_text)
                req_json = json.dumps(analysis_result)
            except Exception as e:
                print(f"Hata (Satır {index}): {e}")
                req_json = json.dumps({})

            jobs_data.append((
                title,
                row['location'],
                desc,
                row['company_profile'] if row['company_profile'] else "Confidential", # Şirket adı yoksa profil veya placeholder
                employer_id,
                req_json,
                row['benefits'],
                row['company_profile']
            ))
            
            if index % 100 == 0:
                print(f"   ... {index} ilan işlendi.")

        # Toplu Insert
        cursor.executemany("""
            INSERT INTO jobs (title, location, description, company, employer_id, requirements_json, benefits, company_profile)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, jobs_data)
        
        conn.commit()
        print(f">>> BAŞARILI: {len(jobs_data)} ilan veritabanına yüklendi ve analiz edildi.")
    else:
        print("!!! CSV dosyası bulunamadı.")

    conn.close()

if __name__ == "__main__":
    setup_database()