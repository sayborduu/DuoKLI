from pathlib import Path

__version__ = "v1.4.3-demo"

GITHUB_USER = "sayborduu"
GITHUB_REPO = "DuoKLI"

GITHUB_API = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}/releases/latest"

UPDATE_DIR = Path.cwd() / ".duokli_update"