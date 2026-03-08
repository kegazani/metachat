import pickle
import numpy as np
from pathlib import Path
from typing import Optional, Dict, List
from scipy.signal import butter, sosfiltfilt, find_peaks, welch
from scipy.stats import skew, kurtosis
from scipy.interpolate import interp1d

EMOTION_NAMES_4CLASS = {
    0: 'Baseline',
    1: 'Stress',
    2: 'Amusement',
    3: 'Meditation'
}

EMOTION_NAMES_BINARY = {
    0: 'Non-Stress',
    1: 'Stress'
}

EMOTION_NAMES_3CLASS = {
    0: 'Baseline',
    1: 'Amusement', 
    2: 'Meditation'
}

FEATURE_NAMES = [
    'mean_rr', 'sdnn', 'rmssd', 'nn50', 'pnn50', 'nn20', 'pnn20',
    'mean_hr', 'sdsd', 'cvnn', 'cvsd',
    'median_rr', 'mad_rr', 'rr_range', 'rr_iqr',
    'hr_max', 'hr_min', 'hr_range',
    'rr_skew', 'rr_kurt',
    'vlf_power', 'lf_power', 'hf_power', 'total_power',
    'lf_hf_ratio', 'lf_norm', 'hf_norm',
    'sd1', 'sd2', 'sd1_sd2_ratio'
]

