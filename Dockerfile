# ベースイメージ(CUDA)の指定
FROM nvcr.io/nvidia/pytorch:21.10-py3

RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# 必須ツールのインストール
RUN apt-get update && apt-get install -y \
    cmake software-properties-common curl git

# Goのインストール
RUN add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && apt-get install -y golang

# GCC-11のインストール
RUN apt-get install -y build-essential manpages-dev && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && apt-get install -y gcc-11 g++-11 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110

WORKDIR /work

# Ollamaのソース取得とCC3.5(K40)対応パッチ適用・ビルド
RUN git clone https://github.com/ollama/ollama.git && \
    cd ollama && \
    git checkout -b ollama_v0.3.0_cc35build refs/tags/v0.3.0 && \
    curl -OL https://patch-diff.githubusercontent.com/raw/ollama/ollama/pull/2233.patch && \
    git apply 2233.patch && \
    sed -i 's/var CudaComputeMajorMin = "5"/var CudaComputeMajorMin = "3"/' gpu/gpu.go && \
    sed -i 's/var CudaComputeMinorMin = "0"/var CudaComputeMinorMin = "5"/' gpu/gpu.go && \
    export CMAKE_CUDA_ARCHITECTURES="35" && \
    export OLLAMA_CUSTOM_CUDA_ARCH="35" && \
    go generate ./... && \
    go build -ldflags "-w -s -X=github.com/ollama/ollama/gpu.CudaMinVersion=3.5" .

# Ollamaのサーバー設定
ENV OLLAMA_HOST=0.0.0.0
EXPOSE 11434

WORKDIR /work/ollama
# コンテナ起動時にOllamaサーバーを立ち上げる
CMD ["./ollama", "serve"]
