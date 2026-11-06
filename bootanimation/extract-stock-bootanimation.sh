#!/usr/bin/env bash
# Extracts the stock Google Pixel boot animation(s) from the latest official OTA for a device
# and stores them next to this script (bootanimation/bootanimation*.zip).
#
# Usage: DEVICE_ID=tegu bootanimation/extract-stock-bootanimation.sh
# Requires: curl, unzip, ssh-keygen, docker (for the erofs fallback)
set -o nounset -o pipefail -o errexit

DEVICE_ID=${DEVICE_ID:-tegu}
STOCK_OTA_URL=${STOCK_OTA_URL:-}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${REPO_DIR}/bootanimation"
WORK_DIR="${REPO_DIR}/.tmp/stock-bootanimation"

cd "${REPO_DIR}"
# Reuse avbroot / afsr download + signature verification from the main script
# shellcheck source=../rooted-ota.sh
. ./rooted-ota.sh
set +o nounset
downloadAvBroot
downloadAndVerifyFromChenxiaolong 'afsr' "$AFSR_VERSION"
set -o nounset

mkdir -p "${WORK_DIR}"

if [[ -z "${STOCK_OTA_URL}" ]]; then
  STOCK_OTA_URL=$(curl --fail -sL -H 'Cookie: devsite_wall_acks=nexus-ota-tos' https://developers.google.com/android/ota |
    grep -oE "https://dl\.google\.com/[^\"]*${DEVICE_ID}-ota-[^\"]*\.zip" | tail -n1)
fi
echo "Stock OTA: ${STOCK_OTA_URL}"

stockOta="${WORK_DIR}/$(basename "${STOCK_OTA_URL}")"
if [[ ! -f "${stockOta}" ]]; then
  curl --fail -L -o "${stockOta}" "${STOCK_OTA_URL}"
fi

found=0
for partition in product system; do
  partDir="${WORK_DIR}/${partition}"
  rm -rf "${partDir}" && mkdir -p "${partDir}"

  .tmp/avbroot ota extract --input "${stockOta}" --directory "${partDir}" --partition "${partition}"
  (cd "${partDir}" && "${REPO_DIR}/.tmp/avbroot" avb unpack --input "${partition}.img")

  if ! (cd "${partDir}" && "${REPO_DIR}/.tmp/afsr" unpack --input raw.img >/dev/null 2>&1); then
    echo "afsr could not unpack ${partition}, trying erofs extraction"
    docker run --rm -v "${partDir}:/work" -w /work alpine:3.22 sh -c \
      "apk add --no-cache erofs-utils >/dev/null && mkdir -p fs_tree && fsck.erofs --extract=fs_tree raw.img && chown -R $(id -u):$(id -g) fs_tree"
  fi

  while IFS= read -r -d '' anim; do
    echo "Found stock boot animation: ${anim#"${partDir}/fs_tree/"} (${partition})"
    cp "${anim}" "${OUT_DIR}/$(basename "${anim}")"
    found=1
  done < <(find "${partDir}/fs_tree" -type f -name 'bootanimation*.zip' -print0)

  [[ "${found}" == 1 ]] && break
done

if [[ "${found}" != 1 ]]; then
  echo "No bootanimation*.zip found in stock OTA" >&2
  exit 1
fi

echo "$(basename "${STOCK_OTA_URL}")" > "${OUT_DIR}/SOURCE"
ls -l "${OUT_DIR}"/bootanimation*.zip
