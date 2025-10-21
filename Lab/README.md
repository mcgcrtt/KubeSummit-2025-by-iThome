# Image-analysis Service - 使用 GraalVM Native Spring 的 Cloud Run 服務

**原始碼來源：** https://github.com/GoogleCloudPlatform/serverless-photosharing-workshop

本實驗將在 Compute Engine VM 上執行建置工作，然後部署到 Google Cloud Run。

## 架構說明

應用程式流程：
1. 使用者上傳圖片到 Cloud Storage
2. Cloud Storage 觸發 Eventarc 事件
3. Eventarc 呼叫 Cloud Run 服務
4. Cloud Run 服務使用 Vision API 分析圖片
5. 分析結果儲存到 Firestore

## 前置準備

### 建立 Compute Engine VM

建議在 VM 上執行建置工作，建議規格：
- **地區**：asia-east1 (台灣)
- **作業系統**：Ubuntu 24.04 LTS x86/64
- **機器類型**：e2-standard-4 (4 vCPUs, 16 GB Memory)
- **開機磁碟大小**：100 GB

> **注意**：Native Image 編譯需要較多記憶體，建議至少使用 16 GB 記憶體的機器類型。

### 環境設定

連線到 VM 後，執行安裝腳本來安裝所需工具（Docker、GraalVM、Maven 等）：

```bash
# Clone workshop repository
git clone https://github.com/mcgcrtt/KubeSummit-2025-by-iThome.git
cd spring-native-workshop/Lab

# 執行安裝腳本
chmod +x ./env/setup.sh
./env/setup.sh
```

### 驗證 Java 環境

確認使用的是 GraalVM：

```bash
# 載入 SDKMAN 環境
. $HOME/.sdkman/bin/sdkman-init.sh

# 檢查當前 Java 版本
sdk current java

# 驗證 JAVA_HOME
echo $JAVA_HOME
```

## Google Cloud 認證設定

### 登入 Google Cloud

```bash
# 登入 Google Cloud
gcloud auth login

# 設定應用程式預設憑證 (ADC)
gcloud auth application-default login
```

### 設定專案環境變數

```bash
# 設定專案 ID
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')

# 設定 gcloud 預設值
gcloud config set project ${PROJECT_ID}
gcloud config set run/platform managed
gcloud config set eventarc/location asia-east1
```

### 啟用所需的 Google Cloud API

```bash
# 啟用 Vision API (圖片分析)、Cloud Functions API、Cloud Build API、Cloud Run API、Artifact Registry API、Eventarc API、Pub/Sub API (Eventarc 需要)
gcloud services enable \
    vision.googleapis.com \
    cloudfunctions.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    eventarc.googleapis.com \
    pubsub.googleapis.com
```

### 建立 Artifact Registry Repository

使用 gcloud CLI 或從 GCP Console 建立：

```bash
# 建立 JIT 版本的 Docker Repository
gcloud artifacts repositories create jit-image-docker-repo \
  --repository-format=docker \
  --location=asia-east1 \
  --description="JIT version Docker images"

# 建立 Native 版本的 Docker Repository
gcloud artifacts repositories create native-image-docker-repo \
  --repository-format=docker \
  --location=asia-east1 \
  --description="Native version Docker images"
```

## 建立 Google Cloud Storage

### 建立 Storage Bucket

使用 gcloud CLI 或從 GCP Console 建立，用於儲存上傳圖片的 GCS Bucket：

```bash
# 設定 Bucket 名稱
export BUCKET_PICTURES=uploaded-pictures-${PROJECT_ID}

# 建立 Bucket (位於台灣區域)
gsutil mb -l asia-east1 gs://${BUCKET_PICTURES}

# 啟用統一的 Bucket 層級存取控制
gsutil uniformbucketlevelaccess set on gs://${BUCKET_PICTURES}

# 設定公開讀取權限
gsutil iam ch allUsers:objectViewer gs://${BUCKET_PICTURES}
```

### 設定 Storage 服務帳戶權限

為了讓 Cloud Storage 能夠發送 Pub/Sub 事件，需要授予服務帳戶 `pubsub.publisher` 權限：

```bash
# 取得 Cloud Storage 服務帳戶
SERVICE_ACCOUNT="$(gsutil kms serviceaccount -p ${PROJECT_ID})"

# 授予 pubsub.publisher 角色
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role='roles/pubsub.publisher'
```

## 建立 Firestore 資料庫

### 透過 Console 建立 Firestore

