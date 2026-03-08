import requests
import json

BASE_URL = "http://localhost:8000"

def test_health():
    print("=" * 60)
    print("1. Health Check")
    print("=" * 60)
    response = requests.get(f"{BASE_URL}/health")
    print(json.dumps(response.json(), indent=2))

def test_models_info():
    print("\n" + "=" * 60)
    print("2. Models Info")
    print("=" * 60)
    response = requests.get(f"{BASE_URL}/models/info")
    data = response.json()
    
    print(f"\nДоступные модели: {len(data['models'])}")
    for model in data['models']:
        print(f"\n  • {model['name']}")
        print(f"    Тип: {model['type']}")
        print(f"    Алгоритм: {model['algorithm']}")
        print(f"    F1-Score: {model['f1_score']:.4f}")
        print(f"    Accuracy: {model['accuracy']:.4f}")
    
    print(f"\nВсего признаков: {data['features']['total']}")
    print(f"Категории: {data['features']['categories']}")

def test_predictions():
    print("\n" + "=" * 60)
    print("3. Predictions Test")
    print("=" * 60)
    
    rr_calm = [850, 860, 845, 855, 840, 865, 850, 855, 845, 860,
               855, 850, 860, 845, 855, 850, 860, 855, 845, 850]
    
    rr_stress = [650, 680, 620, 700, 590, 720, 610, 690, 630, 670,
                 600, 710, 640, 660, 620, 680, 600, 700, 650, 630]
    
    print("\n3.1 Binary Model (Stress Detection)")
    print("-" * 60)
    
    for label, rr_data in [("Calm", rr_calm), ("Stress", rr_stress)]:
        response = requests.post(
            f"{BASE_URL}/predict",
            json={"rr_intervals_ms": rr_data, "model_type": "binary"}
        )
        result = response.json()
        print(f"{label:10s} → {result['predicted_emotion']:15s} (confidence: {result['confidence']:.1%}, stress_prob: {result.get('stress_probability', 0):.1%})")
    
    print("\n3.2 4-Class Model (Emotion Classification)")
    print("-" * 60)
    
    for label, rr_data in [("Calm", rr_calm), ("Stress", rr_stress)]:
        response = requests.post(
            f"{BASE_URL}/predict",
            json={"rr_intervals_ms": rr_data, "model_type": "4class"}
        )
        result = response.json()
        print(f"{label:10s} → {result['predicted_emotion']:15s} (confidence: {result['confidence']:.1%})")
        if 'probabilities' in result:
            probs = result['probabilities']
            print(f"            Probabilities: " + ", ".join([f"{k}: {v:.1%}" for k, v in probs.items()]))
    
    print("\n3.3 Hierarchical Model")
    print("-" * 60)
    
    for label, rr_data in [("Calm", rr_calm), ("Stress", rr_stress)]:
        response = requests.post(
            f"{BASE_URL}/predict",
            json={"rr_intervals_ms": rr_data, "model_type": "hierarchical"}
        )
        result = response.json()
        print(f"{label:10s} → {result['predicted_emotion']:15s} (confidence: {result['confidence']:.1%})")

if __name__ == "__main__":
    try:
        test_health()
        test_models_info()
        test_predictions()
        
        print("\n" + "=" * 60)
        print("✓ Все тесты пройдены успешно")
        print("=" * 60)
        
    except requests.exceptions.ConnectionError:
        print("\n❌ Ошибка: Сервер не запущен")
        print("Запустите: python backend.py")
    except Exception as e:
        print(f"\n❌ Ошибка: {e}")
