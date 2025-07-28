# gcloud-service-account-manager

Google Cloud 서비스 계정을 효율적으로 관리하는 도구입니다. 조직 및 프로젝트 레벨에서 서비스 계정을 생성하고, 필요한 권한과 API를 자동으로 설정할 수 있습니다.

## 설치 및 설정

### 1. gcloud CLI 설치
[OFFICIAL DOCS LINK](https://cloud.google.com/sdk/docs/install?hl=ko)

```bash
# RECOMMAND HOME DIR
cd
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
tar -xf google-cloud-cli-linux-x86_64.tar.gz

# FOR UPDATE INSTALL PATH
./google-cloud-sdk/install.sh

# REQUIRE LOGIN
./google-cloud-sdk/bin/gcloud init

# check login status : below step always require login
gcloud auth list
gcloud config set account [ACCOUNT_EMAIL]
```

```bash
# check install status
$ gcloud version

    Google Cloud SDK 531.0.0
    bq 2.1.20
    bundled-python3-unix 3.12.9
    core 2025.07.18
    gcloud-crc32c 1.0.0
    gsutil 5.35
```

### 2. 필수 도구 설치

```bash
# jq 설치 (JSON 파싱용)
# Ubuntu/Debian
sudo apt-get install jq

# CentOS/RHEL
sudo yum install jq

# macOS
brew install jq
```

## 사용법

### 1. 초기 설정 (1_INIT.sh)
필요한 환경 구성을 생성합니다.

```bash
scripts/1_init.sh
```

이 스크립트는 다음 작업을 수행합니다:
- 인증된 Google Cloud 계정 선택
- 조직 ID 선택 및 설정
- 프로젝트 ID 선택 및 설정
- `config.env` 파일 자동 생성

### 2. 서비스 계정 생성 (2_create_service_account.sh)
새로운 서비스 계정을 생성합니다.

```bash
scripts/2_create_service_account.sh <service_account_name>
```

예시:
```bash
scripts/2_create_service_account.sh project-sa
```

이 스크립트는 다음 작업을 수행합니다:
- 필수 API 활성화 (IAM, Cloud Resource Manager)
- 서비스 계정 생성
- 서비스 계정 키 파일 생성

### 3. 프로젝트 레벨 권한 및 API 할당 (3_assign_roles_and_apis.sh)
서비스 계정에 프로젝트 레벨 권한과 API를 할당합니다.

```bash
scripts/3_assign_roles_and_apis.sh
```

이 스크립트는 다음 작업을 수행합니다:
- 프로젝트 내 서비스 계정 목록 표시
- 사용자가 서비스 계정 선택
- `config/roles.json`의 프로젝트 역할 할당
- `config/apis.json`의 API 활성화

### 4. 조직 레벨 권한 및 API 할당 (4_assing_org_roles_and_apis.sh)
서비스 계정에 조직 레벨 권한과 API를 할당합니다.

```bash
scripts/4_assing_org_roles_and_apis.sh
```

이 스크립트는 다음 작업을 수행합니다:
- 프로젝트 내 서비스 계정 목록 표시
- 사용자가 서비스 계정 선택
- `config/roles.json`의 조직 역할 할당
- `config/apis.json`의 API 활성화

## 전체 워크플로우

1. **초기 설정**: `scripts/1_init.sh` 실행하여 환경 구성
2. **서비스 계정 생성**: `scripts/2_create_service_account.sh` 실행하여 새 서비스 계정 생성
3. **프로젝트 권한 할당**: `scripts/3_assign_roles_and_apis.sh` 실행하여 프로젝트 레벨 권한 설정
4. **조직 권한 할당**: `scripts/4_assing_org_roles_and_apis.sh` 실행하여 조직 레벨 권한 설정

## 주의사항

- 모든 스크립트 실행 전에 `gcloud auth login`으로 로그인되어 있어야 합니다.
- 조직 레벨 권한 할당은 조직 관리자 권한이 필요합니다.

## 문제 해결

### 일반적인 오류

1. **인증 오류**: `gcloud auth login`으로 다시 로그인
2. **권한 부족**: 조직 관리자에게 필요한 권한 요청
3. **jq 명령어 없음**: 위의 설치 지침에 따라 jq 설치