class EmotionPredictor:
    def __init__(self, model_dir: str = 'model', mode: str = 'hierarchical'):
        self.model_dir = Path(model_dir)
        self.mode = mode
        self.model_binary = None
        self.model_3class = None
        self.model_4class = None
        self.scaler = None
        self.load_models()
    
    def load_models(self):
        scaler_path = self.model_dir / 'scaler.pkl'
        if scaler_path.exists():
            self.scaler = pickle.load(open(scaler_path, 'rb'))
        
        if self.mode == 'hierarchical':
            binary_path = self.model_dir / 'model_binary.pkl'
            class3_path = self.model_dir / 'model_3class.pkl'
            
            if binary_path.exists() and class3_path.exists():
                self.model_binary = pickle.load(open(binary_path, 'rb'))
                self.model_3class = pickle.load(open(class3_path, 'rb'))
            else:
                self.mode = '4class'
        
        if self.mode == 'binary':
            binary_path = self.model_dir / 'model_binary.pkl'
            if binary_path.exists():
                self.model_binary = pickle.load(open(binary_path, 'rb'))
        
        if self.mode == '4class':
            class4_path = self.model_dir / 'model_4class.pkl'
            if class4_path.exists():
                self.model_4class = pickle.load(open(class4_path, 'rb'))
    
    def extract_features_from_rr(self, rr_intervals_ms: List[float]) -> Optional[np.ndarray]:
        rr_ms = np.array(rr_intervals_ms)
        rr_ms = rr_ms[(rr_ms > 300) & (rr_ms < 2000)]
        
        if len(rr_ms) < 8:
            return None
        
        nn_diffs = np.diff(rr_ms)
        
        mean_rr = np.mean(rr_ms)
        sdnn = np.std(rr_ms, ddof=1)
        rmssd = np.sqrt(np.mean(nn_diffs ** 2))
        nn50 = np.sum(np.abs(nn_diffs) > 50)
        pnn50 = (nn50 / len(nn_diffs)) * 100 if len(nn_diffs) > 0 else 0
        nn20 = np.sum(np.abs(nn_diffs) > 20)
        pnn20 = (nn20 / len(nn_diffs)) * 100 if len(nn_diffs) > 0 else 0
        mean_hr = 60000 / mean_rr
        sdsd = np.std(nn_diffs, ddof=1) if len(nn_diffs) > 1 else 0
        cvnn = (sdnn / mean_rr) * 100 if mean_rr > 0 else 0
        cvsd = (rmssd / mean_rr) * 100 if mean_rr > 0 else 0
        median_rr = np.median(rr_ms)
        mad_rr = np.median(np.abs(rr_ms - median_rr))
        rr_range = np.max(rr_ms) - np.min(rr_ms)
        rr_iqr = np.percentile(rr_ms, 75) - np.percentile(rr_ms, 25)
        hr_max = 60000 / np.min(rr_ms)
        hr_min = 60000 / np.max(rr_ms)
        hr_range_val = hr_max - hr_min
        
        rr_skew = skew(rr_ms)
        rr_kurt = kurtosis(rr_ms)
        
        try:
            rr_times = np.cumsum(rr_ms) / 1000.0
            rr_times = rr_times - rr_times[0]
            
            if len(rr_times) > 4 and rr_times[-1] > 0:
                fs_interp = 4.0
                t_interp = np.arange(0, rr_times[-1], 1.0/fs_interp)
                
                if len(t_interp) > 16:
                    interp_func = interp1d(rr_times, rr_ms, kind='cubic', fill_value='extrapolate')
                    rr_interp = interp_func(t_interp)
                    
                    freqs, psd = welch(rr_interp, fs=fs_interp, nperseg=min(len(rr_interp), 64))
                    
                    vlf_mask = (freqs >= 0.003) & (freqs < 0.04)
                    lf_mask = (freqs >= 0.04) & (freqs < 0.15)
                    hf_mask = (freqs >= 0.15) & (freqs < 0.4)
                    
                    vlf_power = np.trapezoid(psd[vlf_mask], freqs[vlf_mask]) if np.any(vlf_mask) else 0
                    lf_power = np.trapezoid(psd[lf_mask], freqs[lf_mask]) if np.any(lf_mask) else 0
                    hf_power = np.trapezoid(psd[hf_mask], freqs[hf_mask]) if np.any(hf_mask) else 0
                    
                    total_power = vlf_power + lf_power + hf_power
                    lf_hf_ratio = lf_power / hf_power if hf_power > 0 else 0
                    lf_norm = (lf_power / (lf_power + hf_power)) * 100 if (lf_power + hf_power) > 0 else 0
                    hf_norm = (hf_power / (lf_power + hf_power)) * 100 if (lf_power + hf_power) > 0 else 0
                else:
                    vlf_power = lf_power = hf_power = total_power = 0
                    lf_hf_ratio = lf_norm = hf_norm = 0
            else:
                vlf_power = lf_power = hf_power = total_power = 0
                lf_hf_ratio = lf_norm = hf_norm = 0
        except:
            vlf_power = lf_power = hf_power = total_power = 0
            lf_hf_ratio = lf_norm = hf_norm = 0
        
        sd1 = np.sqrt(0.5 * np.var(nn_diffs)) if len(nn_diffs) > 1 else 0
        sd2 = np.sqrt(2 * np.var(rr_ms) - 0.5 * np.var(nn_diffs)) if len(nn_diffs) > 1 else 0
        sd1_sd2_ratio = sd1 / sd2 if sd2 > 0 else 0
        
        features = np.array([
            mean_rr, sdnn, rmssd, nn50, pnn50, nn20, pnn20,
            mean_hr, sdsd, cvnn, cvsd,
            median_rr, mad_rr, rr_range, rr_iqr,
            hr_max, hr_min, hr_range_val,
            rr_skew, rr_kurt,
            vlf_power, lf_power, hf_power, total_power,
            lf_hf_ratio, lf_norm, hf_norm,
            sd1, sd2, sd1_sd2_ratio
        ])
        
        return features
    
    def predict(self, mean_hr: float) -> Dict:
        mean_rr_ms = 60000.0 / mean_hr if mean_hr > 0 else 1000.0
        
        num_intervals = 20
        std_rr = mean_rr_ms * 0.05
        
        rr_intervals = np.random.normal(mean_rr_ms, std_rr, num_intervals)
        rr_intervals = np.clip(rr_intervals, 300, 2000)
        
        return self.predict_from_rr_intervals(rr_intervals.tolist())
    
    def predict_from_rr_intervals(self, rr_intervals_ms: List[float]) -> Dict:
        features = self.extract_features_from_rr(rr_intervals_ms)
        
        if features is None:
            return {'error': 'Not enough RR intervals (minimum 8 required)'}
        
        features = np.nan_to_num(features, nan=0, posinf=0, neginf=0)
        features_scaled = self.scaler.transform(features.reshape(1, -1))
        
        if self.mode == 'hierarchical':
            return self._predict_hierarchical(features_scaled, features)
        elif self.mode == 'binary':
            return self._predict_binary(features_scaled, features)
        else:
            return self._predict_4class(features_scaled, features)
    
    def _predict_hierarchical(self, features_scaled, features_raw) -> Dict:
        is_stress = int(self.model_binary.predict(features_scaled)[0])
        stress_proba = self.model_binary.predict_proba(features_scaled)[0]
        
        if is_stress == 1:
            predicted_class = 1
            emotion_name = 'Stress'
            confidence = float(stress_proba[1])
            probabilities = {
                EMOTION_NAMES_4CLASS[0]: float(stress_proba[0] * 0.33),
                EMOTION_NAMES_4CLASS[1]: float(stress_proba[1]),
                EMOTION_NAMES_4CLASS[2]: float(stress_proba[0] * 0.33),
                EMOTION_NAMES_4CLASS[3]: float(stress_proba[0] * 0.34)
            }
        else:
            pred_3class = int(self.model_3class.predict(features_scaled)[0])
            proba_3class = self.model_3class.predict_proba(features_scaled)[0]
            
            mapping = {0: 0, 1: 2, 2: 3}
            predicted_class = mapping[pred_3class]
            emotion_name = EMOTION_NAMES_4CLASS[predicted_class]
            confidence = float(proba_3class[pred_3class]) * float(stress_proba[0])
            
            probabilities = {
                EMOTION_NAMES_4CLASS[0]: float(stress_proba[0] * proba_3class[0]) if pred_3class == 0 else 0.0,
                EMOTION_NAMES_4CLASS[1]: 0.0,
                EMOTION_NAMES_4CLASS[2]: float(stress_proba[0] * proba_3class[1]) if pred_3class == 1 else 0.0,
                EMOTION_NAMES_4CLASS[3]: float(stress_proba[0] * proba_3class[2]) if pred_3class == 2 else 0.0
            }
        
        return {
            'mode': 'hierarchical',
            'predicted_emotion_id': predicted_class,
            'predicted_class': predicted_class,
            'predicted_emotion': emotion_name,
            'confidence': confidence,
            'is_stressed': is_stress == 1,
            'stress_probability': float(stress_proba[1]),
            'probabilities': probabilities,
            'features': {name: float(val) for name, val in zip(FEATURE_NAMES, features_raw)}
        }
    
    def _predict_binary(self, features_scaled, features_raw) -> Dict:
        predicted_class = int(self.model_binary.predict(features_scaled)[0])
        proba = self.model_binary.predict_proba(features_scaled)[0]
        
        return {
            'mode': 'binary',
            'predicted_emotion_id': predicted_class,
            'predicted_class': predicted_class,
            'predicted_emotion': EMOTION_NAMES_BINARY[predicted_class],
            'confidence': float(proba[predicted_class]),
            'is_stressed': predicted_class == 1,
            'probabilities': {
                EMOTION_NAMES_BINARY[i]: float(proba[i]) for i in range(2)
            },
            'features': {name: float(val) for name, val in zip(FEATURE_NAMES, features_raw)}
        }
    
    def _predict_4class(self, features_scaled, features_raw) -> Dict:
        predicted_class = int(self.model_4class.predict(features_scaled)[0])
        proba = self.model_4class.predict_proba(features_scaled)[0]
        
        return {
            'mode': '4class',
            'predicted_emotion_id': predicted_class,
            'predicted_class': predicted_class,
            'predicted_emotion': EMOTION_NAMES_4CLASS[predicted_class],
            'confidence': float(proba[predicted_class]),
            'is_stressed': predicted_class == 1,
            'probabilities': {
                EMOTION_NAMES_4CLASS[i]: float(proba[i]) for i in range(4)
            },
            'features': {name: float(val) for name, val in zip(FEATURE_NAMES, features_raw)}
        }

