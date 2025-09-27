# backend/main.py
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import pdfplumber
import io

app = FastAPI(title="Career AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # geliştirme: tüm origin'lere izin; prod'da kısıtla
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/ping")
def ping():
    return {"msg": "pong"}

@app.post("/upload_cv")
async def upload_cv(file: UploadFile = File(...)):
    # Basit: pdf ise text çıkar, değilse hata ver
    if not file.filename.lower().endswith(".pdf"):
        return {"error": "Sadece PDF yükleyin."}
    content = await file.read()
    text = ""
    with pdfplumber.open(io.BytesIO(content)) as pdf:
        for page in pdf.pages:
            text += page.extract_text() or ""
    # şimdilik sadece metni döndürelim; ileride NLP analizini buraya ekleyeceğiz
    return {"filename": file.filename, "text_snippet": text[:1000]}
