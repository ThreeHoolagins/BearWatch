# Bear detector: YOLO weights from earthtoolsmaker/bear-conservation exported
# to ONNX, served by a tiny HTTP app. onnxruntime instead of full PyTorch keeps
# the image and RAM small enough for a Raspberry Pi 4 (arm64).
# Requires detector/ app + model (Phase 2).
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN useradd --create-home detector
USER detector
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
