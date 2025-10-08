# backend/etl_sqlite.py
import sqlite3
import pandas as pd

DB_PATH = 'career.db'
CSV_PATH = 'jobs.csv'

def setup_database():
    """
    Veritabanını ve tüm tabloları sıfırdan kurar.
    jobs tablosunu CSV'den doldurur ve diğer tabloları oluşturur.
    """
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # --- 1. Jobs Tablosunu Oluştur ve Doldur ---
    print("Creating and populating 'jobs' table...")
    # jobs tablosu varsa silerek temiz bir başlangıç yapalım
    cursor.execute('DROP TABLE IF EXISTS jobs')
    
    # jobs tablosunu CSV'den oku
    df = pd.read_csv(CSV_PATH)

    # HATA DÜZELTME: CSV'deki gerçek sütun adlarını kullanalım.
    # Sadece ihtiyacımız olan sütunları seçiyoruz.
    required_cols = ['title', 'location', 'description', 'company_profile']
    df_selected = df[required_cols].copy()

    # 'company_profile' sütununu 'company' olarak yeniden adlandıralım.
    df_selected.rename(columns={'company_profile': 'company'}, inplace=True)
    
    # 'job_id' sütunu CSV'de yok, bu yüzden DataFrame'in index'ini kullanarak oluşturalım.
    df_selected.reset_index(inplace=True)
    df_selected.rename(columns={'index': 'job_id'}, inplace=True)

    # Sütunları istediğimiz sırada düzenleyelim.
    final_df = df_selected[['job_id', 'title', 'location', 'description', 'company']]

    # Boş (NaN) değerleri boş string ile değiştirelim.
    final_df.fillna('', inplace=True)

    # DataFrame'i SQLite tablosuna yaz
    final_df.to_sql('jobs', conn, if_exists='replace', index=False)
    print("'jobs' table created and populated successfully.")

    # --- 2. Kullanıcı ve Diğer Tabloları Oluştur (Bu kısım aynı) ---
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

    # --- 3. Jobs Tablosunu Güncelle (Bu kısım aynı) ---
    print("Updating 'jobs' table with employer_id...")
    try:
        cursor.execute('ALTER TABLE jobs ADD COLUMN employer_id INTEGER REFERENCES users(id)')
    except sqlite3.OperationalError as e:
        if "duplicate column name" in str(e):
            print("employer_id column already exists.")
        else:
            raise e

    print("\nDatabase setup completed successfully!")
    conn.commit()
    conn.close()

if __name__ == '__main__':
    setup_database()