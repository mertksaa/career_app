# match_server.py (test script)
from match_utils import load_jobs_from_sqlite, build_tfidf, match_query

print("Loading jobs from DB...")
jobs, texts = load_jobs_from_sqlite(limit=2000)  # ilk 2000 kaydı alıyoruz (demo)
print("Building TF-IDF matrix...")
vectorizer, tfidf = build_tfidf(texts)
print("Ready. Run a sample match:")

sample = "experienced python developer with sql and pandas knowledge"
res = match_query(sample, vectorizer, tfidf, jobs, top_k=5)
for r in res:
    print(r)
