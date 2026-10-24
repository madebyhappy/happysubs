#!/usr/bin/env bash
# Installs the local recogniser that HappySubs' live transcription talks to.
#
# Two ways in, both fine:
#   ./setup.sh                                    from a clone of this repo
#   curl -fsSL <raw url>/setup.sh | bash          on its own, no clone needed
#
# Nothing large is stored in this repository. The two Python files are a few KB;
# the model is ~500MB compressed and comes straight from the sherpa-onnx
# project's own GitHub release, so it costs this project no bandwidth and
# tracks upstream rather than a copy of it.
set -e

RAW="https://raw.githubusercontent.com/madebyhappy/happysubs/main"
MODEL_TARBALL="sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20"
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${MODEL_TARBALL}.tar.bz2"
# The second-pass model: re-recognises each finished sentence for accuracy,
# punctuation, and Japanese / Korean / Cantonese. Optional — server.py runs
# without it — so a failed download here does not fail the install.
REFINE_TARBALL="sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"
REFINE_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${REFINE_TARBALL}.tar.bz2"
STANDALONE_DIR="happysubs-server"

# Running from a clone puts server/ next to this script. Piped from curl there
# is no script on disk and no repo, so fetch the two files we actually need.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/server/server.py" ]; then
  echo "==> 使用仓库里的 server/ · Using server/ from this repository"
  cd "$SCRIPT_DIR/server"
else
  echo "==> 下载识别服务到 ./${STANDALONE_DIR}/ · Downloading the recogniser into ./${STANDALONE_DIR}/"
  mkdir -p "$STANDALONE_DIR"
  cd "$STANDALONE_DIR"
  curl -fsSL --retry 3 -o server.py "$RAW/server/server.py"
  curl -fsSL --retry 3 -o requirements.txt "$RAW/server/requirements.txt"
  curl -fsSL --retry 3 -o start.sh "$RAW/server/start.sh"
  chmod +x start.sh
fi

INSTALL_DIR="$(pwd)"

echo "==> 创建 Python 环境 · Setting up Python"
rm -rf .venv
python3 -m venv .venv
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q -r requirements.txt

if [ -f model/tokens.txt ]; then
  echo "==> 模型已存在,跳过下载 · Model already present, skipping"
else
  echo "==> 下载语音识别模型(约 500MB) · Downloading the speech model (about 500MB)"
  echo "    sherpa-onnx release"
  curl -L --retry 3 -o model.tar.bz2 "$MODEL_URL"
  tar xjf model.tar.bz2
  mv "$MODEL_TARBALL" model
  rm -f model.tar.bz2 \
        model/encoder-epoch-99-avg-1.onnx \
        model/decoder-epoch-99-avg-1.onnx \
        model/joiner-epoch-99-avg-1.onnx
  rm -rf model/test_wavs
fi

if [ -f model-sensevoice/model.int8.onnx ]; then
  echo "==> 二次识别模型已存在,跳过下载 · Second-pass model already present, skipping"
else
  echo "==> 下载二次识别模型(约 155MB) · Downloading the second-pass model (about 155MB)"
  if curl -L --retry 3 -o refine.tar.bz2 "$REFINE_URL" && tar xjf refine.tar.bz2; then
    mkdir -p model-sensevoice
    mv "$REFINE_TARBALL/model.int8.onnx" "$REFINE_TARBALL/tokens.txt" model-sensevoice/
    rm -rf "$REFINE_TARBALL" refine.tar.bz2
  else
    rm -rf "$REFINE_TARBALL" refine.tar.bz2
    echo "    没下载成功,不影响使用;之后重跑一次本命令可补上。"
    echo "    Download failed. Transcription still works without it; run this command again to add it."
  fi
fi

chmod +x start.sh 2>/dev/null || true

echo
echo "==> 安装完成 · Installation complete"
echo
echo "    以后每次用听译前,运行这一行 · Each time before live transcription, run:"
echo
echo "    ${INSTALL_DIR}/start.sh"
echo
echo "    看到「监听 / listening」后,在 HappySubs 弹窗的「实时听译」里点开启。"
echo "    When it says \"listening\", press Start in HappySubs' Live transcribe tab."
