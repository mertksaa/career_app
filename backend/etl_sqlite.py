# etl_sqlite.py
import pandas as pd
import re
import os
import json
from sqlalchemy import create_engine
from pathlib import Path

# Ayarlar
BASE_DIR = Path(__file__).resolve().parent
CSV_PATH = BASE_DIR / "jobs.csv"   # Kaggle'dan indirdiğin dosya buraya koyulacak
SQLITE_PATH = BASE_DIR / "career.db"
TABLE_NAME = "job_postings"

# Basit master skill list (başlangıç)
MASTER_SKILLS = [
    "python","sql","java","javascript","react","node","django","flask",
    "pandas","numpy","tensorflow","docker","kubernetes","aws","excel","tableau",
    "spark","airflow","flutter","dart","ios","android","selenium","testing"
]

def normalize_text(s):
    if not isinstance(s, str):
        return ""
    s = s.lower()
    s = re.sub(r'\s+', ' ', s)
    s = re.sub(r'[^a-z0-9\s]', ' ', s)
    return s.strip()

def extract_skills(text):
    t = normalize_text(text)
    found = set()
    for skill in MASTER_SKILLS:
        if re.search(r'\b' + re.escape(skill) + r'\b', t):
            found.add(skill)
    return list(found)

def main():
    if not CSV_PATH.exists():
        print(f"ERROR: CSV file not found at {CSV_PATH}")
        return

    print("Reading CSV (this may take a while for large files)...")
    df = pd.read_csv(CSV_PATH)
    print(f"Loaded {len(df)} rows from CSV")

    # Normalize column names (küçült)
    df.columns = [c.strip().lower() for c in df.columns]

    # Try to find useful columns
    title_col = None
    desc_col = None
    for c in df.columns:
        if c in ("title","job_title","position","name"):
            title_col = c
        if c in ("description","job_description","detail","requirements","jobdesc"):
            desc_col = c
    # fallback to any columns
    if title_col is None:
        title_col = df.columns[0]
    if desc_col is None:
        if len(df.columns) > 1:
            desc_col = df.columns[1]
        else:
            desc_col = title_col

    print(f"Using title column: {title_col}, description column: {desc_col}")

    # Build combined text and extract skills
    combined_texts = []
    skills_list = []
    for idx, row in df.iterrows():
        title = str(row.get(title_col,"") or "")
        desc = str(row.get(desc_col,"") or "")
        combined = f"{title} {desc}"
        norm = normalize_text(combined)
        skills = extract_skills(combined)
        combined_texts.append(norm)
        skills_list.append(skills)
        if (idx+1) % 500 == 0:
            print(f"Processed {idx+1} rows...")

    # Add to df
    df["normalized_text"] = combined_texts
    df["skills_extracted"] = skills_list

    # Convert list columns to JSON strings so SQLite can store them
    df["skills_extracted"] = df["skills_extracted"].apply(json.dumps)
    # Ensure normalized_text is a string
    df["normalized_text"] = df["normalized_text"].astype(str)

    # Save to sqlite
    engine = create_engine(f"sqlite:///{SQLITE_PATH}")
    print(f"Saving to SQLite DB at {SQLITE_PATH} ... (overwrites table if exists)")
    # drop unnamed index columns if present
    cols_to_save = [col for col in df.columns if not col.lower().startswith("unnamed")]
    df_to_db = df[cols_to_save]
    df_to_db.to_sql(TABLE_NAME, con=engine, if_exists="replace", index=False)
    print("Saved to DB. Done.")

if __name__ == "__main__":
    main()
