# backend/match_utils.py

import sqlite3
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import nltk
from nltk.corpus import stopwords
from nltk.stem import PorterStemmer

# NLTK veri setlerini indir (sadece ilk çalıştırmada gerekli)
try:
    stopwords.words('english')
except LookupError:
    print("Downloading NLTK stopwords...")
    nltk.download('stopwords')

# --- Veritabanı Yardımcı Fonksiyonu ---
DB_PATH = 'career.db'

def get_db_conn():
    """Veritabanı bağlantısı oluşturur ve döndürür."""
    conn = sqlite3.connect(DB_PATH)
    return conn

# --- Metin İşleme ---
stemmer = PorterStemmer()
stop_words = set(stopwords.words('english'))

def preprocess_text(text):
    if not isinstance(text, str):
        return ""
    text = re.sub(r'<.*?>', '', text)  # HTML etiketlerini kaldır
    text = re.sub(r'[^a-zA-Z\s]', '', text, re.I|re.A)
    text = text.lower()
    text = text.strip()
    tokens = []
    for token in text.split():
        if token not in stop_words:
            tokens.append(stemmer.stem(token))
    return " ".join(tokens)

# --- Veri Yükleme ---
def load_jobs_from_sqlite(limit: int = 10_000):
    """
    SQLite veritabanından iş ilanlarını yükler.
    Sütun adlarının standart olduğu varsayılır: title, description, company, location.
    """
    print("Loading jobs from DB...")
    conn = get_db_conn()
    # Sonuçları sözlük gibi kullanmak için row_factory ayarı
    conn.row_factory = sqlite3.Row
    
    # Veritabanından belirli sütunları seç
    query = "SELECT job_id, title, description, company, location FROM jobs LIMIT ?"
    
    c = conn.cursor()
    c.execute(query, (limit,))
    
    jobs = [dict(row) for row in c.fetchall()]
    conn.close()

    if not jobs:
        print("Warning: No jobs found in the database.")
        return [], []

    # Metinleri birleştirerek işleme hazır hale getir
    texts = [
        f"{j.get('title', '')} {j.get('description', '')} {j.get('company', '')}" 
        for j in jobs
    ]
    
    print(f"Loaded {len(jobs)} jobs.")
    return jobs, texts

# --- Eşleştirme Mantığı ---
class Matcher:
    def __init__(self, texts, jobs):
        self.vectorizer = TfidfVectorizer(preprocessor=preprocess_text)
        self.job_embeddings = self.vectorizer.fit_transform(texts)
        self.jobs = jobs

    def find_matches(self, query_text, top_k=5):
        query_embedding = self.vectorizer.transform([query_text])
        cosine_similarities = cosine_similarity(query_embedding, self.job_embeddings).flatten()
        
        # En iyi N sonucu al
        related_docs_indices = cosine_similarities.argsort()[:-top_k-1:-1]
        
        results = []
        for i in related_docs_indices:
            results.append({
                "job_id": self.jobs[i]['job_id'],
                "title": self.jobs[i]['title'],
                "company": self.jobs[i]['company'],
                "location": self.jobs[i]['location'],
                "score": round(float(cosine_similarities[i]), 4)
            })
        return results