# backend/backfill_jobs_nlp.py
import sqlite3
import json
import os
from nlp_service import analyze_text # NLP beynimizi import ediyoruz

APP_DIR = os.path.dirname(__file__)
DB_PATH = os.path.join(APP_DIR, 'career.db')

def backfill_job_requirements():
    """
    Veritabanındaki 'jobs' tablosunu tarar.
    'requirements_json' sütunu boş olan ilanları bulur,
    NLP analizi yapar ve sütunu günceller.
    """
    
    db = None
    try:
        db = sqlite3.connect(DB_PATH)
        db.row_factory = sqlite3.Row
        cursor = db.cursor()

        # 1. Analiz edilmemiş iş ilanlarını seç
        # requirements_json IS NULL kontrolü, bu script'i tekrar tekrar
        # çalıştırmanın güvenli olmasını sağlar (sadece eksikleri işler).
        cursor.execute("""
            SELECT job_id, title, description, requirements, benefits 
            FROM jobs 
            WHERE requirements_json IS NULL
        """)
        
        jobs_to_process = cursor.fetchall()
        
        if not jobs_to_process:
            print("Analiz edilecek yeni iş ilanı bulunamadı. Veritabanı güncel.")
            return

        print(f"Toplam {len(jobs_to_process)} adet iş ilanı analiz için bulundu. İşlem başlıyor...")
        
        processed_count = 0
        update_data = [] # Toplu güncelleme için [(json_data, job_id), ...]

        for job in jobs_to_process:
            # 2. NLP analizi için zengin metinleri birleştir
            # (description + requirements + benefits)
            combined_text = " ".join([
                job['title'] or "",
                job['description'] or "",
                job['requirements'] or "",
                job['benefits'] or ""
            ])
            
            if not combined_text.strip():
                # Eğer tüm alanlar boşsa, boş bir JSON kaydet
                analysis_result = {"skills": []}
            else:
                # 3. NLP Servisimizi kullanarak analiz et
                analysis_result = analyze_text(combined_text)
            
            analysis_json = json.dumps(analysis_result, ensure_ascii=False)
            
            # 4. Güncelleme listesine ekle
            update_data.append((analysis_json, job['job_id']))
            
            processed_count += 1
            if processed_count % 100 == 0:
                print(f"{processed_count}/{len(jobs_to_process)} ilan işlendi...")

        # 5. Veritabanını Toplu Güncelle (Çok daha hızlı)
        if update_data:
            print(f"Veritabanı güncelleniyor ({len(update_data)} satır)...")
            cursor.executemany("""
                UPDATE jobs 
                SET requirements_json = ? 
                WHERE job_id = ?
            """, update_data)
            
            db.commit()
            print("Veritabanı başarıyla güncellendi!")
        
        print(f"\nİşlem tamamlandı. Toplam {processed_count} ilan analiz edildi ve kaydedildi.")

    except sqlite3.Error as e:
        if db:
            db.rollback()
        print(f"Veritabanı hatası oluştu: {e}")
    except Exception as e:
        print(f"Beklenmedik bir hata oluştu: {e}")
    finally:
        if db:
            db.close()

if __name__ == "__main__":
    # Bu script, nlp_service'in model yüklemesini tetikleyeceği için
    # terminalde "NLP modeli ve yetenekler yükleniyor..." mesajını göreceksiniz.
    # Bu normaldir.
    backfill_job_requirements()