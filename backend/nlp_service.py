# backend/nlp_service.py
import spacy
import json
import re
import os

APP_DIR = os.path.dirname(__file__)
SKILLS_PATH = os.path.join(APP_DIR, "skills.json")

# --- Regex Patterns for PII ---
# E-posta için daha basit ve yaygın kullanılan bir regex
EMAIL_REGEX = r"[\w\.-]+@[\w\.-]+\.\w+"

# Basit bir telefon regex'i (farklı formatları yakalamak için geliştirilebilir)
PHONE_REGEX = r"(\+?\d{1,3}[\s-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}"


def load_skills(skills_path: str) -> list:
    """JSON dosyasından yetenek listesini okur."""
    try:
        with open(skills_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Uyarı: {skills_path} bulunamadı. Yetenekler yüklenemedi.")
        return []
    except json.JSONDecodeError:
        print(f"Hata: {skills_path} dosyası bozuk JSON formatında.")
        return []

def create_skill_patterns(skills: list) -> list:
    """
    Basit yetenek listesini spaCy EntityRuler formatına dönüştürür.
    Örn: "Python" -> [{"label": "SKILL", "pattern": [{"lower": "python"}]}]
    Örn: "Project Management" -> [{"label": "SKILL", "pattern": [{"lower": "project"}, {"lower": "management"}]}]
    """
    patterns = []
    for skill in skills:
        words = skill.split()
        pattern = [{"lower": word.lower()} for word in words]
        patterns.append({"label": "SKILL", "pattern": pattern, "id": skill})
    return patterns

def load_nlp_model():
    """
    spaCy modelini yükler ve EntityRuler'ı özel yeteneklerle günceller.
    """
    print("NLP modeli ve yetenekler yükleniyor...")
    try:
        # 'en_core_web_lg' modelini yükle
        nlp = spacy.load("en_core_web_lg")
    except OSError:
        print("Hata: 'en_core_web_lg' modeli bulunamadı.")
        print("Lütfen 'python -m spacy download en_core_web_lg' komutu ile indirin.")
        # Model yüklenemezse, sadece yetenekleri tanıyan boş bir model oluştur
        nlp = spacy.blank("en")

    # Yetenekleri JSON'dan yükle
    skills = load_skills(SKILLS_PATH)
    # Yetenekleri spaCy pattern'larına dönüştür
    skill_patterns = create_skill_patterns(skills)

    # Mevcut pipeline'a EntityRuler ekle
    if "entity_ruler" not in nlp.pipe_names:
        ruler = nlp.add_pipe("entity_ruler", before="ner")
    else:
        ruler = nlp.get_pipe("entity_ruler")
    
    ruler.add_patterns(skill_patterns)
    print("NLP modeli başarıyla yüklendi.")
    return nlp

# Modeli global olarak yükle (uygulama başladığında bir kez)
# Bu, her analyze çağrısında modeli tekrar yüklemenin önüne geçer.
NLP = load_nlp_model()


def analyze_text(text: str) -> dict:
    """
    Bir metni analiz eder ve yapılandırılmış bilgileri (yetenekler, e-posta, telefon) çıkarır.
    """
    if not text:
        return {"skills": [], "emails": [], "phones": []}
    
    doc = NLP(text)
    
    # --- Yetenekleri Çıkar (EntityRuler ve NER kullanarak) ---
    # Modelin 'SKILL' olarak etiketlediklerini ve 'ORG' (organizasyon, örn: Microsoft)
    # ve 'PRODUCT' (ürün, örn: TensorFlow) olarak etiketlediklerini topla.
    # 'id' kullanarak orijinal (büyük/küçük harf duyarlı) yetenek ismini alıyoruz.
    skills = set()
    for ent in doc.ents:
        if ent.label_ == "SKILL":
            skills.add(ent.id_) # Bizim tanımladığımız ID (örn: "Python")
        
        # Ekstra: Modelin zaten bildiği teknoloji/ürünleri de ekleyelim
        elif ent.label_ in ["PRODUCT", "ORG"]:
            # 'skills.json' listesindeki bir yetenekle eşleşiyor mu diye kontrol et
            # Bu, "TensorFlow" (PRODUCT) veya "Azure" (ORG) gibi şeyleri yakalar
            normalized_ent = ent.text.lower()
            for skill_pattern in NLP.get_pipe("entity_ruler").patterns:
                pattern_text = " ".join([p["lower"] for p in skill_pattern["pattern"]])
                if normalized_ent == pattern_text:
                    skills.add(skill_pattern["id"])
                    break

    # --- E-posta ve Telefonları Çıkar (Regex kullanarak) ---
    emails = re.findall(EMAIL_REGEX, text, re.IGNORECASE)
    phones = re.findall(PHONE_REGEX, text)
    
    # Sonuçları temizle ve tekilleştir
    results = {
        "skills": sorted(list(skills)),
        "emails": sorted(list(set(emails))),
        "phones": sorted(list(set(phones)))
    }
    
    return results

# --- Test için ---
if __name__ == "__main__":
    test_cv_text = """
    John Doe
    Software Developer
    john.doe@email.com | (555) 123-4567 | +1-555-987-6543
    
    Summary:
    Experienced software engineer with 5+ years in Python, FastAPI, and React.
    Passionate about building scalable microservices and working with AWS.
    Also skilled in Project Management and Agile methodologies.
    
    Experience:
    Sr. Developer at TechCorp (Product: TensorFlow Analytics)
    - Developed APIs using python.
    
    Education:
    B.Sc. in Computer Science
    
    My Skills:
    - java
    - node.js
    - Microsoft Azure
    """
    
    analysis_result = analyze_text(test_cv_text)
    print("\n--- ANALİZ SONUCU ---")
    print(json.dumps(analysis_result, indent=2, ensure_ascii=False))