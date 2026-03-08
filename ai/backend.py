from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict
import sys
import logging
import pickle
import numpy as np
from pathlib import Path

sys.path.append(str(Path(__file__).parent))
from predict import predict_emotion, predict_stress, predict_emotion_4class, EmotionPredictor, SimpleEmotionPredictor, predict_simple_binary, predict_simple_4class

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Emotion Prediction API",
    description="AI service for emotion classification from HRV features",
    version="2.0"
)

predictor_4class = None
predictor_binary = None
predictor_simple = None

@app.on_event("startup")
async def startup_event():
    global predictor_4class, predictor_binary, predictor_simple
    
    model_dir = Path(__file__).parent / "model"
    logger.info(f"Проверка наличия моделей в: {model_dir}")
    
    required_files = ['model_4class.pkl', 'model_binary.pkl', 'scaler.pkl']
    missing_files = [f for f in required_files if not (model_dir / f).exists()]
    
    if missing_files:
        logger.error(f"Отсутствуют файлы моделей: {missing_files}")
        raise RuntimeError(f"Missing model files: {missing_files}")
    
    predictor_4class = EmotionPredictor(model_dir=str(model_dir), mode='4class')
    predictor_binary = EmotionPredictor(model_dir=str(model_dir), mode='binary')
    
    simple_files = ['model_simple_binary.pkl', 'model_simple_4class.pkl', 'scaler_simple.pkl']
    if all((model_dir / f).exists() for f in simple_files):
        predictor_simple = SimpleEmotionPredictor(model_dir=str(model_dir))
        logger.info("Упрощённые модели (4 признака) загружены успешно")
    else:
        logger.warning("Упрощённые модели не найдены, будут использоваться полные модели")
    
    logger.info("Все модели загружены успешно")
    logger.info("Доступные модели:")
    logger.info("  - 4-Class (LightGBM): F1=0.7788")
    logger.info("  - Binary (XGBoost): F1=0.9332")
    if predictor_simple:
        logger.info("  - Simple 4-Class (4 features)")
        logger.info("  - Simple Binary (4 features)")

class HeartRateRequest(BaseModel):
    heart_rate: float

class RRIntervalsRequest(BaseModel):
    rr_intervals_ms: List[float]
    model_type: Optional[str] = "4class"

class HRVMetricsRequest(BaseModel):
    heart_rate: float
    sdnn: Optional[float] = None
    rmssd: Optional[float] = None
    pnn50: Optional[float] = None
    model_type: Optional[str] = "binary"

class SimpleHRVRequest(BaseModel):
    heart_rate: float
    sdnn: Optional[float] = None
    rmssd: Optional[float] = None
    pnn50: Optional[float] = None
    model_type: Optional[str] = "4class"

class LegacyEmotionResponse(BaseModel):
    predicted_emotion_id: int
    predicted_emotion: str
    confidence: float
    probabilities: Dict[str, float]

class EmotionPrediction(BaseModel):
    mode: str
    predicted_class: int
    predicted_emotion: str
    confidence: float
    is_stressed: bool
    features: Optional[Dict] = None
    probabilities: Optional[Dict] = None
    stress_probability: Optional[float] = None

class HealthStatus(BaseModel):
    status: str
    models_loaded: bool
    available_models: List[str]

def estimate_sdnn_from_hr(heart_rate: float) -> float:
    if heart_rate <= 0:
        return 50.0
    mean_rr = 60000.0 / heart_rate
    sdnn = 0.05 * mean_rr
    return max(10.0, min(200.0, sdnn))

def calculate_rmssd_from_sdnn(sdnn: float) -> float:
    rmssd = 0.8 * sdnn
    return max(5.0, min(150.0, rmssd))

def calculate_pnn50_from_rmssd(rmssd: float) -> float:
    from scipy.special import erfc
    if rmssd <= 0:
        return 0.0
    pnn50 = 100.0 * erfc(50.0 / (rmssd * np.sqrt(2)))
    return max(0.0, min(100.0, pnn50))

def predict_from_hr_simple(heart_rate: float, sdnn: float = None, rmssd: float = None, pnn50: float = None, model_type: str = "binary"):
    if sdnn is None:
        sdnn = estimate_sdnn_from_hr(heart_rate)
    
    if rmssd is None:
        rmssd = calculate_rmssd_from_sdnn(sdnn)
    
    if pnn50 is None:
        pnn50 = calculate_pnn50_from_rmssd(rmssd)
    
    if predictor_simple is not None:
        if model_type == "binary":
            return predictor_simple.predict_simple_binary(heart_rate, sdnn, rmssd, pnn50)
        else:
            return predictor_simple.predict_simple_4class(heart_rate, sdnn, rmssd, pnn50)
    
    return {'error': 'Simple predictor not loaded'}

