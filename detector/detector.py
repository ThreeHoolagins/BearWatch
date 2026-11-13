"""Bear detection with a COCO-trained YOLOX model (Apache-2.0) on onnxruntime.

COCO already has a "bear" class, so no custom training is needed. A photo
counts as a bear when the bear score clears the threshold AND beats every
other animal, so a very bear-like dog that scores "86% dog, 85% bear" fails.

The same pass also scores people (no extra compute). The Terms of Service ban
people in photos, so person_detected flags anything at or above
person_threshold.
"""
import io
import time
from dataclasses import dataclass

import numpy as np
import onnxruntime as ort
from PIL import Image

COCO = ["person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light",
        "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
        "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
        "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard",
        "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
        "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
        "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote", "keyboard",
        "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase",
        "scissors", "teddy bear", "hair drier", "toothbrush"]

BEAR = COCO.index("bear")
PERSON = COCO.index("person")
# Things a bear photo could be confused with. The bear must outscore all of them.
LOOKALIKES = [COCO.index(name) for name in
              ("bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "zebra", "giraffe", "teddy bear")]


@dataclass
class Result:
    is_bear: bool
    bear_score: float
    person_detected: bool
    person_score: float
    runner_up: str
    runner_up_score: float
    ms: int
    # Best bear box as (centre x, centre y, width, height), 0-1 of the photo.
    bear_box: tuple | None = None

    def as_dict(self):
        return {
            "is_bear": self.is_bear,
            "bear_score": round(self.bear_score, 4),
            "person_detected": self.person_detected,
            "person_score": round(self.person_score, 4),
            "runner_up": self.runner_up,
            "runner_up_score": round(self.runner_up_score, 4),
            "ms": self.ms,
            "bear_box": [round(v, 4) for v in self.bear_box] if self.bear_box else None,
        }


class BearDetector:
    def __init__(self, model_path: str, threshold: float, person_threshold: float = 0.20):
        options = ort.SessionOptions()
        # Keep CPU use modest so a Raspberry Pi stays responsive.
        options.intra_op_num_threads = 2
        self.session = ort.InferenceSession(model_path, options, providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name
        self.size = self.session.get_inputs()[0].shape[2]
        self.threshold = threshold
        self.person_threshold = person_threshold
        self.grids, self.strides = self._grids(self.size)

    def detect(self, image_bytes: bytes) -> Result:
        started = time.perf_counter()
        tensor, content_size = self._preprocess(image_bytes)
        raw = self.session.run(None, {self.input_name: tensor})[0][0]
        scores = self._class_scores(raw)

        bear = float(scores[BEAR])
        person = float(scores[PERSON])
        runner_up = max(LOOKALIKES, key=lambda i: scores[i])
        runner_up_score = float(scores[runner_up])
        return Result(
            is_bear=bear >= self.threshold and bear > runner_up_score,
            bear_score=bear,
            person_detected=person >= self.person_threshold,
            person_score=person,
            runner_up=COCO[runner_up],
            runner_up_score=runner_up_score,
            ms=round((time.perf_counter() - started) * 1000),
            bear_box=self._best_box(raw, BEAR, content_size),
        )

    def _preprocess(self, image_bytes: bytes):
        """Letterboxed tensor, plus the (width, height) the photo fills inside it."""
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        ratio = min(self.size / image.width, self.size / image.height)
        resized = image.resize((max(1, int(image.width * ratio)), max(1, int(image.height * ratio))), Image.BILINEAR)
        canvas = np.full((self.size, self.size, 3), 114, dtype=np.uint8)
        canvas[: resized.height, : resized.width] = np.asarray(resized)
        bgr = canvas[:, :, ::-1]  # YOLOX was trained on OpenCV (BGR) images
        tensor = np.ascontiguousarray(bgr.transpose(2, 0, 1)[None].astype(np.float32))
        return tensor, (resized.width, resized.height)

    def _best_box(self, raw: np.ndarray, cls: int, content_size):
        """Highest-scoring box for a class, as fractions of the photo."""
        i = int(np.argmax(raw[:, 4] * raw[:, 5 + cls]))
        stride = float(self.strides[i, 0])
        cx = (raw[i, 0] + self.grids[i, 0]) * stride
        cy = (raw[i, 1] + self.grids[i, 1]) * stride
        w = float(np.exp(raw[i, 2])) * stride
        h = float(np.exp(raw[i, 3])) * stride
        width, height = content_size
        clamp = lambda v: float(min(1.0, max(0.0, v)))  # noqa: E731
        return (clamp(cx / width), clamp(cy / height), clamp(w / width), clamp(h / height))

    def _class_scores(self, raw: np.ndarray) -> np.ndarray:
        """Best score per class across all candidate boxes (objectness x class probability)."""
        return (raw[:, 4:5] * raw[:, 5:]).max(axis=0)

    @staticmethod
    def _grids(size: int):
        grids, strides = [], []
        for stride in (8, 16, 32):
            n = size // stride
            ys, xs = np.meshgrid(np.arange(n), np.arange(n), indexing="ij")
            grids.append(np.stack((xs, ys), 2).reshape(-1, 2))
            strides.append(np.full((n * n, 1), stride))
        return np.concatenate(grids), np.concatenate(strides)
