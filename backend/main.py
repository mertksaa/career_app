# backend/main.py
import json
import io
import re
import os
from typing import List, Optional
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from match_utils import load_jobs_from_sqlite, build_tfidf, match_query
import pdfplumber

APP_DIR = os.path.dirname(__file__)

app = FastAPI(title="Career AI Backend (basic)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # geliştirme için * ; prod ortamında kısıtla
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

print("Loading jobs and building TF-IDF at startup...")
jobs, texts = load_jobs_from_sqlite(limit=None)   # tüm veriyi al (büyükse limit ver)
vectorizer, tfidf_matrix = build_tfidf(texts, max_features=20000)
print("Startup done.")

# --- simple normalize function (same as ETL) ---
def normalize_text(s: str) -> str:
    if not isinstance(s, str):
        return ""
    s = s.lower()
    s = re.sub(r'\s+', ' ', s)
    s = re.sub(r'[^a-z0-9\s]', ' ', s)
    return s.strip()

class MatchRequest(BaseModel):
    text: str
    top_k: int = 10

@app.post("/match_text")
async def match_text_endpoint(req: MatchRequest):
    q = normalize_text(req.text)
    results = match_query(q, vectorizer, tfidf_matrix, jobs, top_k=req.top_k)
    return {"query": req.text, "results": results}

    
# Load job roles from json
JOB_ROLES_PATH = os.path.join(APP_DIR, "job_roles.json")
with open(JOB_ROLES_PATH, "r", encoding="utf-8") as f:
    job_roles = json.load(f)

# build master skill set
_master_skills = set()
for r in job_roles:
    for s in r.get("skills", []):
        _master_skills.add(s.lower())
master_skills = sorted(list(_master_skills), key=lambda x: -len(x))  # longer first (phrase matching)

class AnalyzeRequest(BaseModel):
    text: Optional[str] = None
    skills: Optional[List[str]] = None

def extract_skills_from_text(text: str):
    """
    Very simple rule-based extractor:
    - Lowercases text and looks for whole-word matches of known skills.
    - Returns unique list of matched skills.
    """
    if not text:
        return []
    t = text.lower()
    found = set()
    # normalize separators
    t = re.sub(r"[-_/]", " ", t)
    for skill in master_skills:
        # create a regex to match whole words, but allow +, # or dots in skill names
        pattern = r"(?<!\w)" + re.escape(skill) + r"(?!\w)"
        if re.search(pattern, t, flags=re.IGNORECASE):
            found.add(skill)
    return sorted(list(found))

@app.get("/ping")
def ping():
    return {"msg": "pong"}

@app.post("/upload_cv")
async def upload_cv(file: UploadFile = File(...)):
    # Accept PDF only for now
    if not file.filename.lower().endswith(".pdf"):
        return {"error": "Sadece PDF yükleyin."}
    content = await file.read()
    text = ""
    try:
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
    except Exception as e:
        return {"error": f"PDF okunurken hata: {e}"}
    snippet = text[:2000]
    # return snippet; client may call /analyze with this text
    return {"filename": file.filename, "text_snippet": snippet}

@app.post("/analyze")
async def analyze(req: AnalyzeRequest):
    # Determine input skills (either provided or extracted from text)
    if req.skills and isinstance(req.skills, list) and len(req.skills) > 0:
        user_skills = [s.strip().lower() for s in req.skills if s and isinstance(s, str)]
    else:
        user_skills = extract_skills_from_text(req.text or "")
    user_skills_set = set(user_skills)

    results = []
    for r in job_roles:
        required = [s.lower() for s in r.get("skills", [])]
        req_set = set(required)
        matched = sorted(list(req_set.intersection(user_skills_set)))
        match_ratio = round(len(matched) / len(req_set), 2) if len(req_set) > 0 else 0.0
        missing = sorted(list(req_set - user_skills_set))
        results.append({
            "name": r.get("name"),
            "match": match_ratio,
            "matched": matched,
            "missing": missing
        })

    results_sorted = sorted(results, key=lambda x: x["match"], reverse=True)
    return {"roles": results_sorted, "detected_skills": sorted(list(user_skills_set))}

@app.get("/jobs")
def list_jobs():
    # convenience endpoint to inspect job roles
    return {"count": len(job_roles), "jobs": job_roles}
