# dataquestapp/ml_service.py
import os
import json
import threading
import traceback
from pathlib import Path
from typing import Any, Dict, List

# Optional: set an env var EMBEDDER_MODEL_DIR to override the path
PROJECT_DIR = Path(__file__).resolve().parent.parent
MODELS_PATH = os.environ.get("MODELS_PATH", str(PROJECT_DIR /"dataquestapp"/ "models"))
# your actual nested folder
EMBEDDER_DIR = os.environ.get(
    "EMBEDDER_MODEL_DIR",
    str(Path(MODELS_PATH) / "embedder_model")
)

# Globals (populated by init_models)
embedder = None
clf_multi = None
mlb = None
SUB_TO_CAT = {}

# thread-safety
_load_lock = threading.Lock()
_loaded = False
_load_error_msg = None  # store last load error for easier debugging


def _list_top_dir(p: str, max_entries: int = 50) -> List[str]:
    try:
        pth = Path(p)
        if not pth.exists():
            return [f"(missing) {p}"]
        entries = []
        for i, child in enumerate(pth.iterdir()):
            if i >= max_entries:
                entries.append("... (truncated)")
                break
            entries.append(child.name)
        return entries
    except Exception as e:
        return [f"error listing dir: {e}"]


def init_models() -> None:
    """Load the embedder, classifier and mapping. Raises RuntimeError on failure."""
    global embedder, clf_multi, mlb, SUB_TO_CAT, _loaded, _load_error_msg

    if _loaded:
        return

    with _load_lock:
        if _loaded:
            return
        try:
            from sentence_transformers import SentenceTransformer
            import joblib
        except Exception as e:
            _load_error_msg = f"Failed to import heavy libs: {e}\n{traceback.format_exc()}"
            raise RuntimeError(_load_error_msg)

        # check embedder path
        embedder_path = Path(EMBEDDER_DIR)
        if not embedder_path.exists():
            _load_error_msg = (
                f"Embedder folder not found: {EMBEDDER_DIR}\n"
                f"MODELS_PATH={MODELS_PATH}\n"
                f"Top-level of MODELS_PATH: {_list_top_dir(MODELS_PATH)}"
            )
            raise RuntimeError(_load_error_msg)

        # instantiate embedder
        try:
            embedder = SentenceTransformer(str(embedder_path), local_files_only=True)
        except Exception as e:
            _load_error_msg = f"Failed to load SentenceTransformer: {e}\n{traceback.format_exc()}\nListing: {_list_top_dir(EMBEDDER_DIR)}"
            raise RuntimeError(_load_error_msg)

        # classifier and multilabel binarizer files (adjust names if different)
        clf_path = Path(MODELS_PATH) / "emb_clf_multilabel.pkl"
        mlb_path = Path(MODELS_PATH) / "mlb.pkl"
        sub_map_path = Path(MODELS_PATH) / "sub_to_cat.json"

        if not clf_path.exists() or not mlb_path.exists() or not sub_map_path.exists():
            missing = []
            if not clf_path.exists(): missing.append(str(clf_path))
            if not mlb_path.exists(): missing.append(str(mlb_path))
            if not sub_map_path.exists(): missing.append(str(sub_map_path))
            _load_error_msg = f"Required files missing in MODELS_PATH: {missing}\nTop-level: {_list_top_dir(MODELS_PATH)}"
            raise RuntimeError(_load_error_msg)

        try:
            clf_multi = joblib.load(str(clf_path))
            mlb = joblib.load(str(mlb_path))
        except Exception as e:
            _load_error_msg = f"Failed to load joblib files: {e}\n{traceback.format_exc()}"
            raise RuntimeError(_load_error_msg)

        try:
            with open(sub_map_path, "r", encoding="utf-8") as fh:
                SUB_TO_CAT = json.load(fh)
        except Exception as e:
            _load_error_msg = f"Failed to read sub_to_cat.json: {e}\n{traceback.format_exc()}"
            raise RuntimeError(_load_error_msg)

        _loaded = True
        _load_error_msg = None


def predict_text(text: str, reports_same_place: int = 0) -> Dict[str, Any]:
    """
    Ensure models are loaded (lazy), then run your pipeline.
    Returns a dict. If loading failed, returns a dict with key "error".
    """
    global _loaded, _load_error_msg

    # lazy init
    if not _loaded:
        try:
            init_models()
        except Exception as e:
            return {"error": f"Model initialization failed: {e}"}

    # final guard
    if embedder is None or clf_multi is None or mlb is None:
        return {"error": f"Models not loaded. Last init error: {_load_error_msg}"}

    if not text:
        return {"error": "empty text"}

    try:
        emb = embedder.encode([text], convert_to_numpy=True)
        probs = clf_multi.predict_proba(emb)[0]
        # pick top 3
        import numpy as _np
        top_idx = _np.argsort(probs)[::-1][:3]
        chosen = [(mlb.classes_[i], float(probs[i])) for i in top_idx]

        subs = [c[0] for c in chosen]
        confs = [c[1] for c in chosen]
        cats = [SUB_TO_CAT.get(s, "other") for s in subs]

        sev = "medium"
        if "dangerous" in text.lower():
            sev = "high"

        return {
            "subcategory": subs,
            "subcategory_conf": confs,
            "category": cats,
            "severity": sev,
            "priority": min(100, int(confs[0]*100) + reports_same_place*5),
        }
    except Exception as e:
        return {"error": f"Prediction failed: {e}\n{traceback.format_exc()}"}
