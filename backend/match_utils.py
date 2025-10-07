# match_utils.py
import sqlite3
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

DB = "career.db"
TABLE = "job_postings"

# olası sütun isimleri için alternatif listeler
POSSIBLE_TITLE_COLS = ["title", "job_title", "position", "name"]
POSSIBLE_COMPANY_COLS = ["company", "company_profile", "employer", "company_name"]
POSSIBLE_LOCATION_COLS = ["location", "city", "area"]
POSSIBLE_TEXT_COLS = ["normalized_text", "description", "requirements", "job_description", "detail"]

def get_table_columns(conn, table_name):
    cur = conn.cursor()
    cur.execute(f"PRAGMA table_info({table_name})")
    cols = [row[1] for row in cur.fetchall()]  # row[1] is column name
    return cols

def choose_column(available_cols, candidates):
    for c in candidates:
        if c in available_cols:
            return c
    return None

def load_jobs_from_sqlite(limit=None):
    conn = sqlite3.connect(DB)
    available = get_table_columns(conn, TABLE)
    # pick appropriate columns
    title_col = choose_column(available, POSSIBLE_TITLE_COLS) or available[0]
    company_col = choose_column(available, POSSIBLE_COMPANY_COLS) or None
    location_col = choose_column(available, POSSIBLE_LOCATION_COLS) or None
    text_col = choose_column(available, POSSIBLE_TEXT_COLS) or None

    # Build select list dynamically
    select_cols = [title_col]
    if company_col:
        select_cols.append(company_col)
    else:
        select_cols.append("'' as company")
    if location_col:
        select_cols.append(location_col)
    else:
        select_cols.append("'' as location")
    if text_col:
        select_cols.append(text_col)
    else:
        select_cols.append("'' as normalized_text")

    q = f"SELECT rowid, {', '.join(select_cols)} FROM {TABLE}"
    if limit:
        q += f" LIMIT {int(limit)}"

    cur = conn.cursor()
    cur.execute(q)
    rows = cur.fetchall()
    conn.close()

    ids = [r[0] for r in rows]
    titles = [r[1] for r in rows]
    companies = [r[2] for r in rows]
    locations = [r[3] for r in rows]
    texts = [r[4] if r[4] is not None else "" for r in rows]

    jobs = [{"id": ids[i], "title": titles[i], "company": companies[i], "location": locations[i], "text": texts[i]} for i in range(len(rows))]
    return jobs, texts

def build_tfidf(texts, max_features=20000):
    vectorizer = TfidfVectorizer(max_features=max_features, ngram_range=(1,2))
    tfidf = vectorizer.fit_transform(texts)
    return vectorizer, tfidf

def match_query(query_text, vectorizer, tfidf_matrix, jobs, top_k=10):
    q_vec = vectorizer.transform([query_text])
    sims = cosine_similarity(q_vec, tfidf_matrix).flatten()
    top_idx = np.argsort(-sims)[:top_k]
    results = []
    for idx in top_idx:
        score = float(sims[idx])
        job = jobs[idx]
        results.append({
            "job_id": job["id"],
            "title": job["title"],
            "company": job["company"],
            "location": job["location"],
            "score": round(score, 4)
        })
    return results
