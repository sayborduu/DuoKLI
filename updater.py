import sys, requests, zipfile, tempfile, shutil
from pathlib import Path
import version

APP_DIR = Path.cwd()

UPDATE_DIR = version.UPDATE_DIR

def apply_update(staged_dir: Path, target_dir: Path = APP_DIR):
    if not staged_dir.exists():
        return
    print("Applying pending update...")
    for item in staged_dir.iterdir():
        dest = target_dir / item.name
        if dest.exists():
            if dest.is_dir():
                shutil.rmtree(dest)
            else:
                dest.unlink()
        shutil.move(str(item), str(dest))
    staged_dir.rmdir()
    print("Update applied!")

def parse_version(v: str):
    return tuple(map(int, v.lstrip("v").split(".")))

def is_newer(latest: str):
    return parse_version(latest) > parse_version(version.__version__)

def get_latest_release():
    r = requests.get(version.GITHUB_API, timeout=10)
    if r.status_code != 200:
        if r.status_code == 404:
            raise Exception(f"GitHub returned status code 404. Your current repo ({version.GITHUB_USER}/{version.GITHUB_REPO}) does not have any releases.")
        raise Exception(f"GitHub returned status code {r.status_code}.")
    return r.json()

def download_release(url: str):
    tmp = Path(tempfile.mkdtemp())
    zip_path = tmp / "update.zip"
    with requests.get(url, stream=True) as r:
        r.raise_for_status()
        with open(zip_path, "wb") as f:
            for chunk in r.iter_content(8192):
                f.write(chunk)

    extract_dir = tmp / "extracted"
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(extract_dir)

    return extract_dir

def stage_update(extract_dir: Path, tag: str):
    if UPDATE_DIR.exists() and not UPDATE_DIR.is_dir():
        shutil.rmtree(UPDATE_DIR)
    UPDATE_DIR.mkdir(parents=True, exist_ok=True)

    version_name = tag.lstrip("v")
    target = UPDATE_DIR / version_name

    if target.exists():
        shutil.rmtree(target)

    entries = list(extract_dir.iterdir())
    if len(entries) == 1 and entries[0].is_dir():
        src = entries[0]
        shutil.move(str(src), str(target))
        try:
            extract_dir.rmdir()
        except Exception:
            shutil.rmtree(extract_dir, ignore_errors=True)
    else:
        shutil.move(str(extract_dir), str(target))

def check_and_stage_update():
    try:
        release = get_latest_release()
        latest = release["tag_name"]

        if is_newer(latest):
            print(f"DuoKLI update available: {latest}")
            url = release["zipball_url"]
            extract_dir = download_release(url)
            stage_update(extract_dir, latest)
            print(f"Update staged at {UPDATE_DIR / latest.lstrip('v')}. It will be applied on next launch.")
            sys.exit(0)
        else:
            print("DuoKLI is up to date.")
    except Exception as e:
        print("Failed to check for updates:", e)
