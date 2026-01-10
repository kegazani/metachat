# Инструкции по обновлению модели для работы только с пульсом

## Изменения, которые нужно внести в notebook:

### 1. После функции `extract_hrv_features` добавить новую функцию:

```python
def extract_heart_rate_only(ecg_segment, fs=700):
    """
    Извлекает только пульс (Mean_HR) из куска ECG
    """
    if len(ecg_segment) < int(fs * 5):
        return None
    
    sos = butter(2, [5, 15], btype='band', fs=fs, output='sos')
    ecg_band = sosfiltfilt(sos, ecg_segment)
    ecg_squared = ecg_band ** 2
    window_size = int(0.15 * fs)
    ecg_integrated = np.convolve(ecg_squared, 
                                 np.ones(window_size)/window_size, 
                                 mode='same')
    threshold = np.mean(ecg_integrated) + 0.5 * np.std(ecg_integrated)
    r_peaks, _ = find_peaks(ecg_integrated, 
                            height=threshold, 
                            distance=int(0.4 * fs))
    
    if len(r_peaks) < 4:
        return None
    
    rr_samples = np.diff(r_peaks)
    rr_ms = (rr_samples / fs) * 1000
    mean_hr = 60000 / np.mean(rr_ms)
    
    return mean_hr
```

### 2. В функции `load_subject_all_emotions` изменить строки:

**Было:**
```python
        # Извлечь HRV
        hrv = extract_hrv_features(ecg_window, fs)
        
        if hrv is None:
            continue
        
        # Сохранить
        X.append(hrv)
```

**Стало:**
```python
        # Извлечь только пульс
        heart_rate = extract_heart_rate_only(ecg_window, fs)
        
        if heart_rate is None:
            continue
        
        # Сохранить только пульс
        X.append([heart_rate])
```

### 3. В ячейке с нормализацией изменить:

**Было:**
```python
feature_names = ['SDNN', 'RMSSD', 'pNN50', 'Mean_HR']
```

**Стало:**
```python
feature_names = ['Mean_HR']
```

И добавить после нормализации:
```python
print(f"\n📊 Статистика пульса по эмоциям:")
for emotion_id in [1, 2, 3, 4]:
    mask = y_all == emotion_id
    if np.sum(mask) > 0:
        hr_values = X_all[mask, 0]
        print(f"{EMOTION_NAMES[emotion_id]:40s} Mean: {hr_values.mean():.1f} bpm, Std: {hr_values.std():.1f} bpm")
```

Все визуализации уже добавлены в новые ячейки.
