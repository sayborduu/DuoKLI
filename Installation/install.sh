#!/usr/bin/env bash
set -euo pipefail

GITHUB_REPO=""
DEFAULT_PREFIX="/usr/local/lib/duokli"
DOWNLOAD_DIR=""
BIN_DIR="/usr/local/bin"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--prefix DIR] [--tag TAG] [--uninstall]

Installs the latest DuoKLI release from GitHub.

Options:
  --prefix DIR    Installation prefix (default: ${DEFAULT_PREFIX})
  --github-repo REPO    GitHub repo in owner/repo format (required)
  --download-dir DIR    Directory to download/extract release (default: current directory)
  --tag TAG       Install a specific release tag instead of latest
  --uninstall     Remove the installed symlink and wrapper
  -h, --help      Show this help

Examples:
  sudo bash install.sh
  sudo bash install.sh --prefix /opt/duokli --tag v1.3.0
  sudo bash install.sh --uninstall
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found"
}

check_cmd curl
check_cmd tar
check_cmd python3

PREFIX="${DEFAULT_PREFIX}"
TAG=""
UNINSTALL=0

if [[ -z "${GITHUB_REPO}" ]]; then
  :
fi

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="$2"; shift 2;;
    --github-repo)
      GITHUB_REPO="$2"; shift 2;;
    --download-dir)
      DOWNLOAD_DIR="$2"; shift 2;;
    --tag)
      TAG="$2"; shift 2;;
    --uninstall)
      UNINSTALL=1; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

BIN_PATH="${BIN_DIR}/duokli"

if [[ ${UNINSTALL} -eq 1 ]]; then
  info "Uninstalling DuoKLI"
  if [[ -L "${PREFIX}" ]]; then
    REALPATH=$(readlink "${PREFIX}")
    info "Removing symlink ${PREFIX} -> ${REALPATH}"
    sudo rm -f "${PREFIX}"
  fi
  if [[ -f "${BIN_PATH}" ]]; then
    info "Removing wrapper ${BIN_PATH}"
    sudo rm -f "${BIN_PATH}"
  fi
  echo "Uninstall complete. (Note: release directories under ${PREFIX}-<tag> are not removed automatically)"
  exit 0
fi

info "Fetching latest release info for ${GITHUB_REPO}"
if [[ -z "${GITHUB_REPO}" ]]; then
  die "--github-repo is required (format: owner/repo)"
fi

API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

info "Fetching latest release info for ${GITHUB_REPO}"
if [[ -z "${TAG}" ]]; then
  RAW=$(curl -fsL "${API_URL}") || die "failed fetching release info"
  TAG=$(printf '%s' "$RAW" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": "([^"]*)".*/\1/')
  if [[ -z "${TAG}" ]]; then
    die "could not determine latest tag"
  fi
  info "Latest tag: ${TAG}"
else
  info "Using requested tag: ${TAG}"
fi

TARBALL_URL="https://github.com/${GITHUB_REPO}/archive/refs/tags/${TAG}.tar.gz"
if [[ -n "${DOWNLOAD_DIR}" ]]; then
  mkdir -p "${DOWNLOAD_DIR}"
  TMPDIR="${DOWNLOAD_DIR%/}"
  IS_TEMP=0
else
  TMPDIR="$(pwd)"
  IS_TEMP=0
fi
ARCHIVE="${TMPDIR}/repo-${TAG}.tar.gz"

info "Downloading ${TARBALL_URL}"
curl -L --fail -o "${ARCHIVE}" "${TARBALL_URL}" || die "download failed"

info "Extracting archive into ${TMPDIR}"
tar -xzf "${ARCHIVE}" -C "${TMPDIR}" || die "extract failed"

EXTRACTED_DIR=$(find "${TMPDIR}" -mindepth 1 -maxdepth 1 -type d | head -n1)
[[ -d "${EXTRACTED_DIR}" ]] || die "extracted directory not found"

TARGET_DIR="${PREFIX}-${TAG}"

info "Installing to ${TARGET_DIR}"
if [[ -e "${TARGET_DIR}" ]]; then
  info "Removing existing ${TARGET_DIR}"
  sudo rm -rf "${TARGET_DIR}"
fi

sudo mkdir -p "$(dirname "${TARGET_DIR}")"
sudo mv "${EXTRACTED_DIR}" "${TARGET_DIR}" || die "failed to move files into ${TARGET_DIR}"

info "Creating/refreshing symlink ${PREFIX} -> ${TARGET_DIR}"
sudo ln -sfn "${TARGET_DIR}" "${PREFIX}"

info "Setting up Python virtual environment"
sudo "${TARGET_DIR}"/bin/true 2>/dev/null || true
sudo chown -R "$(whoami)" "${TARGET_DIR}"
python3 -m venv "${TARGET_DIR}/venv" || die "venv creation failed"
"${TARGET_DIR}/venv/bin/pip" install -U pip setuptools wheel >/dev/null

if [[ -f "${TARGET_DIR}/requirements.txt" ]]; then
  info "Installing Python deps from requirements.txt"
  "${TARGET_DIR}/venv/bin/pip" install -r "${TARGET_DIR}/requirements.txt"
else
  info "No requirements.txt found — skipping pip install"
fi

info "Creating wrapper at ${BIN_PATH}"
WRAPPER_CONTENT=$(cat <<EOF
#!/usr/bin/env bash
exec "${TARGET_DIR}/venv/bin/python" "${PREFIX}/DuoKLI.py" "\$@"
EOF
)
echo "${WRAPPER_CONTENT}" | sudo tee "${BIN_PATH}" >/dev/null
sudo chmod +x "${BIN_PATH}"

info "Installation complete. You can run DuoKLI with: ${BIN_PATH}"
echo "If you want to install for all users, run this script with sudo."

if [[ ${IS_TEMP} -eq 1 ]]; then
  rm -rf "${TMPDIR}"
else
  info "Downloaded/extracted files kept at ${TMPDIR} (user-specified)"
fi
exit 0
