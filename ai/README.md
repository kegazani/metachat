# Модель предсказания эмоций по пульсу

## Обновление модели для работы только с пульсом

Модель адаптирована для работы только с данными пульса (Heart Rate), так как это единственные данные, доступные из Apple Watch.

## Структура

- `model.ipynb` - Jupyter notebook для обучения модели
- `predict.py` - Скрипт для предсказания эмоций
- `backend.py` - FastAPI сервис для предсказания
- `model/` - Директория с обученными моделями и скейлером

## Изменения в коде

### 1. Обучение модели (model.ipynb)

1. Добавлена функция `extract_heart_rate_only()` - извлекает только пульс
2. Функция `load_subject_all_emotions()` обновлена для использования только пульса
3. Добавлены визуализации:
   - Распределение пульса по эмоциям
   - Confusion matrices для каждой модели
   - Сравнение точности моделей
   - Зависимость предсказания от пульса
   - Тестирование на реальных данных

### 2. Предсказание (predict.py)

- Метод `predict()` теперь принимает только `mean_hr` (пульс)
- Функция `predict_from_apple_watch()` упрощена - требуется только `heart_rate`

### 3. API (backend.py)

- Эндпоинт `/predict` принимает только `heart_rate`

## Использование

### Обучение модели

1. Запустите все ячейки в `model.ipynb`
2. Модели сохранятся в `model/model_{1,2,3,4}.pkl`
3. Скейлер сохранится в `model/scaler.pkl`
4. Графики сохранятся в `model/`:
   - `heart_rate_distribution.png` - распределение пульса
   - `confusion_matrices.png` - матрицы ошибок
   - `accuracy_comparison.png` - сравнение точности
   - `heart_rate_predictions.png` - зависимость от пульса

### Предсказание через CLI

```bash
python predict.py 72.0
```

### Предсказание через API

```bash
# Запустить сервис
python backend.py

# Выполнить запрос
curl -X POST "http://localhost:8000/predict" \
  -H "Content-Type: application/json" \
  -d '{"heart_rate": 72.0}'
```

## Интерпретация результатов

Модель возвращает:
- `predicted_emotion_id`: ID эмоции (1-4)
- `predicted_emotion`: Название эмоции
- `confidence`: Уверенность в предсказании (0-1)
- `probabilities`: Вероятности для всех 4 эмоций

### Эмоции:
- 1: Baseline (спокойствие)
- 2: Stress (стресс)
- 3: Amusement (веселье)
- 4: Meditation (медитация)
