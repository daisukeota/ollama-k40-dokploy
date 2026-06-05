# 1. サーバーのドライバー（470.xx）に適合するCUDA 11.4の開発用イメージ
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04

# 環境変数の設定（ビルド時のプロンプト停止防止）
ENV DEBIAN_FRONTEND=noninteractive

# 2. 必要な依存パッケージと最新のGo言語（Ollamaのビルドに必須）のインストール
RUN apt-get update && apt-get install -y \
    curl \
    git \
    software-properties-common \
    cmake \
    && add-apt-repository ppa:longsleep/golang-backports -y \
    && apt-get update && apt-get install -y golang-go \
    && rm -rf /var/lib/apt/lists/*

# 3. Ollamaのソース取得、パッチ適用、CC3.5用書き換え、そしてビルド
# ※コンパイルを確実に通すため、以前成功した v0.3.0 をベースにしています
RUN git clone https://github.com/ollama/ollama.git && \
    cd ollama && \
    git checkout -b ollama_v0.3.0_cc35build refs/tags/v0.3.0 && \
    curl -OL https://patch-diff.githubusercontent.com/raw/ollama/ollama/pull/2233.patch && \
    git apply 2233.patch && \
    # ここで最低要求スペックをCC 3.5に書き換えます（これが肝です）
    sed -i 's/var CudaComputeMajorMin = "5"/var CudaComputeMajorMin = "3"/' gpu/gpu.go && \
    sed -i 's/var CudaComputeMinorMin = "0"/var CudaComputeMinorMin = "5"/' gpu/gpu.go && \
    # コンパイルターゲットにCC 3.5を指定
    export CMAKE_CUDA_ARCHITECTURES="35" && \
    export OLLAMA_CUSTOM_CUDA_ARCH="35" && \
    # コード生成とビルドを実行
    go generate ./... && \
    go build -ldflags "-w -s -X=github.com/ollama/ollama/gpu.CudaMinVersion=3.5" . && \
    # ビルドしたバイナリをパスの通る場所に配置
    cp ollama /usr/local/bin/ollama

# ポートの開放
EXPOSE 11434

# すべてのインターフェースからの接続を許可
ENV OLLAMA_HOST=0.0.0.0

# サーバーモードで起動
ENTRYPOINT ["ollama", "serve"]
