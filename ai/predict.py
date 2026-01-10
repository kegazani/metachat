import pickle
import numpy as np
from pathlib import Path
from typing import Optional, Dict

EMOTION_NAMES = {
    1: 'Baseline (спокойствие)',
    2: 'Stress (стресс)',
    3: 'Amusement (веселье)',
    4: 'Meditation (медитация)'
}

class EmotionPredictor:
    def __init__(self, model_dir: str = 'model'):
        self.model_dir = Path(model_dir)
        self.models = {}
        self.scaler = None
        self.load_models()
    
    def load_models(self):
        scaler_path = self.model_dir / 'scaler.pkl'
        if not scaler_path.exists():
            raise FileNotFoundError(f"Скейлер не найден: {scaler_path}")
        
        self.scaler = pickle.load(open(scaler_path, 'rb'))
        
        for emotion_id in [1, 2, 3, 4]:
            model_path = self.model_dir / f'model_{emotion_id}.pkl'
            if not model_path.exists():
                raise FileNotFoundError(f"Модель {emotion_id} не найдена: {model_path}")
            
            self.models[emotion_id] = pickle.load(open(model_path, 'rb'))
    
    def predict(self, mean_hr: float) -> Dict:
        if mean_hr is None:
            return {
                'error': 'Heart rate (Mean_HR) обязателен'
            }
        
        features = np.array([[mean_hr]])
        features_scaled = self.scaler.transform(features)
        
        probabilities = {}
        
        for emotion_id, model in self.models.items():
            prob = model.predict_proba(features_scaled)[0]
            probabilities[emotion_id] = float(prob[1])
        
        predicted_emotion_id = max(probabilities.items(), key=lambda x: x[1])[0]
        confidence = probabilities[predicted_emotion_id]
        
        return {
            'predicted_emotion_id': predicted_emotion_id,
            'predicted_emotion': EMOTION_NAMES[predicted_emotion_id],
            'confidence': confidence,
            'probabilities': {
                EMOTION_NAMES[k]: v for k, v in probabilities.items()
            }
        }

def predict_from_apple_watch(heart_rate: float) -> Dict:
    predictor = EmotionPredictor()
    
    if heart_rate is None:
        return {'error': 'heart_rate (Mean_HR) обязателен'}
    
    return predictor.predict(heart_rate)

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 2:
        print("Использование: python predict.py <heart_rate>")
        print("Пример: python predict.py 72.0")
        sys.exit(1)
    
    try:
        heart_rate = float(sys.argv[1])
        
        result = predict_from_apple_watch(heart_rate=heart_rate)
        
        if 'error' in result:
            print(f"❌ Ошибка: {result['error']}")
        else:
            print(f"\n🎯 Предсказанная эмоция: {result['predicted_emotion']}")
            print(f"📊 Уверенность: {result['confidence']:.1%}")
            print(f"\n📈 Вероятности для всех эмоций:")
            for emotion, prob in result['probabilities'].items():
                bar = '█' * int(prob * 50)
                print(f"   {emotion:30s} {prob:.1%} {bar}")
    
    except ValueError as e:
        print(f"❌ Ошибка: Неверный формат данных - {e}")
    except Exception as e:
        print(f"❌ Ошибка: {e}")
