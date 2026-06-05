# ==========================================
# 1. ベースイメージの指定
# ==========================================
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# ==========================================
# 2. 必要な依存パッケージと最新のGo言語の導入
# ==========================================
# ※ 後ほど公式スクリプトで最新の CMake を入れるため、ここでは cmake を除外しています
RUN apt-get update && apt-get install -y \
    curl \
    git \
    software-properties-common \
    && add-apt-repository ppa:longsleep/golang-backports -y \
    && apt-get update && apt-get install -y golang-go \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 2.5. 最新の CMake を公式スクリプトからインストール（★ここを追加）
# ==========================================
# Ubuntu標準の3.16を回避し、条件である3.18以上（今回は安定版の3.26系列）を直接導入します
RUN curl -sSL https://cmake.org/files/v3.26/cmake-3.26.4-linux-x86_64.sh -o /tmp/cmake.sh && \
    chmod +x /tmp/cmake.sh && \
    /tmp/cmake.sh --prefix=/usr/local --skip-license && \
    rm /tmp/cmake.sh

# ==========================================
# 3. Ollamaのソース取得とチェックアウト
# ==========================================
RUN git clone https://github.com/ollama/ollama.git && \
    cd ollama && \
    git checkout refs/tags/v0.3.0

# ==========================================
# 4. パッチの適用とgpu.goの書き換え（Tesla K40: CC 3.5対応化）
# ==========================================
RUN cd ollama && \
    curl -OL https://patch-diff.githubusercontent.com/raw/ollama/ollama/pull/2233.patch && \
    git apply 2233.patch && \
    sed -i 's/CudaComputeMajorMin = 5/CudaComputeMajorMin = 3/g' gpu/gpu.go || \
    sed -i 's/"5"/"3"/g' gpu/gpu.go && \
    sed -i 's/CudaComputeMinorMin = 0/CudaComputeMinorMin = 5/g' gpu/gpu.go || \
    sed -i 's/"0"/"5"/g' gpu/gpu.go

# ==========================================
# 5. 環境変数の注入と生成・ビルドの実行
# ==========================================
ENV CMAKE_CUDA_ARCHITECTURES="35"
ENV OLLAMA_CUSTOM_CUDA_ARCH="35"

RUN cd ollama && \
    go generate ./... && \
    go build -ldflags "-w -s -X=github.com/ollama/ollama/gpu.CudaMinVersion=3.5" . && \
    cp ollama /usr/local/bin/ollama

# ==========================================
# 6. コンテナ起動設定
# ==========================================
EXPOSE 11434
ENV OLLAMA_HOST=0.0.0.0

ENTRYPOINT ["ollama", "serve"]
