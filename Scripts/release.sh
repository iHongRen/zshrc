#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

OWNER="${GITHUB_OWNER:-iHongRen}"
REPO="${GITHUB_REPO:-zshrc}"
REMOTE="${REMOTE:-origin}"
APP_NAME="${APP_NAME:-zshrc}"
DMG_NAME="${DMG_NAME:-zshrc.dmg}"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/dist}"
PACKAGE_SCRIPT="${PACKAGE_SCRIPT:-${SCRIPT_DIR}/package_dmg.sh}"

VERSION=""
BUILD_NUMBER=""
TAG=""
TITLE=""
NOTES=""
NOTES_FILE=""
TARGET_COMMITISH=""
DRAFT=false
PRERELEASE=false
OVERWRITE=false
SKIP_BUILD=false

usage() {
  cat <<EOF
Usage:
  scripts/release.sh --version 1.2.3 --build 45 --notes "Release notes"
  scripts/release.sh --version 1.2.3 --build 45 --notes-file RELEASE_NOTES.md

Options:
  --version VERSION       Required. App version, used for MARKETING_VERSION and default tag vVERSION.
  --build NUMBER         Required. Build number, used for CURRENT_PROJECT_VERSION.
  --tag TAG              Release tag. Defaults to vVERSION.
  --title TITLE          Release title. Defaults to zshrc VERSION.
  --notes TEXT           Release notes text.
  --notes-file PATH      Read release notes from file.
  --target COMMITISH     Target commit/branch for a new release. Defaults to current branch on GitHub.
  --repo OWNER/REPO      GitHub repo. Defaults to ${OWNER}/${REPO}.
  --draft                Create or update release as draft.
  --prerelease           Mark release as prerelease.
  --overwrite            Delete an existing uploaded DMG asset before upload.
  --skip-build           Upload existing dist/zshrc.dmg without rebuilding.
  -h, --help             Show this help.

Environment:
  GITHUB_TOKEN           Required. Token with repo release permissions.
  APP_NAME               Defaults to zshrc.
  DMG_NAME               Defaults to zshrc.dmg.
  OUTPUT_DIR             Defaults to ./dist.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

json_escape() {
  python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}

api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local url="https://api.github.com${path}"

  if [[ -n "${data}" ]]; then
    curl -fsSL \
      -X "${method}" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      --data "${data}" \
      "${url}"
  else
    curl -fsSL \
      -X "${method}" \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "${url}"
  fi
}

api_status() {
  local method="$1"
  local path="$2"
  local url="https://api.github.com${path}"
  curl -sS \
    -o /dev/null \
    -w "%{http_code}" \
    -X "${method}" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${url}"
}

release_payload() {
  local escaped_tag escaped_title escaped_notes escaped_target
  escaped_tag="$(printf '%s' "${TAG}" | json_escape)"
  escaped_title="$(printf '%s' "${TITLE}" | json_escape)"
  escaped_notes="$(printf '%s' "${NOTES}" | json_escape)"

  if [[ -n "${TARGET_COMMITISH}" ]]; then
    escaped_target="$(printf '%s' "${TARGET_COMMITISH}" | json_escape)"
    cat <<EOF
{"tag_name":${escaped_tag},"target_commitish":${escaped_target},"name":${escaped_title},"body":${escaped_notes},"draft":${DRAFT},"prerelease":${PRERELEASE}}
EOF
  else
    cat <<EOF
{"tag_name":${escaped_tag},"name":${escaped_title},"body":${escaped_notes},"draft":${DRAFT},"prerelease":${PRERELEASE}}
EOF
  fi
}

read_release_field() {
  local field="$1"
  python3 -c 'import json, sys; print(json.load(sys.stdin)[sys.argv[1]])' "${field}"
}