def predict_stress(rr_intervals_ms: List[float]) -> Dict:
    predictor = EmotionPredictor(mode='binary')
    return predictor.predict_from_rr_intervals(rr_intervals_ms)

def predict_emotion(rr_intervals_ms: List[float]) -> Dict:
    predictor = EmotionPredictor(mode='hierarchical')
    return predictor.predict_from_rr_intervals(rr_intervals_ms)

def predict_emotion_4class(rr_intervals_ms: List[float]) -> Dict:
    predictor = EmotionPredictor(mode='4class')
    return predictor.predict_from_rr_intervals(rr_intervals_ms)

SIMPLE_FEATURE_NAMES = ['mean_hr', 'sdnn', 'rmssd', 'pnn50']

class SimpleEmotionPredictor:
    def __init__(self, model_dir: str = 'model'):
        self.model_dir = Path(model_dir)
        self.model_binary = None
        self.model_4class = None
        self.scaler = None
        self.load_models()
    
    def load_models(self):
        scaler_path = self.model_dir / 'scaler_simple.pkl'
        if scaler_path.exists():
            self.scaler = pickle.load(open(scaler_path, 'rb'))
        
        binary_path = self.model_dir / 'model_simple_binary.pkl'
        if binary_path.exists():
            self.model_binary = pickle.load(open(binary_path, 'rb'))
        
        class4_path = self.model_dir / 'model_simple_4class.pkl'
        if class4_path.exists():
            self.model_4class = pickle.load(open(class4_path, 'rb'))
    
    def predict_simple_binary(self, heart_rate: float, sdnn: float, rmssd: float, pnn50: float) -> Dict:
        if self.model_binary is None or self.scaler is None:
            return {'error': 'Simple binary model not loaded'}
        
        features = np.array([[heart_rate, sdnn, rmssd, pnn50]])
        features = np.nan_to_num(features, nan=0, posinf=0, neginf=0)
        features_scaled = self.scaler.transform(features)
        
        predicted_class = int(self.model_binary.predict(features_scaled)[0])
        proba = self.model_binary.predict_proba(features_scaled)[0]
        
        return {
            'mode': 'simple_binary',
            'predicted_class': predicted_class,
            'predicted_emotion': EMOTION_NAMES_BINARY[predicted_class],
            'confidence': float(proba[predicted_class]),
            'is_stressed': predicted_class == 1,
            'probabilities': {
                EMOTION_NAMES_BINARY[i]: float(proba[i]) for i in range(2)
            }
        }
    
    def predict_simple_4class(self, heart_rate: float, sdnn: float, rmssd: float, pnn50: float) -> Dict:
        if self.model_4class is None or self.scaler is None:
            return {'error': 'Simple 4-class model not loaded'}
        
        features = np.array([[heart_rate, sdnn, rmssd, pnn50]])
        features = np.nan_to_num(features, nan=0, posinf=0, neginf=0)
        features_scaled = self.scaler.transform(features)
        
        predicted_class = int(self.model_4class.predict(features_scaled)[0])
        proba = self.model_4class.predict_proba(features_scaled)[0]
        
        return {
            'mode': 'simple_4class',
            'predicted_class': predicted_class,
            'predicted_emotion': EMOTION_NAMES_4CLASS[predicted_class],
            'confidence': float(proba[predicted_class]),
            'is_stressed': predicted_class == 1,
            'probabilities': {
                EMOTION_NAMES_4CLASS[i]: float(proba[i]) for i in range(4)
            }
        }

