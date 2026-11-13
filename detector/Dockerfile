# Bear detector: YOLOX-S (Apache-2.0, COCO-trained) on onnxruntime.
# Runs on a network with no internet access, so the model is baked in at
# build time and checked against a known hash. Builds for amd64 and arm64.
FROM python:3.12-slim

ARG MODEL_URL=https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_s.onnx
ARG MODEL_SHA256=c5c2d13e59ae883e6af3b45daea64af4833a4951c92d116ec270d9ddbe998063

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir --root-user-action=ignore -r requirements.txt

ADD --checksum=sha256:${MODEL_SHA256} ${MODEL_URL} /models/yolox_s.onnx

COPY detector.py server.py ./
COPY tests/ ./tests/
RUN useradd --create-home detector && chmod 444 /models/yolox_s.onnx
USER detector

ENV MODEL_PATH=/models/yolox_s.onnx PYTHONUNBUFFERED=1
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=5s --retries=6 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=4)"
CMD ["python", "server.py"]
