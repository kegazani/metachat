from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent))
from predict import EmotionPredictor

app = FastAPI(title="Emotion Prediction API")

predictor = None

@app.on_event("startup")
async def startup_event():
    global predictor
    model_dir = Path(__file__).parent / "model"
    predictor = EmotionPredictor(model_dir=str(model_dir))

class HealthDataRequest(BaseModel):
    heart_rate: float

class EmotionPrediction(BaseModel):
    predicted_emotion_id: int
    predicted_emotion: str
    confidence: float
    probabilities: dict

@app.post("/predict", response_model=EmotionPrediction)
async def predict_emotion(data: HealthDataRequest):
    if predictor is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        result = predictor.predict(mean_hr=data.heart_rate)
        
        if 'error' in result:
            raise HTTPException(status_code=400, detail=result['error'])
        
        return EmotionPrediction(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": predictor is not None}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
