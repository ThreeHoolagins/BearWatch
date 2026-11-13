"""Run the detector over a folder of labelled photos to tune the threshold.

Put photos in two subfolders, bears/ and not_bears/, then:

  docker compose run --rm -v /path/to/photos:/photos:ro detector \
    python tests/evaluate.py /photos

Photos stay outside the repo (we don't know their licenses).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from detector import BearDetector  # noqa: E402

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")


def main():
    root = sys.argv[1]
    detector = BearDetector(os.environ.get("MODEL_PATH", "/models/yolox_s.onnx"),
                            float(os.environ.get("BEAR_CONFIDENCE_THRESHOLD", "0.85")))
    correct = total = 0
    for label in ("bears", "not_bears"):
        folder = os.path.join(root, label)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if not name.lower().endswith(IMAGE_EXTENSIONS):
                continue
            with open(os.path.join(folder, name), "rb") as f:
                result = detector.detect(f.read())
            expected = label == "bears"
            ok = result.is_bear == expected
            correct += ok
            total += 1
            print(f"{'ok  ' if ok else 'MISS'} {label}/{name}: bear {result.bear_score:.0%}, "
                  f"{result.runner_up} {result.runner_up_score:.0%}, person {result.person_score:.0%}")
    print(f"\n{correct}/{total} correct at threshold {detector.threshold:.2f}")


if __name__ == "__main__":
    main()
