# ==========================================
# 1. ベースイメージの指定
# ==========================================
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# ==========================================
# 2. 必要な依存パッケージと最新のGo言語・GCC11の導入
# ==========================================
# 【修正内容】Ollamaビルドの必須要件である gcc-11 と g++-11 を PPA から明示的に導入し、
# Ubuntu 20.04 のデフォルトコンパイラとして登録します。
RUN apt-get update && apt-get install -y \
    curl \
    git \
    software-properties-common \
    build-essential \
    && add-apt-repository ppa:longsleep/golang-backports -y \
    && add-apt-repository ppa:ubuntu-toolchain-r/test -y \
    && apt-get update && apt-get install -y \
    golang-go \
    gcc-11 \
    g++-11 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 110 \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 2.5. 最新の CMake を公式スクリプトからインストール
# ==========================================
# 【維持】条件である CMake 3.24 以上を満たすため、3.26系列の導入は完璧です。
RUN curl -sSL https://cmake.org/files/v3.26/cmake-3.26.4-linux-x86_64.sh -o /tmp/cmake.sh && \
    chmod +x /tmp/cmake.sh && \
    /tmp/cmake.sh --prefix=/usr/local --skip-license && \
    rm /tmp/cmake.sh

# ==========================================
# 3. Ollamaのソース取得とチェックアウト
# ==========================================
# 【修正内容】WORKDIRを使ってディレクトリを固定し、以降のRUNをスッキリさせます。
RUN git clone https://github.com/ollama/ollama.git /app/ollama && \
    cd /app/ollama && \
    git checkout refs/tags/v0.3.0

WORKDIR /app/ollama

# ==========================================
# 4. パッチの適用とgpu.goの書き換え（Tesla K40: CC 3.5対応化）
# ==========================================
# 【修正内容】危険な一括置換を排除し、変数名まで含めた完全一致で安全に 3.5 へ書き換えます。
RUN curl -OL https://patch-diff.githubusercontent.com/raw/ollama/ollama/pull/2233.patch && \
    git apply 2233.patch && \
    sed -i 's/var CudaComputeMajorMin = "5"/var CudaComputeMajorMin = "3"/' gpu/gpu.go && \
    sed -i 's/var CudaComputeMinorMin = "0"/var CudaComputeMinorMin = "5"/' gpu/gpu.go

# ==========================================
# 5. 環境変数の注入と生成・ビルドの実行
# ==========================================
ENV CMAKE_CUDA_ARCHITECTURES="35"
ENV OLLAMA_CUSTOM_CUDA_ARCH="35"

# CGO_ENABLEDを明示して、確実にホストのGCC(11)を使ってC++コードをコンパイルさせます。
ENV CGO_ENABLED=1

# 【修正内容】出力先パス (-o) を指定して直接 /usr/local/bin にバイナリを配置します。
RUN go generate ./... && \
    go build -ldflags "-w -s -X=github.com/ollama/ollama/gpu.CudaMinVersion=3.5" -o /usr/local/bin/ollama .

# ==========================================
# 6. コンテナ起動設定
# ==========================================
EXPOSE 11434
ENV OLLAMA_HOST=0.0.0.0

# ENTRYPOINTで固定し、Ollamaを起動します。
ENTRYPOINT ["ollama", "serve"]
