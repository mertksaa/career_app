import sqlite3
import json
import os
import sys
import pickle

# Backend klasörünü path'e ekle
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

from nlp_service import nlp_service

DB_PATH = os.path.join(current_dir, 'career.db')

def add_test_scenarios():
    print(">>> Test İlanları Ekleniyor...")

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. İşveren ID'sini bul (setup_db ile oluşturulan employer@test.com)
    cursor.execute("SELECT id FROM users WHERE role='employer' LIMIT 1")
    row = cursor.fetchone()
    if not row:
        print("HATA: İşveren hesabı bulunamadı. Önce setup_db.py çalıştırın.")
        return
    employer_id = row[0]

    # --- TEST SENARYOLARI ---
    test_jobs = [
        # --- AHMET İÇİN (Yazılımcı) ---
        {
            "title": "Senior React Developer",
            "location": "Remote",
            "company": "TechFlow",
            "description": "We are looking for an experienced Frontend Developer. Must have strong knowledge of React.js and JavaScript. Experience with Tailwind CSS and Figma is required. You will build modern user interfaces."
        },
        {
            "title": "Python Backend Developer",
            "location": "Istanbul",
            "company": "DataCorp",
            "description": "Seeking a Backend Developer to build APIs. Required skills: Python, Django, and PostgreSQL. Experience with Git is a plus. Knowledge of frontend technologies is nice to have but not required."
        },
        {
            "title": "Accounting Specialist",
            "location": "Ankara",
            "company": "FinansBank",
            "description": "We need an accountant to manage financial records. Must have experience with Excel, Tax Laws, and Financial Auditing. CPA certification is required. No coding skills needed."
        },

        # --- ZEYNEP İÇİN (Pazarlamacı) ---
        {
            "title": "SEO & Content Manager",
            "location": "Izmir",
            "company": "CreativeAgency",
            "description": "We are hiring a Digital Marketer. Must be an expert in SEO, Google Analytics, and Content Writing. Experience with Social Media Management and tools like HubSpot is essential."
        },
        {
            "title": "Sales Representative",
            "location": "Istanbul",
            "company": "GlobalTrade",
            "description": "Looking for a driven Sales Representative to join our team. Responsibilities include Cold Calling, Lead Generation, and closing deals. Experience with Salesforce CRM is required. Excellent communication skills are a must."
        },
        {
            "title": "Mechanical Engineer",
            "location": "Bursa",
            "company": "AutoParts Inc.",
            "description": "Seeking a Mechanical Engineer to design automotive parts. Must have experience with AutoCAD, SolidWorks, and Thermodynamics. Engineering degree is required."
        },

        # --- ORTAK TEST (Turnusol) ---
        {
            "title": "Full Stack Web Developer",
            "location": "London (Hybrid)",
            "company": "StartUp X",
            "description": "We are looking for a developer who can handle both frontend and backend. Must have: JavaScript, Node.js, and HTML/CSS. Nice to have: Database management and API design. Ideally, you have a Computer Science background."
        }
    ]

    count = 0
    for job in test_jobs:
        try:
            # 1. Metni Birleştir
            combined_text = f"{job['title']} {job['description']}"

            # 2. NLP Analizi (JSON)
            reqs = nlp_service.analyze_job_description(combined_text)
            req_json = json.dumps(reqs)

            # 3. VEKTÖR HESAPLAMA (Önemli!)
            doc = nlp_service.nlp(combined_text)
            vector_blob = pickle.dumps(doc.vector)

            # 4. Ekle
            cursor.execute("""
                INSERT INTO jobs (title, location, description, company, employer_id, requirements_json, vector_blob) 
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (job['title'], job['location'], job['description'], job['company'], employer_id, req_json, vector_blob))
            
            count += 1
            print(f"   + Eklendi: {job['title']}")

        except Exception as e:
            print(f"   ! Hata ({job['title']}): {e}")

    conn.commit()
    conn.close()
    print(f"\n>>> TOPLAM {count} TEST İLANI EKLENDİ VE VEKTÖRLENDİ.")

if __name__ == "__main__":
    add_test_scenarios()