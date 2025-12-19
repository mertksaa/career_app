import spacy
from spacy.pipeline import EntityRuler
import json
import os

class NLPService:
    def __init__(self):
        print("NLP Modeli yükleniyor (en_core_web_md)...")
        try:
            self.nlp = spacy.load("en_core_web_md")
        except OSError:
            print("Model bulunamadı! 'python -m spacy download en_core_web_md' çalıştırın.")
            raise

        # Skill listesini yükle ve Entity Ruler'a ekle
        self._add_skill_ruler()

        # Ağırlıklandırma için anahtar kelimeler
        self.must_have_keywords = ["required", "must", "essential", "core", "mandatory", "minimum", "proficiency"]
        self.nice_to_have_keywords = ["plus", "bonus", "preferred", "advantage", "desirable", "nice to have"]

    def _add_skill_ruler(self):
        # Mevcut skill listesini oku
        current_dir = os.path.dirname(os.path.abspath(__file__))
        skills_path = os.path.join(current_dir, "skills.json")
        
        try:
            with open(skills_path, "r", encoding="utf-8") as f:
                skills_data = json.load(f)
        except FileNotFoundError:
            print("UYARI: skills.json bulunamadı. Boş liste kullanılıyor.")
            skills_data = []

        # Entity Ruler oluştur
        if "entity_ruler" not in self.nlp.pipe_names:
            ruler = self.nlp.add_pipe("entity_ruler", before="ner")
        else:
            ruler = self.nlp.get_pipe("entity_ruler")

        patterns = []
        for skill in skills_data:
            # Hem tam eşleşme hem de büyük/küçük harf duyarsız (LOWER) desenler
            patterns.append({"label": "SKILL", "pattern": [{"LOWER": word.lower()} for word in skill.split()]})
        
        ruler.add_patterns(patterns)

    def analyze_text(self, text: str):
        """
        Eski yöntem (Geriye dönük uyumluluk için).
        Sadece yetenek listesi (set) döndürür.
        """
        doc = self.nlp(text)
        skills = set()
        for ent in doc.ents:
            if ent.label_ == "SKILL":
                skills.add(ent.text)
        return list(skills)

    def analyze_job_description(self, text: str):
        """
        YENİ YÖNTEM: İlan metnini analiz eder ve yetenekleri ağırlıklandırır.
        """
        doc = self.nlp(text)
        
        must_have_skills = set()
        nice_to_have_skills = set()
        normal_skills = set()

        # Cümle cümle analiz et
        for sent in doc.sents:
            sentence_text = sent.text.lower()
            
            # Bu cümlede geçen yetenekleri bul
            sent_skills = set()
            for ent in sent.ents:
                if ent.label_ == "SKILL":
                    sent_skills.add(ent.text)
            
            if not sent_skills:
                continue

            # Cümlenin bağlamına (context) bak
            is_must = any(keyword in sentence_text for keyword in self.must_have_keywords)
            is_nice = any(keyword in sentence_text for keyword in self.nice_to_have_keywords)

            if is_must:
                must_have_skills.update(sent_skills)
            elif is_nice:
                nice_to_have_skills.update(sent_skills)
            else:
                normal_skills.update(sent_skills)

        # Çakışmaları temizle (Eğer bir yetenek hem must hem nice listesindeyse, must kalsın)
        nice_to_have_skills -= must_have_skills
        normal_skills -= must_have_skills
        normal_skills -= nice_to_have_skills

        return {
            "must_have": list(must_have_skills),
            "nice_to_have": list(nice_to_have_skills),
            "normal": list(normal_skills),
            "all_skills": list(must_have_skills | nice_to_have_skills | normal_skills)
        }

# Global instance (main.py tarafından kullanılacak)
nlp_service = NLPService()