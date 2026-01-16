#!/usr/bin/env bash
set -euo pipefail

TESS_VERSION="5.4.1"
LEPT_VERSION="1.84.1"

ROOT="$(pwd)"
WORK="$ROOT/work"
DIST="$ROOT/dist/tesseract-linux64"

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

echo "== Download leptonica =="
cd "$WORK"
curl -L -o leptonica.tar.gz "https://github.com/DanBloomberg/leptonica/archive/refs/tags/${LEPT_VERSION}.tar.gz"
tar -xzf leptonica.tar.gz
LEPT_DIR="$WORK/leptonica-${LEPT_VERSION}"

echo "== Build leptonica =="
mkdir -p "$LEPT_DIR/build"
cd "$LEPT_DIR/build"
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$DIST" \
  -DBUILD_SHARED_LIBS=ON
cmake --build . -j2
cmake --install .

echo "== Download tesseract =="
cd "$WORK"
curl -L -o tesseract.tar.gz "https://github.com/tesseract-ocr/tesseract/archive/refs/tags/${TESS_VERSION}.tar.gz"
tar -xzf tesseract.tar.gz
TESS_DIR="$WORK/tesseract-${TESS_VERSION}"

echo "== Build tesseract (no training tools) =="
mkdir -p "$TESS_DIR/build"
cd "$TESS_DIR/build"

cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$DIST" \
  -DBUILD_TRAINING_TOOLS=OFF \
  -DLeptonica_DIR="$DIST/lib/cmake/leptonica" \
  -DCMAKE_PREFIX_PATH="$DIST"

cmake --build . -j2
cmake --install .

echo "== Download minimal tessdata (eng + osd) =="
mkdir -p "$DIST/share/tessdata"
curl -L -o "$DIST/share/tessdata/eng.traineddata" \
  "https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata"
curl -L -o "$DIST/share/tessdata/osd.traineddata" \
  "https://github.com/tesseract-ocr/tessdata_best/raw/main/osd.traineddata"

echo "== Create wrapper script =="
mkdir -p "$DIST/bin" "$DIST/lib"

cat > "$DIST/bin/run_tesseract.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"

export LD_LIBRARY_PATH="$HERE/lib:$LD_LIBRARY_PATH"
export TESSDATA_PREFIX="$HERE/share"

exec "$HERE/bin/tesseract" "$@"
EOF
chmod +x "$DIST/bin/run_tesseract.sh"

echo "Tesseract: ${TESS_VERSION}" > "$DIST/VERSION.txt"
echo "Leptonica: ${LEPT_VERSION}" >> "$DIST/VERSION.txt"

echo "== DONE =="
echo "Bundle created at: $DIST"
ls -la "$DIST"
