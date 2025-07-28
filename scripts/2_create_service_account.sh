#!/bin/bash

# ==============================================================================
# 인자 및 설정 파일 처리
# ==============================================================================

# 사용법 확인
if [ $# -eq 0 ]; then
    echo "  Usage: $0 <service_account_name>"
    echo "  Example: $0 project-sa"
    exit 1
fi

# 서비스 계정 이름을 첫 번째 인자로 받기
SA_NAME="$1"

# config.env 파일 읽기
CONFIG_FILE="../config.env"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# config.env 파일을 source로 읽어서 변수 설정
source "$CONFIG_FILE"

# 설정된 계정으로 전환
echo "Switching to account: $ACCOUNT"
gcloud config set account "$ACCOUNT"
if [ $? -ne 0 ]; then
    echo "Failed to switch account: $ACCOUNT"
    echo "Please login with 'gcloud auth login' and try again."
    exit 1
fi

# 설정된 프로젝트로 전환
echo "Switching to project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"
if [ $? -ne 0 ]; then
    echo "Failed to switch project: $PROJECT_ID"
    exit 1
fi

# 서비스 계정 표시 이름과 설명 설정
SA_DISPLAY_NAME="$NAME Project SA"
SA_DESCRIPTION="Service Account for $NAME Project-level plugins"

# 필수 API 목록
REQUIRED_APIS=(
    "iam.googleapis.com"
    "cloudresourcemanager.googleapis.com"
)

# ==============================================================================
# 스크립트 실행 영역 (수정 불필요)
# ==============================================================================

# 서비스 계정 전체 이메일 주소
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"


echo "=================================================="
echo "Starting service account creation."
echo "=================================================="
echo "PROJECT_ID: $PROJECT_ID"
echo "SA_NAME: $SA_NAME"
echo "SA_DISPLAY_NAME: $SA_DISPLAY_NAME"
echo "SA_DESCRIPTION: $SA_DESCRIPTION"
echo ""

# 1. 필수 API 활성화
echo "Enabling required APIs..."
for api in "${REQUIRED_APIS[@]}"; do
    echo "  - Enabling $api..."
    gcloud services enable "$api" --project=$PROJECT_ID
    if [ $? -ne 0 ]; then
        echo "Failed to enable API: $api"
        exit 1
    fi
done
echo "Required APIs enabled successfully."
echo ""

# 2. 서비스 계정 생성
echo "Creating service account..."
gcloud iam service-accounts create $SA_NAME \
    --display-name="$SA_DISPLAY_NAME" \
    --description="$SA_DESCRIPTION" \
    --project=$PROJECT_ID

if [ $? -ne 0 ]; then
    echo "Failed to create service account. Please check if the account already exists."
    exit 1
fi
echo "Service account created successfully: $SA_EMAIL"
echo ""

# 서비스 계정이 실제로 존재하는지 확인 (최대 10번 시도)
echo "Verifying service account creation..."
for i in {1..10}; do
    echo "  Attempt $i/10..."
    if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID > /dev/null 2>&1; then
        echo "Service account verified successfully: $SA_EMAIL"
        break
    else
        if [ $i -eq 10 ]; then
            echo "Failed to verify service account creation."
            exit 1
        fi
        echo "Service account not found. Retrying in 2 seconds..."
        sleep 2
    fi
done
echo ""

echo "Service account creation completed successfully!"
echo "Created service account: $SA_EMAIL"
echo "=================================================="