find_asset_id() {
  local release_id="$1"
  api GET "/repos/${OWNER}/${REPO}/releases/${release_id}/assets?per_page=100" |
    python3 -c 'import json, sys
assets = json.load(sys.stdin)
name = sys.argv[1]
for asset in assets:
    if asset.get("name") == name:
        print(asset["id"])
        break
' "${DMG_NAME}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --build)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    --tag)
      TAG="${2:-}"
      shift 2
      ;;
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --notes)
      NOTES="${2:-}"
      shift 2
      ;;
    --notes-file)
      NOTES_FILE="${2:-}"
      shift 2
      ;;
    --target)
      TARGET_COMMITISH="${2:-}"
      shift 2
      ;;
    --repo)
      IFS=/ read -r OWNER REPO <<< "${2:-}"
      shift 2
      ;;
    --draft)
      DRAFT=true
      shift
      ;;
    --prerelease)
      PRERELEASE=true
      shift
      ;;
    --overwrite)
      OVERWRITE=true
      shift
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "${VERSION}" ]] || die "--version is required"
[[ -n "${BUILD_NUMBER}" ]] || die "--build is required"
[[ -n "${GITHUB_TOKEN:-}" ]] || die "GITHUB_TOKEN is required"
[[ -n "${OWNER}" && -n "${REPO}" ]] || die "--repo must use OWNER/REPO"

TAG="${TAG:-v${VERSION}}"
TITLE="${TITLE:-${APP_NAME} ${VERSION}}"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

if [[ -n "${NOTES_FILE}" ]]; then
  [[ -f "${NOTES_FILE}" ]] || die "notes file not found: ${NOTES_FILE}"
  NOTES="$(cat "${NOTES_FILE}")"
fi

if [[ -z "${NOTES}" ]]; then
  NOTES="Release ${VERSION} (${BUILD_NUMBER})"
fi

need_command curl
need_command python3

if [[ "${SKIP_BUILD}" == false ]]; then
  VERSION="${VERSION}" \
    BUILD_NUMBER="${BUILD_NUMBER}" \
    APP_NAME="${APP_NAME}" \
    DMG_NAME="${DMG_NAME}" \
    OUTPUT_DIR="${OUTPUT_DIR}" \
    "${PACKAGE_SCRIPT}"
fi

[[ -f "${DMG_PATH}" ]] || die "DMG not found: ${DMG_PATH}"

echo "==> Publishing ${TAG} to ${OWNER}/${REPO}"
release_status="$(api_status GET "/repos/${OWNER}/${REPO}/releases/tags/${TAG}")"

if [[ "${release_status}" == "200" ]]; then
  echo "==> Updating existing release ${TAG}"
  release_json="$(api GET "/repos/${OWNER}/${REPO}/releases/tags/${TAG}")"
  release_id="$(printf '%s' "${release_json}" | read_release_field id)"
  api PATCH "/repos/${OWNER}/${REPO}/releases/${release_id}" "$(release_payload)" >/dev/null
elif [[ "${release_status}" == "404" ]]; then
  echo "==> Creating release ${TAG}"
  release_json="$(api POST "/repos/${OWNER}/${REPO}/releases" "$(release_payload)")"
  release_id="$(printf '%s' "${release_json}" | read_release_field id)"
else
  die "GitHub release lookup failed with HTTP ${release_status}"
fi

asset_id="$(find_asset_id "${release_id}")"
if [[ -n "${asset_id}" ]]; then
  if [[ "${OVERWRITE}" == true ]]; then
    echo "==> Deleting existing asset ${DMG_NAME}"
    api DELETE "/repos/${OWNER}/${REPO}/releases/assets/${asset_id}" >/dev/null
  else
    die "asset already exists: ${DMG_NAME}. Re-run with --overwrite."
  fi
fi

echo "==> Uploading ${DMG_NAME}"
curl -fsSL \
  -X POST \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"${DMG_PATH}" \
  "https://uploads.github.com/repos/${OWNER}/${REPO}/releases/${release_id}/assets?name=${DMG_NAME}" \
  >/dev/null

echo "==> Release complete"
echo "https://github.com/${OWNER}/${REPO}/releases/tag/${TAG}"
