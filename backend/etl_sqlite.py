# backend/etl_sqlite.py
import sqlite3
import pandas as pd

DB_PATH = 'career.db'
CSV_PATH = 'jobs.csv'

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
    
    # --- 1. Jobs Tablosunu DOĞRU ŞEMA ile Oluştur ---
    print("Creating 'jobs' table with proper schema...")
    cursor.execute('''
    CREATE TABLE jobs (
        job_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        location TEXT,
        description TEXT,
        company TEXT,
        employer_id INTEGER,
        FOREIGN KEY (employer_id) REFERENCES users(id)
    )
    ''')

    # --- 2. CSV'den Verileri Oku ve Ekle ---
    print("Populating 'jobs' table from CSV...")
    df = pd.read_csv(CSV_PATH)
    required_cols = ['title', 'location', 'description', 'company_profile']
    df_selected = df[required_cols].copy()
    df_selected.rename(columns={'company_profile': 'company'}, inplace=True)
    df_selected.fillna('', inplace=True)

    # DataFrame'i veritabanına ekle (ancak 'job_id' ve 'employer_id' hariç)
    # Bu sütunlar veritabanı tarafından yönetilecek
    df_to_insert = df_selected[['title', 'location', 'description', 'company']]
    df_to_insert.to_sql('jobs', conn, if_exists='append', index=False)
    print("'jobs' table populated from CSV.")

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