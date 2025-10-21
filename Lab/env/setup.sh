#!/bin/bash
set -e  # 遇到錯誤立即停止

echo "=========================================="
echo "開始安裝 Spring Native Workshop 所需環境"
echo "=========================================="

# ============================================
# 1. 安裝 Docker
# ============================================
echo ""
echo "[1/6] 安裝 Docker..."
echo "----------------------------------------"

# 添加 Docker 官方 GPG key
echo "→ 更新套件列表並安裝必要工具..."
sudo apt-get update -qq
sudo apt-get install -y ca-certificates curl

echo "→ 設定 Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 添加 Docker repository 到 Apt sources
echo "→ 添加 Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "→ 更新套件列表..."
sudo apt-get update -qq

# 安裝 Docker 相關套件
echo "→ 安裝 Docker Engine 及相關工具..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 啟動 Docker 服務
echo "→ 啟動 Docker 服務..."
sudo systemctl start docker
sudo systemctl enable docker

echo "✓ Docker 安裝完成！"
docker --version

# ============================================
# 2. 安裝 build-essential 編譯工具
# ============================================
echo ""
echo "[2/6] 安裝 build-essential 編譯工具..."
echo "----------------------------------------"

# 安裝 build-essential (包含 gcc, g++, make 等)
# 編譯 native image 時需要這些工具
echo "→ 更新套件列表..."
sudo apt-get update -qq

echo "→ 安裝 build-essential 和相關開發工具..."
sudo apt-get install -y build-essential zlib1g-dev

# 驗證安裝
echo "✓ build-essential 安裝完成！"
gcc --version | head -n 1

# ============================================
# 3. 安裝 SDKMAN!
# ============================================
echo ""
echo "[3/6] 安裝 SDKMAN!..."
echo "----------------------------------------"

# 安裝 SDKMAN! 所需的依賴套件
echo "→ 安裝必要工具 (curl, zip, unzip)..."
sudo apt-get update -qq
sudo apt-get install -y curl zip unzip

# 安裝 SDKMAN!
echo "→ 下載並安裝 SDKMAN!..."
curl -s "https://get.sdkman.io" | bash

# 載入 SDKMAN! 環境
echo "→ 初始化 SDKMAN! 環境..."
source "$HOME/.sdkman/bin/sdkman-init.sh"

echo "✓ SDKMAN! 安裝完成！"
sdk version

# ============================================
# 4. 安裝 GraalVM Java 17
# ============================================
echo ""
echo "[4/6] 安裝 GraalVM Java 17..."
echo "----------------------------------------"

# 使用 SDKMAN! 安裝 GraalVM
# GraalVM 是支援 Spring Native 的關鍵元件
echo "→ 透過 SDKMAN! 安裝 GraalVM 17.0.8..."
sdk install java 17.0.8-graal

# 設定 GraalVM 為當前使用的 Java 版本
echo "→ 設定 GraalVM 為預設 Java 版本..."
sdk use java 17.0.8-graal

echo "✓ GraalVM Java 17 安裝完成！"
java -version

# ============================================
# 5. 安裝 Maven
# ============================================
echo ""
echo "[5/6] 安裝 Maven..."
echo "----------------------------------------"

echo "→ 安裝 Maven 建置工具..."
sudo apt-get install -y maven

echo "✓ Maven 安裝完成！"
mvn -version

# ============================================
# 6. 產生 Maven Wrapper
# ============================================
echo ""
echo "[6/6] 產生 Maven Wrapper..."
echo "----------------------------------------"

# The Maven Wrapper is an easy way to ensure a user of your Maven build
# has everything necessary to run your Maven build.
# 產生 Wrapper 後，其他使用者不需安裝 Maven 就能執行專案建置
echo "→ 產生 Maven Wrapper 檔案 (mvnw / mvnw.cmd)..."
mvn wrapper:wrapper

echo "✓ Maven Wrapper 產生完成！"
echo "  • 已產生 mvnw (Unix/Mac) 和 mvnw.cmd (Windows)"
echo "  • 其他使用者可直接使用 ./mvnw 指令，無需安裝 Maven"
echo "  • Wrapper 會自動下載並使用專案指定的 Maven 版本"

# ============================================
# 安裝完成
# ============================================
echo ""
echo "=========================================="
echo "✓ 所有環境安裝完成！"
echo "=========================================="
echo ""
echo "已安裝的工具版本："
echo "  • Docker:   $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  • GCC:      $(gcc --version | head -n 1 | awk '{print $4}')"
echo "  • SDKMAN:   $(sdk version)"
echo "  • Java:     $(java -version 2>&1 | head -n 1)"
echo "  • Maven:    $(mvn -version | head -n 1 | cut -d' ' -f3)"
echo ""
echo "=========================================="
