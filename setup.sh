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

# Messages follow the system language: the five the extension's interface has,
# English for anything else. HAPPYSUBS_LANG=ja (etc.) overrides it. On a Mac
# $LANG is often empty or set by Terminal, so read the system setting instead.
# "Installation complete" and "listening" stay in English in every language,
# because the website and the popup tell people to wait for those words.
ui_lang() {
  l="${HAPPYSUBS_LANG:-}"
  if [ -z "$l" ] && [ "$(uname -s)" = "Darwin" ]; then
    l="$(defaults read -g AppleLanguages 2>/dev/null </dev/null | sed -n '2s/[^A-Za-z_-]//gp')"
  fi
  [ -z "$l" ] && l="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  case "$l" in
    zh-Hant*|zh_Hant*|zh-TW*|zh_TW*|zh-HK*|zh_HK*|zh-MO*|zh_MO*) echo zh-Hant ;;
    zh*) echo zh ;;
    ja*) echo ja ;;
    vi*) echo vi ;;
    *) echo en ;;
  esac
}

case "$(ui_lang)" in
  zh)
    M_REPO="使用仓库里的 server/"
    M_FETCH="下载识别服务到 ./${STANDALONE_DIR}/"
    M_PYTHON="创建 Python 环境"
    M_MODEL_SKIP="模型已存在，跳过下载"
    M_MODEL_GET="下载语音识别模型（约 500MB）"
    M_REFINE_SKIP="二次识别模型已存在，跳过下载"
    M_REFINE_GET="下载二次识别模型（约 155MB）"
    M_REFINE_FAIL="没下载成功，不影响使用；之后重跑一次本命令可补上。"
    M_DONE="安装完成 · Installation complete"
    M_EACH="以后每次用听译前，运行这一行："
    M_THEN="看到「监听 · listening」后，在 HappySubs 弹窗的「实时听译」里点开启。"
    ;;
  zh-Hant)
    M_REPO="使用儲存庫裡的 server/"
    M_FETCH="下載辨識服務到 ./${STANDALONE_DIR}/"
    M_PYTHON="建立 Python 環境"
    M_MODEL_SKIP="模型已存在，略過下載"
    M_MODEL_GET="下載語音辨識模型（約 500MB）"
    M_REFINE_SKIP="二次辨識模型已存在，略過下載"
    M_REFINE_GET="下載二次辨識模型（約 155MB）"
    M_REFINE_FAIL="沒下載成功，不影響使用；之後再執行一次本指令即可補上。"
    M_DONE="安裝完成 · Installation complete"
    M_EACH="以後每次用聽譯前，執行這一行："
    M_THEN="看到「監聽 · listening」後，在 HappySubs 彈窗的「即時聽譯」裡點開啟。"
    ;;
  ja)
    M_REPO="リポジトリの server/ を使います"
    M_FETCH="認識プログラムを ./${STANDALONE_DIR}/ にダウンロード中"
    M_PYTHON="Python 環境を準備中"
    M_MODEL_SKIP="モデルはすでにあります。スキップします"
    M_MODEL_GET="音声認識モデルをダウンロード中（約 500MB）"
    M_REFINE_SKIP="2回目の認識モデルはすでにあります。スキップします"
    M_REFINE_GET="2回目の認識モデルをダウンロード中（約 155MB）"
    M_REFINE_FAIL="ダウンロードに失敗しました。なくても使えます。もう一度このコマンドを実行すると追加されます。"
    M_DONE="インストール完了 · Installation complete"
    M_EACH="文字起こしを使う前に、毎回これを実行します："
    M_THEN="「listening」と出たら、HappySubs のポップアップの「文字起こし」で開始を押します。"
    ;;
  vi)
    M_REPO="Dùng thư mục server/ trong kho mã này"
    M_FETCH="Đang tải chương trình nhận dạng vào ./${STANDALONE_DIR}/"
    M_PYTHON="Đang thiết lập Python"
    M_MODEL_SKIP="Mô hình đã có sẵn, bỏ qua"
    M_MODEL_GET="Đang tải mô hình nhận dạng giọng nói (khoảng 500MB)"
    M_REFINE_SKIP="Mô hình nhận dạng lần hai đã có sẵn, bỏ qua"
    M_REFINE_GET="Đang tải mô hình nhận dạng lần hai (khoảng 155MB)"
    M_REFINE_FAIL="Tải không thành công. Vẫn dùng được khi thiếu nó; chạy lại lệnh này để bổ sung."
    M_DONE="Cài đặt xong · Installation complete"
    M_EACH="Mỗi lần trước khi dùng phụ đề trực tiếp, hãy chạy:"
    M_THEN="Thấy chữ “listening” thì bấm Bắt đầu trong thẻ “Phụ đề trực tiếp” của HappySubs."
    ;;
  *)
    M_REPO="Using server/ from this repository"
    M_FETCH="Downloading the recogniser into ./${STANDALONE_DIR}/"
    M_PYTHON="Setting up Python"
    M_MODEL_SKIP="Model already present, skipping"
    M_MODEL_GET="Downloading the speech model (about 500MB)"
    M_REFINE_SKIP="Second-pass model already present, skipping"
    M_REFINE_GET="Downloading the second-pass model (about 155MB)"
    M_REFINE_FAIL="Download failed. Transcription still works without it; run this command again to add it."
    M_DONE="Installation complete"
    M_EACH="Each time before live transcription, run:"
    M_THEN="When it says \"listening\", press Start in HappySubs' Live transcribe tab."
    ;;
esac

# Running from a clone puts server/ next to this script. Piped from curl there
# is no script on disk and no repo, so fetch the two files we actually need.
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/server/server.py" ]; then
  echo "==> $M_REPO"
  cd "$SCRIPT_DIR/server"
else
  echo "==> $M_FETCH"
  mkdir -p "$STANDALONE_DIR"
  cd "$STANDALONE_DIR"
  curl -fsSL --retry 3 -o server.py "$RAW/server/server.py"
  curl -fsSL --retry 3 -o requirements.txt "$RAW/server/requirements.txt"
  curl -fsSL --retry 3 -o start.sh "$RAW/server/start.sh"
  chmod +x start.sh
fi

INSTALL_DIR="$(pwd)"

echo "==> $M_PYTHON"
rm -rf .venv
python3 -m venv .venv
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q -r requirements.txt

if [ -f model/tokens.txt ]; then
  echo "==> $M_MODEL_SKIP"
else
  echo "==> $M_MODEL_GET"
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
  echo "==> $M_REFINE_SKIP"
else
  echo "==> $M_REFINE_GET"
  if curl -L --retry 3 -o refine.tar.bz2 "$REFINE_URL" && tar xjf refine.tar.bz2; then
    mkdir -p model-sensevoice
    mv "$REFINE_TARBALL/model.int8.onnx" "$REFINE_TARBALL/tokens.txt" model-sensevoice/
    rm -rf "$REFINE_TARBALL" refine.tar.bz2
  else
    rm -rf "$REFINE_TARBALL" refine.tar.bz2
    echo "    $M_REFINE_FAIL"
  fi
fi

chmod +x start.sh 2>/dev/null || true

echo
echo "==> $M_DONE"
echo
echo "    $M_EACH"
echo
echo "    ${INSTALL_DIR}/start.sh"
echo
echo "    $M_THEN"