@app.post("/predict", response_model=LegacyEmotionResponse)
async def predict_legacy(data: HeartRateRequest):
    logger.info(f"[Legacy] Получен запрос: heart_rate={data.heart_rate}")
    
    if data.heart_rate <= 0 or data.heart_rate > 250:
        logger.error(f"Некорректный heart_rate: {data.heart_rate}")
        raise HTTPException(status_code=400, detail="Invalid heart rate value")
    
    if predictor_simple is None:
        logger.error("Упрощённые модели не загружены")
        raise HTTPException(status_code=503, detail="Simple models not loaded")
    
    sdnn = estimate_sdnn_from_hr(data.heart_rate)
    rmssd = calculate_rmssd_from_sdnn(sdnn)
    pnn50 = calculate_pnn50_from_rmssd(rmssd)
    
    logger.info(f"[Legacy] Рассчитанные параметры: SDNN={sdnn:.2f}, RMSSD={rmssd:.2f}, PNN50={pnn50:.2f}")
    
    try:
        result = predictor_simple.predict_simple_4class(data.heart_rate, sdnn, rmssd, pnn50)
        
        if 'error' in result:
            logger.error(f"Ошибка предсказания: {result['error']}")
            raise HTTPException(status_code=400, detail=result['error'])
        
        predicted_class = result['predicted_class']
        emotion_id = predicted_class + 1
        emotion_name = result['predicted_emotion']
        
        probabilities = result.get('probabilities', {})
        if not probabilities:
            probabilities = {emotion_name: result['confidence']}
        
        logger.info(f"[Legacy] Предсказание: {emotion_name} (ID: {emotion_id}, confidence={result['confidence']:.2f})")
        
        return LegacyEmotionResponse(
            predicted_emotion_id=emotion_id,
            predicted_emotion=emotion_name,
            confidence=result['confidence'],
            probabilities=probabilities
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Неожиданная ошибка: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict/simple", response_model=LegacyEmotionResponse)
async def predict_simple(data: SimpleHRVRequest):
    logger.info(f"[Simple] Получен запрос: heart_rate={data.heart_rate}, sdnn={data.sdnn}, rmssd={data.rmssd}, pnn50={data.pnn50}, model_type={data.model_type}")
    
    if data.heart_rate <= 0 or data.heart_rate > 250:
        logger.error(f"Некорректный heart_rate: {data.heart_rate}")
        raise HTTPException(status_code=400, detail="Invalid heart rate value")
    
    if predictor_simple is None:
        logger.error("Упрощённые модели не загружены")
        raise HTTPException(status_code=503, detail="Simple models not loaded")
    
    sdnn = data.sdnn if data.sdnn is not None else estimate_sdnn_from_hr(data.heart_rate)
    rmssd = data.rmssd if data.rmssd is not None else calculate_rmssd_from_sdnn(sdnn)
    pnn50 = data.pnn50 if data.pnn50 is not None else calculate_pnn50_from_rmssd(rmssd)
    
    logger.info(f"[Simple] Используемые параметры: HR={data.heart_rate:.2f}, SDNN={sdnn:.2f}, RMSSD={rmssd:.2f}, PNN50={pnn50:.2f}")
    
    try:
        if data.model_type == "binary":
            result = predictor_simple.predict_simple_binary(data.heart_rate, sdnn, rmssd, pnn50)
            if 'error' in result:
                raise HTTPException(status_code=400, detail=result['error'])
            
            emotion_id = 2 if result['is_stressed'] else 1
            emotion_name = result['predicted_emotion']
        else:
            result = predictor_simple.predict_simple_4class(data.heart_rate, sdnn, rmssd, pnn50)
            if 'error' in result:
                raise HTTPException(status_code=400, detail=result['error'])
            
            emotion_id = result['predicted_class'] + 1
            emotion_name = result['predicted_emotion']
        
        probabilities = result.get('probabilities', {})
        if not probabilities:
            probabilities = {emotion_name: result['confidence']}
        
        logger.info(f"[Simple] Предсказание: {emotion_name} (ID: {emotion_id}, confidence={result['confidence']:.2f})")
        
        return LegacyEmotionResponse(
            predicted_emotion_id=emotion_id,
            predicted_emotion=emotion_name,
            confidence=result['confidence'],
            probabilities=probabilities
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Неожиданная ошибка: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict/rr", response_model=EmotionPrediction)
async def predict_from_rr(data: RRIntervalsRequest):
    logger.info(f"Получен запрос: model_type={data.model_type}, rr_intervals={len(data.rr_intervals_ms)} values")
    
    if not data.rr_intervals_ms or len(data.rr_intervals_ms) < 8:
        logger.error("Недостаточно RR интервалов")
        raise HTTPException(status_code=400, detail="Minimum 8 RR intervals required")
    
    try:
        if data.model_type == "binary":
            logger.info("Используется Binary модель (XGBoost, F1=0.9332)")
            result = predict_stress(data.rr_intervals_ms)
        elif data.model_type == "4class":
            logger.info("Используется 4-Class модель (LightGBM, F1=0.7788)")
            result = predict_emotion_4class(data.rr_intervals_ms)
        elif data.model_type == "hierarchical":
            logger.info("Используется Hierarchical модель (Binary + 3-Class)")
            result = predict_emotion(data.rr_intervals_ms)
        else:
            raise HTTPException(status_code=400, detail=f"Invalid model_type: {data.model_type}")
        
        if 'error' in result:
            logger.error(f"Ошибка предсказания: {result['error']}")
            raise HTTPException(status_code=400, detail=result['error'])
        
        logger.info(f"Предсказание: {result['predicted_emotion']} (confidence={result['confidence']:.2f})")
        return EmotionPrediction(**result)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Неожиданная ошибка: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/predict/hrv", response_model=EmotionPrediction)
async def predict_from_hrv(data: HRVMetricsRequest):
    logger.info(f"Получен HRV запрос: heart_rate={data.heart_rate}, sdnn={data.sdnn}, rmssd={data.rmssd}, pnn50={data.pnn50}")
    
    if data.heart_rate <= 0 or data.heart_rate > 250:
        logger.error(f"Некорректный heart_rate: {data.heart_rate}")
        raise HTTPException(status_code=400, detail="Invalid heart rate value")
    
    if predictor_simple is None:
        logger.error("Упрощённые модели не загружены")
        raise HTTPException(status_code=503, detail="Simple models not loaded")
    
    sdnn = data.sdnn if data.sdnn is not None else estimate_sdnn_from_hr(data.heart_rate)
    rmssd = data.rmssd if data.rmssd is not None else calculate_rmssd_from_sdnn(sdnn)
    pnn50 = data.pnn50 if data.pnn50 is not None else calculate_pnn50_from_rmssd(rmssd)
    
    logger.info(f"[HRV] Используемые параметры: HR={data.heart_rate:.2f}, SDNN={sdnn:.2f}, RMSSD={rmssd:.2f}, PNN50={pnn50:.2f}")
    
    try:
        if data.model_type == "binary":
            result = predictor_simple.predict_simple_binary(data.heart_rate, sdnn, rmssd, pnn50)
        else:
            result = predictor_simple.predict_simple_4class(data.heart_rate, sdnn, rmssd, pnn50)
        
        if 'error' in result:
            logger.error(f"Ошибка предсказания: {result['error']}")
            raise HTTPException(status_code=400, detail=result['error'])
        
        logger.info(f"Предсказание (simple): {result['predicted_emotion']} (confidence={result['confidence']:.2f})")
        return EmotionPrediction(**result)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Неожиданная ошибка: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health", response_model=HealthStatus)
async def health():
    model_dir = Path(__file__).parent / "model"
    models_exist = all((model_dir / f).exists() for f in ['model_4class.pkl', 'model_binary.pkl', 'scaler.pkl'])
    
    return HealthStatus(
        status="ok",
        models_loaded=models_exist,
        available_models=["binary", "4class", "hierarchical"]
    )

@app.get("/models/info")
async def models_info():
    return {
        "models": [
            {
                "name": "Binary Stress Detection",
                "type": "binary",
                "algorithm": "XGBoost",
                "f1_score": 0.9332,
                "accuracy": 0.9332,
                "classes": ["Non-Stress", "Stress"]
            },
            {
                "name": "4-Class Emotion Classification",
                "type": "4class",
                "algorithm": "LightGBM",
                "f1_score": 0.7788,
                "accuracy": 0.7828,
                "classes": ["Baseline", "Stress", "Amusement", "Meditation"]
            }
        ],
        "endpoints": {
            "/predict": "Legacy endpoint (heart_rate only)",
            "/predict/rr": "Full RR intervals (best accuracy)",
            "/predict/hrv": "HRV metrics (heart_rate + sdnn + rmssd + pnn50)"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")
