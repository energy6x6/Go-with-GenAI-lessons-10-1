"""Runtime paths shared by local lab utilities."""
import os
from pathlib import Path


def artifacts_dir():
    root = Path(__file__).resolve().parent.parent
    return Path(os.environ.get("PROJECTGO_ARTIFACTS_DIR", str(root.parent / "projectgo-artifacts"))).resolve()
