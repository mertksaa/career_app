# backend/etl_sqlite.py
import sqlite3
import pandas as pd

# YENİ VERİ SETİNE GÖRE GÜNCELLENDİ
DB_PATH = 'career.db'
CSV_PATH = 'fake_job_postings.csv' # YENİ DOSYA ADI

def setup_database():
    """
    Veritabanını ve tüm tabloları sıfırdan ve doğru şema ile kurar.
    """
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    print("Dropping existing tables for a fresh start...")
    cursor.execute('DROP TABLE IF EXISTS jobs')
    cursor.execute('DROP TABLE IF EXISTS users')
    cursor.execute('DROP TABLE IF EXISTS favorites')
    cursor.execute('DROP TABLE IF EXISTS applications')
    cursor.execute('DROP TABLE IF EXISTS user_profiles')
    
    # --- 1. Jobs Tablosunu GÜNCELLENMİŞ ŞEMA ile Oluştur ---
    print("Creating 'jobs' table with rich schema...")
    cursor.execute('''
    CREATE TABLE jobs (
        job_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        location TEXT,
        description TEXT,
        company TEXT,
        employer_id INTEGER,
        requirements TEXT,        -- YENİ ZENGİN VERİ SÜTUNU
        benefits TEXT,            -- YENİ ZENGİN VERİ SÜTUNU
        requirements_json TEXT,   -- NLP ANALİZ SONUCU (Başlangıçta boş olacak)
        FOREIGN KEY (employer_id) REFERENCES users(id)
    )
    ''')

    # --- 2. YENİ CSV'den Verileri Oku ve Ekle ---
    print(f"Populating 'jobs' table from {CSV_PATH}...")
    try:
        df = pd.read_csv(CSV_PATH)
    except FileNotFoundError:
        print(f"HATA: '{CSV_PATH}' dosyası 'backend' klasöründe bulunamadı.")
        print("Lütfen dosyayı doğru yere kopyaladığınızdan emin olun.")
        conn.close()
        return
    except Exception as e:
        print(f"CSV okunurken hata: {e}")
        conn.close()
        return

    # Gerekli sütunları seç (yeni zengin sütunlar dahil)
    required_cols = ['title', 'location', 'description', 'company_profile', 'requirements', 'benefits']
    
    # Gerekli tüm sütunların varlığını kontrol et
    missing_cols = [col for col in required_cols if col not in df.columns]
    if missing_cols:
        print(f"HATA: CSV dosyasında beklenen sütunlar eksik: {missing_cols}")
        conn.close()
        return

    df_selected = df[required_cols].copy()
    
    # 'company_profile' sütununu 'company' olarak yeniden adlandır
    df_selected.rename(columns={'company_profile': 'company'}, inplace=True)
    
    # Boş (NaN) değerleri boş string '' ile doldur
    df_selected.fillna('', inplace=True)

    # DataFrame'i veritabanına ekle
    # Sadece CSV'den gelen sütunları seç
    df_to_insert = df_selected[['title', 'location', 'description', 'company', 'requirements', 'benefits']]
    
    try:
        df_to_insert.to_sql('jobs', conn, if_exists='append', index=False)
        print(f"'{CSV_PATH}' içinden {len(df_to_insert)} ilan 'jobs' tablosuna eklendi.")
    except Exception as e:
        print(f"Veritabanına yazılırken hata: {e}")
        conn.close()
        return

    # --- 3. Kullanıcı ve Diğer Tabloları Oluştur ---
    print("Creating user-related tables...")
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        hashed_password TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('job_seeker', 'employer'))
    )
    ''')
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS user_profiles (
        profile_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL UNIQUE,
        has_cv BOOLEAN DEFAULT 0,
        cv_analysis_json TEXT,
        last_updated TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
    )
    ''')
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        job_id INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (job_id) REFERENCES jobs (job_id)
    )
    ''')
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS applications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        job_id INTEGER NOT NULL,
        application_date TEXT NOT NULL,
        cv_path TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (job_id) REFERENCES jobs (job_id)
    )
    ''')

    print("\nDatabase setup completed successfully!")
    conn.commit()
    conn.close()

if __name__ == '__main__':
    setup_database()