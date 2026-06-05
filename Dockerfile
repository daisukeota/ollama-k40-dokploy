# ==========================================
# 1. ベースイメージの指定
# ==========================================
# サーバーのNVIDIAドライバー（470.256.02）に最も適合するCUDA 11.4の開発用イメージを使用します
FROM nvidia/cuda:11.4.3-devel-ubuntu20.04

# 環境変数の設定（ビルド時のタイムゾーン選択などのプロンプト停止を防ぎます）
ENV DEBIAN_FRONTEND=noninteractive

# ==========================================
# 2. 必要な依存パッケージと最新のGo言語の導入
# ==========================================
RUN apt-get update && apt-get install -y \
    curl \
    git \
    software-properties-common \
    cmake \
    && add-apt-repository ppa:longsleep/golang-backports -y \
    && apt-get update && apt-get install -y golang-go \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 3. Ollamaのソース取得とチェックアウト
# ==========================================
RUN git clone https://github.com/ollama/ollama.git && \
    cd ollama && \
    git checkout refs/tags/v0.3.0

# ==========================================
# 4. パッチの適用とgpu.goの書き換え（Tesla K40: CC 3.5対応化）
# ==========================================
# エラーの原因になりやすい「継続行（\）の間のコメント」を排除しました
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
# コンパイルターゲットにTesla K40のアーキテクチャ「35」を明示指定します
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
