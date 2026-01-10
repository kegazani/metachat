package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

type AIRequest struct {
	HeartRate float64 `json:"heart_rate"`
}

type AIResponse struct {
	PredictedEmotionID int                    `json:"predicted_emotion_id"`
	PredictedEmotion   string                 `json:"predicted_emotion"`
	Confidence         float64                `json:"confidence"`
	Probabilities      map[string]float64     `json:"probabilities"`
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

func (s *AIService) PredictEmotion(req AIRequest) (*AIResponse, error) {
	url := fmt.Sprintf("%s/predict", s.baseURL)
	
	fmt.Printf("[AI Service] Calling AI service at %s with heart rate: %.2f\n", url, req.HeartRate)

	jsonData, err := json.Marshal(req)
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
