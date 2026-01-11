import hashlib
from pathlib import Path
import json

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

release_folder = Path(".")

manifest = {}
for f in release_folder.iterdir():
    if f.is_file() and f.suffix == ".py":
        manifest[f.name] = sha256_file(f)

with open("hashes.json", "w") as out:
    json.dump(manifest, out, indent=2)

print("hash manifest created at hashes.json")
