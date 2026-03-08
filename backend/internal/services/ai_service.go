package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
)

type AIRequest struct {
	HeartRate float64  `json:"heart_rate"`
	SDNN      *float64 `json:"sdnn,omitempty"`
	RMSSD     *float64 `json:"rmssd,omitempty"`
	PNN50     *float64 `json:"pnn50,omitempty"`
	ModelType string   `json:"model_type,omitempty"`
}

type AIResponse struct {
	PredictedEmotionID int                `json:"predicted_emotion_id"`
	PredictedEmotion   string             `json:"predicted_emotion"`
	Confidence         float64            `json:"confidence"`
	Probabilities      map[string]float64 `json:"probabilities"`
}

type AIService struct {
	baseURL string
	client  *http.Client
}

func NewAIService(baseURL string) *AIService {
	return &AIService{
		baseURL: baseURL,
		client:  &http.Client{},
	}
}

func estimateSDNN(heartRate float64) float64 {
	if heartRate <= 0 {
		return 50.0
	}
	meanRR := 60000.0 / heartRate
	sdnn := 0.05 * meanRR
	if sdnn < 10.0 {
		return 10.0
	}
	if sdnn > 200.0 {
		return 200.0
	}
	return sdnn
}

func calculateRMSSD(sdnn float64) float64 {
	rmssd := 0.8 * sdnn
	if rmssd < 5.0 {
		return 5.0
	}
	if rmssd > 150.0 {
		return 150.0
	}
	return rmssd
}

func calculatePNN50(rmssd float64) float64 {
	if rmssd <= 0 {
		return 0.0
	}
	pnn50 := 100.0 * math.Erfc(50.0/(rmssd*math.Sqrt2))
	if pnn50 < 0.0 {
		return 0.0
	}
	if pnn50 > 100.0 {
		return 100.0
	}
	return pnn50
}

func (s *AIService) PredictEmotion(req AIRequest) (*AIResponse, error) {
	fmt.Printf("[AI Service] PredictEmotion called with HeartRate=%.2f, SDNN=%v, RMSSD=%v, PNN50=%v, ModelType=%s\n",
		req.HeartRate, req.SDNN, req.RMSSD, req.PNN50, req.ModelType)
	
	sdnn := req.SDNN
	if sdnn == nil {
		estimated := estimateSDNN(req.HeartRate)
		sdnn = &estimated
		fmt.Printf("[AI Service] Estimated SDNN from HeartRate %.2f: %.2f\n", req.HeartRate, *sdnn)
	}
	
	rmssd := req.RMSSD
	if rmssd == nil {
		calculated := calculateRMSSD(*sdnn)
		rmssd = &calculated
		fmt.Printf("[AI Service] Calculated RMSSD from SDNN %.2f: %.2f\n", *sdnn, *rmssd)
	}
	
	pnn50 := req.PNN50
	if pnn50 == nil {
		calculated := calculatePNN50(*rmssd)
		pnn50 = &calculated
		fmt.Printf("[AI Service] Calculated PNN50 from RMSSD %.2f: %.2f\n", *rmssd, *pnn50)
	}
	
	url := fmt.Sprintf("%s/predict/simple", s.baseURL)
	requestBody := map[string]interface{}{
		"heart_rate": req.HeartRate,
		"sdnn":       *sdnn,
		"rmssd":      *rmssd,
		"pnn50":      *pnn50,
	}
	if req.ModelType != "" {
		requestBody["model_type"] = req.ModelType
	} else {
		requestBody["model_type"] = "4class"
	}
	fmt.Printf("[AI Service] Calling simple model at %s with HR=%.2f, SDNN=%.2f, RMSSD=%.2f, PNN50=%.2f\n",
		url, req.HeartRate, *sdnn, *rmssd, *pnn50)
	fmt.Printf("[AI Service] Request body: %+v\n", requestBody)

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		fmt.Printf("[AI Service] Failed to marshal request: %v\n", err)
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	httpReq, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		fmt.Printf("[AI Service] Failed to create request: %v\n", err)
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(httpReq)
	if err != nil {
		fmt.Printf("[AI Service] Failed to send request to %s: %v\n", url, err)
		return nil, fmt.Errorf("failed to send request to AI service at %s: %w (make sure AI service is running)", url, err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("[AI Service] Failed to read response: %v\n", err)
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	fmt.Printf("[AI Service] Response status: %d, body: %s\n", resp.StatusCode, string(body))

	if resp.StatusCode != http.StatusOK {
		fmt.Printf("[AI Service] Error response (status %d): %s\n", resp.StatusCode, string(body))
		return nil, fmt.Errorf("AI service error (status %d): %s", resp.StatusCode, string(body))
	}

	var aiResp AIResponse
	if err := json.Unmarshal(body, &aiResp); err != nil {
		fmt.Printf("[AI Service] Failed to unmarshal response body '%s': %v\n", string(body), err)
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	fmt.Printf("[AI Service] Successfully parsed response: emotion=%d, label=%s, confidence=%.2f\n",
		aiResp.PredictedEmotionID, aiResp.PredictedEmotion, aiResp.Confidence)

	return &aiResp, nil
}
