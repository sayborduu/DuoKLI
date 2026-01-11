from pathlib import Path

__version__ = "1.4.0"

GITHUB_USER = "sayborduu"
GITHUB_REPO = "DuoKLI"

GITHUB_API = f"https://api.github.com/repos/{GITHUB_USER}/{GITHUB_REPO}/releases/latest"

UPDATE_DIR = Path.cwd() / ".duokli_update"