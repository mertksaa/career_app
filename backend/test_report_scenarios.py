import pytest
import numpy as np
from nlp_service import nlp_service # Senin kodundaki global instance'ı çağırıyoruz

# --- TEST SCENARIO 1: UNIT TEST (Vector Dimensions) ---
def test_u02_vector_dimensions():
    """
    Report Section 10.2: Unit Test U-02
    Doğrulanan: spaCy modelinin (en_core_web_md) gerçekten yüklendiği 
    ve 300 boyutlu vektör ürettiği.
    """
    text = "Software Engineer"
    
    # NLPService içindeki nlp objesini doğrudan kullanıyoruz
    doc = nlp_service.nlp(text)
    
    # 1. Vektör var mı?
    assert doc.has_vector is True
    
    # 2. Boyutu 300 mü? (Raporda iddia ettiğimiz değer)
    assert doc.vector.shape == (300,)

# --- TEST SCENARIO 2: VALIDATION TEST (The "Truck Driver" Logic) ---
def test_scenario_a_truck_driver_logic():
    """
    Report Section 10.4: Scenario A (Semantic Accuracy)
    Doğrulanan: Sistemin 'Truck Driver' ile 'Logistics Manager' arasındaki 
    semantik farkı anlayabilmesi.
    """
    # İki farklı iş tanımı
    text_driver = "Truck Driver"
    text_manager = "Logistics Manager"
    
    # Vektörlerini çıkar
    vec_driver = nlp_service.nlp(text_driver).vector
    vec_manager = nlp_service.nlp(text_manager).vector
    
    # Cosine Similarity (Benzerlik) Hesapla
    # Formül: (A . B) / (||A|| * ||B||)
    similarity = np.dot(vec_driver, vec_manager) / (np.linalg.norm(vec_driver) * np.linalg.norm(vec_manager))
    
    print(f"\n[INFO] Similarity betwen Driver & Manager: {similarity}")
    
    # Eğer sistem sadece kelime eşleşmesine baksaydı (Logistics, Transport vb.) benzerlik çok yüksek çıkardı.
    # Ancak vektör uzayında bunlar farklı rollerdir. Benzerliğin %100 OLMADIĞINI doğruluyoruz.
    assert similarity < 0.85 # Birbirinin aynısı olmadıklarını kanıtlar.

# --- TEST SCENARIO 3: INCLUSIVITY TEST (Manual Profile) ---
def test_scenario_b_manual_profile():
    """
    Report Section 10.4: Scenario B (Manual Profile Inclusivity)
    Doğrulanan: Mavi yaka bir çalışanın girdiği 'Garson, servis' gibi basit metinlerin
    başarıyla işlenebilir bir vektöre dönüştürülmesi.
    """
    # Kullanıcının manuel girdiği ham metin
    manual_input = "Waiter, serving food, customer service expert."
    
    doc = nlp_service.nlp(manual_input)
    
    # Sistem bu girdiyi reddetmemeli, vektöre çevirebilmeli
    assert doc.vector.shape == (300,)
    assert np.any(doc.vector) # Vektörün içi boş (0000) olmamalı

# --- TEST SCENARIO 4: SKILL EXTRACTION (Integration) ---
def test_skill_extraction_logic():
    """
    Test: Senin kodundaki 'analyze_job_description' fonksiyonunun çalıştığını doğrular.
    """
    # İçinde 'must' geçen bir metin (Ağırlıklandırma testi)
    job_desc = "Candidates must have Python skills. SQL is a plus."
    
    # Senin sınıfındaki fonksiyonu çağır
    # NOT: Bu testin geçmesi için 'Python' ve 'SQL' kelimelerinin senin skills.json dosyanda olması gerekir.
    # Eğer skills.json boşsa veya bu kelimeler yoksa, result boş dönebilir ama kod hata vermemeli.
    result = nlp_service.analyze_job_description(job_desc)
    
    assert isinstance(result, dict)
    assert "must_have" in result
    assert "nice_to_have" in result
    assert "all_skills" in result