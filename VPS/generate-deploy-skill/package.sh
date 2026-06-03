#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="${ROOT}/vps-generate-deploy"
DIST_DIR="${ROOT}/dist"
ZIP_NAME="vps-generate-deploy.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"

if [[ ! -f "${SKILL_DIR}/SKILL.md" ]]; then
    echo "error: ${SKILL_DIR}/SKILL.md not found" >&2
    exit 1
fi

mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}"

(
    cd "${ROOT}"
    zip -r "${ZIP_PATH}" vps-generate-deploy \
        -x "*.DS_Store" \
        -x "*__pycache__*"
)

echo "created ${ZIP_PATH}"
unzip -l "${ZIP_PATH}"
