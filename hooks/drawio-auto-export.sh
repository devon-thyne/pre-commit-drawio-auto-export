#!/usr/bin/env bash
# Synopsis: pre-commit script that exports .drawio files to `.png` whenever you commit changes
set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"

FORMAT="png"
DIAGRAMS=()
CHANGES_DETECTED=0

# Parse Arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    *.drawio)
      DIAGRAMS+=("$1")
      shift
      ;;
    *)
      echo "[ERROR]: Unknown option: $1" >&2
      echo "Usage: $0 <file1.drawio> <file2.drawio> ..." >&2
      exit 1
      ;;
  esac
done

# Check Requirements
if command -v exiftool >/dev/null 2>&1; then
  EXIFTOOL="$(command -v exiftool)"
elif [ -x /usr/local/bin/exiftool ]; then
  EXIFTOOL=/usr/local/bin/exiftool
elif [ -x /opt/homebrew/bin/exiftool ]; then
  EXIFTOOL=/opt/homebrew/bin/exiftool
else
  echo "[ERROR]: exiftool not found. Install it or add it to PATH." >&2
  exit 1
fi
if [[ "$OS" == "Linux" ]]; then
  if ! command -v xvfb-run &>/dev/null; then
    echo "[ERROR]: xvfb-run is required but not installed." >&2
    exit 1
  fi
fi

# Diagram Files Input Validation
if [[ ${#DIAGRAMS[@]} -eq 0 ]]; then
  exit 0
fi
echo "Diagrams to convert ($FORMAT):"
for d in "${DIAGRAMS[@]}"; do
  echo "  - $d"
done
echo ""

# Functions
sha256() {
  git show ":$1" | sha256sum | awk '{print $1}'
}

check_diagram_changes() {
  local tmpfile="$1"
  local out="$2"
  local diagram_hash="$3"
  local before_hash="$4"
  local before_perm="$5"

  "$EXIFTOOL" -Comment="drawio-diagram-hash:$diagram_hash" "$tmpfile" >/dev/null 2>&1

  if [[ "$before_hash" != "n/a" ]]; then
    mv -f "$tmpfile" "$out"
    chmod "$before_perm" "$out"
    echo "[ALERT]: file has changed - $out"
    CHANGES_DETECTED=1
  else
    mv "$tmpfile" "$out"
    echo "[ALERT]: new file - $out"
    CHANGES_DETECTED=1
  fi
}

process_diagram_page() {
  local diagram="$1"
  local drawio_binary="$2"
  local output_file="$3"
  local page_index="${4:-1}"

  local tmpfile=$(mktemp)
  local diagram_hash=$(sha256 "$diagram")
  local before_hash="n/a"
  local before_perm="n/a"

  if [[ -f "$output_file" ]]; then
    before_hash=$("$EXIFTOOL" -Comment -s3 "$output_file" | sed 's/^drawio-diagram-hash://')
    if [[ "$OS" == "Linux" ]]; then
      before_perm=$(stat -c "%a" "$output_file")
    else
      before_perm=$(stat -f "%Lp" "$output_file")
    fi
  fi
  if [[ "$diagram_hash" != "$before_hash" ]]; then
    if [[ "$OS" == "Linux" ]]; then
      xvfb-run -a "$drawio_binary" \
        --export --page-index "$page_index" --format "$FORMAT" --output "$tmpfile" "$diagram" \
        --disable-gpu --headless --no-sandbox >/dev/null 2>&1
    else
      "$drawio_binary" \
        --export --page-index "$page_index" --format "$FORMAT" --output "$tmpfile" "$diagram" \
        --disable-gpu --headless --no-sandbox >/dev/null 2>&1
    fi
    check_diagram_changes "$tmpfile" "$output_file" "$diagram_hash" "$before_hash" "$before_perm"
  fi
}

process_diagram() {
  local diagram="$1"
  local drawio_binary="$2"

  local output_file="${diagram%.drawio}.${FORMAT}"
  local diagram_pages="$(\
    cat "$diagram" | grep '<diagram' | sed -n 's/.*name="\([^"]*\)".*/\1/p' | tr ' ' '-' \
  )"

  if [ "$(echo "$diagram_pages" | wc -l)" -eq 1 ]; then
    shopt -s nullglob
    old_exports=( "${diagram%.drawio}"--*.${FORMAT} )
    if (( ${#old_exports[@]} )); then
      rm -- "${old_exports[@]}"
    fi
    process_diagram_page "$diagram" "$drawio_binary" "$output_file"
  else
    if [[ -f "$output_file" ]]; then
      rm "$output_file"
    fi
    index=1
    while IFS= read -r page; do
      [ -z "$page" ] && continue
      output_file="${diagram%.drawio}--${page}.${FORMAT}"
      process_diagram_page "$diagram" "$drawio_binary" "$output_file" "$index"
      index=$((index + 1))
    done <<< "$diagram_pages"
  fi
}

# Linux Export
if [[ "$OS" == "Linux" ]]; then
  APPIMAGE_LATEST_VERSION="$(\
    curl -Ls https://github.com/jgraph/drawio-desktop/releases/latest \
      | grep '<title>Release' | awk -F ' ' '{print $2}' \
  )"
  APPIMAGE="drawio-${ARCH}-${APPIMAGE_LATEST_VERSION}.AppImage"
  APPIMAGE_DIR="$HOME/.cache/pre-commit/drawio-bin"
  APPIMAGE_PATH="$APPIMAGE_DIR/$APPIMAGE"
  mkdir -p "$APPIMAGE_DIR"
  if [[ ! -f "$APPIMAGE_PATH" ]]; then
    curl -Ls -o "$APPIMAGE_PATH" \
      "https://github.com/jgraph/drawio-desktop/releases/download/v${APPIMAGE_LATEST_VERSION}/${APPIMAGE}"
    chmod +x "$APPIMAGE_PATH"
  fi
  if [[ ! -d "$APPIMAGE_DIR/squashfs-root" ]]; then
    (cd "$APPIMAGE_DIR" && "./${APPIMAGE}" --appimage-extract >/dev/null 2>&1)
  fi
  for d in "${DIAGRAMS[@]}"; do
    process_diagram "$d" "$APPIMAGE_DIR/squashfs-root/drawio"
  done

# MacOS Export
elif [[ "$OS" == "Darwin" ]]; then
  DRAWIO_BIN="/Applications/draw.io.app/Contents/MacOS/draw.io"
  if [[ ! -x "$DRAWIO_BIN" ]]; then
    echo "[ERROR]: Draw.io app not found in /Applications. Please install it." >&2
    exit 1
  fi
  for d in "${DIAGRAMS[@]}"; do
    process_diagram "$d" "$DRAWIO_BIN"
  done

else
  echo "[ERROR]: Unsupported OS - $OS" >&2
  exit 1
fi

if [[ $CHANGES_DETECTED -eq 1 ]]; then
  exit 1
fi
