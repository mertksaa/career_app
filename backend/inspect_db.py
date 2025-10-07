# inspect_db.py
import sqlite3, json

DB = "career.db"

def main():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM job_postings")
    total = cur.fetchone()[0]
    print("Total rows in job_postings:", total)
    print("\nFirst 5 rows (title -> skills_extracted):\n")
    cur.execute("SELECT title, normalized_text, skills_extracted FROM job_postings LIMIT 5")
    rows = cur.fetchall()
    for r in rows:
        title, norm, skills_json = r
        try:
            skills = json.loads(skills_json) if skills_json else []
        except Exception:
            skills = skills_json
        print("-", title, "=>", skills)
    conn.close()

if __name__ == "__main__":
    main()