1. 前往 [Google Cloud Console - Firestore](https://console.cloud.google.com/firestore)
2. 點擊「建立資料庫」
3. 選擇 **Native mode**
4. 選擇區域（建議選擇：`asia-east1`）
5. 點擊「建立」

### 建立 Collection

在 Firestore Console 中：
1. 點擊「Start Collection」
2. Collection ID 輸入：`pictures`
3. 新增一個測試文件（之後會由應用程式自動寫入）
4. 將測試文件刪除

### 建立複合索引

```bash
# 建立用於查詢的複合索引
gcloud firestore indexes composite create \
  --collection-group=pictures \
  --field-config field-path=thumbnail,order=descending \
  --field-config field-path=created,order=descending
```

> **注意**：索引建立可能需要數分鐘時間。

## 本地建置與測試

### JIT 版本

建置 JIT 應用程式：
```bash
# 使用 Maven Wrapper 建置專案
./mvnw package -Pjit

# 啟動應用程式（選用）
java -jar target/image-analysis-0.0.1.jar
```

建置 JIT Docker 映像檔：
```bash
# 使用 jit profile 建置 Docker 映像檔
./mvnw spring-boot:build-image -Pjit

# 啟動應用程式（選用）
docker run --rm image-analysis-maven-jit:latest
```

### Native 版本

建置 Native 執行檔：
```bash
# 使用 native profile 建置原生執行檔
./mvnw native:compile -Pnative

# 執行原生執行檔（選用）
./target/image-analysis
```

> **重要**：Native 編譯需要較長時間（約 10-20 分鐘），請耐心等待。

建置 Native Docker 映像檔：
```bash
# 使用 native profile 建置 Docker 映像檔
./mvnw spring-boot:build-image -Pnative

# 啟動應用程式（選用）
docker run --rm image-analysis-maven-native:latest
```

### 比較映像檔大小

```bash
# 查看兩個版本的映像檔大小
docker images | grep image-analysis
```

預期結果：
```
image-analysis-maven-jit       latest    6751b98f7ebf   42 years ago    ~400MB
image-analysis-maven-native    latest    3af942985d65   42 years ago    ~200MB
```

### 效能比較總結

| 指標 | JIT 版本 | Native 版本 | 改善幅度 |
|------|----------|-------------|----------|
| 映像檔大小 | ~400MB | ~200MB | **減少 50%** |
| 啟動時間 | ~5-10 秒 | ~0.05-0.1 秒 | **快 95%** |
| 建置時間 | ~1-3 分鐘 | ~10-20 分鐘 | - |

## 部署到 Cloud Run

### 設定 Docker 認證

```bash
# 設定 Docker 認證
gcloud auth configure-docker asia-east1-docker.pkg.dev
```

### 部署 JIT 版本

```bash
# 標記映像檔
docker tag image-analysis-maven-jit asia-east1-docker.pkg.dev/$PROJECT_ID/jit-image-docker-repo/lab2-jit-image:v1

# 推送到 Artifact Registry
docker push asia-east1-docker.pkg.dev/$PROJECT_ID/jit-image-docker-repo/lab2-jit-image:v1

# 部署到 Cloud Run
gcloud run deploy my-jit-service \
  --image asia-east1-docker.pkg.dev/$PROJECT_ID/jit-image-docker-repo/lab2-jit-image:v1 \
  --region asia-east1 \
  --memory=2Gi \
  --allow-unauthenticated
```

### 部署 Native 版本

```bash
# 標記映像檔
docker tag image-analysis-maven-native asia-east1-docker.pkg.dev/$PROJECT_ID/native-image-docker-repo/lab2-native-image:v1

# 推送到 Artifact Registry
docker push asia-east1-docker.pkg.dev/$PROJECT_ID/native-image-docker-repo/lab2-native-image:v1

# 部署到 Cloud Run
gcloud run deploy my-native-service \
  --image asia-east1-docker.pkg.dev/$PROJECT_ID/native-image-docker-repo/lab2-native-image:v1 \
  --region asia-east1 \
  --memory=2Gi \
  --allow-unauthenticated
```

部署完成後，可以在 [Cloud Run Console](https://console.cloud.google.com/run) 查看服務。

### 部署時間比較

**JIT 映像檔啟動時間：**
```
Started ImageAnalysisApplication in 5.754 seconds
```

**Native 映像檔啟動時間：**
```
Started ImageAnalysisApplication in 0.0868 seconds
```

## 設定 Eventarc 觸發器

Eventarc 可以讓 Cloud Storage 事件自動觸發 Cloud Run 服務。

### 建立觸發器

```bash
# 建立 JIT 服務的 Eventarc Trigger
gcloud eventarc triggers create image-analysis-jit-trigger \
     --destination-run-service=my-jit-service \
     --destination-run-region=asia-east1 \
     --location=asia-east1 \
     --event-filters="type=google.cloud.storage.object.v1.finalized" \
     --event-filters="bucket=uploaded-pictures-${PROJECT_ID}" \
     --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com

# 建立 Native 服務的 Eventarc Trigger
gcloud eventarc triggers create image-analysis-native-trigger \
     --destination-run-service=my-native-service \
     --destination-run-region=asia-east1 \
     --location=asia-east1 \
     --event-filters="type=google.cloud.storage.object.v1.finalized" \
     --event-filters="bucket=uploaded-pictures-${PROJECT_ID}" \
     --service-account=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com
```

### 驗證觸發器

```bash
# 列出所有 triggers
gcloud eventarc triggers list --location=asia-east1
```

## 測試事件驅動流程

### 上傳圖片到 Cloud Storage

準備一張測試圖片，然後上傳到 Cloud Storage：

```bash
# 上傳圖片
gsutil cp /path/to/your/image.jpg gs://${BUCKET_PICTURES}/

# 或使用 gcloud 指令
gcloud storage cp /path/to/your/image.jpg gs://${BUCKET_PICTURES}/
```

### 查看 Cloud Run 日誌

使用以下指令查看服務日誌：

```bash
# 查看 JIT 服務日誌
gcloud logging read "resource.labels.service_name=my-jit-service" --limit 50 --format=json

# 查看 Native 服務日誌
gcloud logging read "resource.labels.service_name=my-native-service" --limit 50 --format=json
```

### 驗證 Firestore 資料

1. 前往 [Firestore Console](https://console.cloud.google.com/firestore)
2. 查看 `pictures` collection
3. 確認有新的文件包含圖片分析結果

## 效能監控

### 查看 Cloud Run 指標

1. 前往 [Cloud Run Console](https://console.cloud.google.com/run)
2. 分別點選 `my-jit-service` 和 `my-native-service`
3. 查看「指標」標籤，比較兩者的啟動時間、記憶體使用等指標

## 清理資源

完成實驗後，記得清理資源以避免產生費用：

### 刪除 Eventarc Triggers

```bash
gcloud eventarc triggers delete image-analysis-jit-trigger --location=asia-east1 --quiet
gcloud eventarc triggers delete image-analysis-native-trigger --location=asia-east1 --quiet
```

### 刪除 Cloud Run 服務

```bash
gcloud run services delete my-jit-service --region asia-east1 --quiet
gcloud run services delete my-native-service --region asia-east1 --quiet
```

### 刪除 Artifact Registry Repositories

```bash
gcloud artifacts repositories delete jit-image-docker-repo --location=asia-east1 --quiet
gcloud artifacts repositories delete native-image-docker-repo --location=asia-east1 --quiet
```

### 刪除 Cloud Storage Bucket

```bash
# 刪除 Bucket 及其內容
gsutil rm -r gs://${BUCKET_PICTURES}
```

### 刪除 Firestore 資料庫

> **注意**：Firestore 資料庫需要透過 Console 手動刪除

1. 前往 [Firestore Console](https://console.cloud.google.com/firestore)
2. 點擊資料庫設定
3. 選擇「刪除資料庫」

### 刪除 Compute Engine VM

透過 [Compute Engine Console](https://console.cloud.google.com/compute/instances) 刪除。

> **提示**：刪除 VM 時，預設會一併刪除開機磁碟。

## 重要概念總結

### JIT vs Native Image

| 特性 | JIT 編譯 | Native Image |
|------|----------|--------------|
| 編譯時機 | 執行時編譯 | 建置時編譯 |
| 啟動速度 | 較慢 (5-10秒) | 極快 (<0.1秒) |
| 記憶體使用 | 較高 | 較低 |
| 執行效能 | 長時間運行後最佳 | 立即最佳 |
| 建置時間 | 快 (1-5分鐘) | 慢 (10-20分鐘) |
| 映像檔大小 | 較大 (~400MB) | 較小 (~200MB) |
| 最佳使用場景 | 長期運行的服務 | Serverless/容器化應用 |

### 何時使用 Native Image？

✅ **適合使用**：
- Serverless 環境（Cloud Run, AWS Lambda）
- 需要快速啟動的應用
- 短期運行的任務
- 容器化微服務
- 資源受限環境

❌ **不建議使用**：
- 大量使用反射的應用
- 需要動態類別載入
- 開發階段（建置時間長）
- 需要 JVM 調優的場景