def predict_simple_binary(heart_rate: float, sdnn: float, rmssd: float, pnn50: float) -> Dict:
    predictor = SimpleEmotionPredictor()
    return predictor.predict_simple_binary(heart_rate, sdnn, rmssd, pnn50)

def predict_simple_4class(heart_rate: float, sdnn: float, rmssd: float, pnn50: float) -> Dict:
    predictor = SimpleEmotionPredictor()
    return predictor.predict_simple_4class(heart_rate, sdnn, rmssd, pnn50)

if __name__ == '__main__':
    print("=" * 60)
    print("Emotion Predictor - HRV Analysis")
    print("=" * 60)
    
    test_rr_calm = [850, 860, 845, 855, 840, 865, 850, 855, 845, 860,
                   855, 850, 860, 845, 855, 850, 860, 855, 845, 850]
    
    test_rr_stress = [650, 680, 620, 700, 590, 720, 610, 690, 630, 670,
                     600, 710, 640, 660, 620, 680, 600, 700, 650, 630]
    
    print("\n" + "-" * 60)
    print("Test 1: Calm RR intervals (Hierarchical)")
    print(f"Mean HR: {60000/np.mean(test_rr_calm):.1f} bpm")
    print("-" * 60)
    
    result = predict_emotion(test_rr_calm)
    if 'error' not in result:
        print(f"Prediction: {result['predicted_emotion']}")
        print(f"Confidence: {result['confidence']:.1%}")
        print(f"Is Stressed: {result['is_stressed']}")
        print(f"Stress Probability: {result['stress_probability']:.1%}")
    
    print("\n" + "-" * 60)
    print("Test 2: Stressed RR intervals (Hierarchical)")
    print(f"Mean HR: {60000/np.mean(test_rr_stress):.1f} bpm")
    print("-" * 60)
    
    result = predict_emotion(test_rr_stress)
    if 'error' not in result:
        print(f"Prediction: {result['predicted_emotion']}")
        print(f"Confidence: {result['confidence']:.1%}")
        print(f"Is Stressed: {result['is_stressed']}")
        print(f"Stress Probability: {result['stress_probability']:.1%}")
    
    print("\n" + "-" * 60)
    print("Test 3: Binary stress detection")
    print("-" * 60)
    
    result_binary = predict_stress(test_rr_stress)
    if 'error' not in result_binary:
        print(f"Prediction: {result_binary['predicted_emotion']}")
        print(f"Confidence: {result_binary['confidence']:.1%}")
