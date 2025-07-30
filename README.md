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

### 전체 워크플로우 개요

이 도구는 다음 순서로 실행됩니다:

1. **초기 설정** (`1_init.sh`) - 계정, 조직, 프로젝트 선택 및 설정
2. **서비스 계정 생성** (`2_create_service_account.sh`) - 프로젝트 레벨 서비스 계정 생성
3. **커스텀 역할 생성** (`3_1_create_custom_role_with_permissions.sh`) - 프로젝트 레벨 커스텀 역할 생성
4. **조직 레벨 커스텀 역할 생성** (`3_2_create_custom_org_role_with_permissions.sh`) - 조직 레벨 커스텀 역할 생성
5. **프로젝트 권한 및 API 할당** (`4_1_assign_roles_and_apis.sh`) - 프로젝트 레벨 권한 설정
6. **조직 권한 및 API 할당** (`4_2_assing_org_roles_and_apis.sh`) - 조직 레벨 권한 설정

### 단계별 실행 가이드

#### 1단계: 초기 설정 및 환경 구성

```bash
# 스크립트 디렉토리로 이동
cd scripts

# 초기 설정 실행
./1_init.sh
```

**실행 과정:**
- Google Cloud 계정 인증 상태 확인
- 사용 가능한 계정 목록 표시 및 선택
- 조직 ID 선택 (조직이 없는 경우 빈 값으로 설정)
- 프로젝트 목록 표시 및 선택
- `config.env` 파일 자동 생성

**생성되는 설정:**
- `ACCOUNT`: 선택된 Google Cloud 계정
- `PROJECT_ID`: 선택된 프로젝트 ID
- `PROJECT_NUMBER`: 프로젝트 번호
- `NAME`: 프로젝트 이름
- `ORGANIZATION_ID`: 선택된 조직 ID (없으면 빈 값)
- `ORGANIZATION_NAME`: 조직 이름
- `CUSTOM_ROLE_NAME`: 자동 생성된 커스텀 역할 이름
- `CUSTOM_ORG_ROLE_NAME`: 자동 생성된 조직 커스텀 역할 이름

#### 2단계: 서비스 계정 생성

```bash
# 기본 서비스 계정 생성 (이름: project-sa)
./2_create_service_account.sh

# 또는 사용자 정의 이름으로 생성
./2_create_service_account.sh my-service-account
```

**실행 과정:**
- 필수 API 활성화 (`iam.googleapis.com`, `cloudresourcemanager.googleapis.com`)
- 서비스 계정 생성
- 생성된 서비스 계정 검증

**생성되는 리소스:**
- 서비스 계정: `[SA_NAME]@[PROJECT_ID].iam.gserviceaccount.com`
- 표시 이름: `[PROJECT_NAME] Project SA`
- 설명: `Service Account for [PROJECT_NAME] Project-level plugins`

#### 3단계: 커스텀 역할 생성

**3-1. 프로젝트 레벨 커스텀 역할 생성**

```bash
./3_1_create_custom_role_with_permissions.sh
```

**실행 과정:**
- `config/roles.json`에서 프로젝트 권한 목록 로드
- 사용자 확인 후 커스텀 역할 생성
- 생성된 역할 ID: `projects/[PROJECT_ID]/roles/[CUSTOM_ROLE_NAME]`

**포함되는 권한들:**
- BigQuery 관련 권한 (jobs, tables, datasets)
- Cloud Asset Inventory 권한
- Cloud Functions, Cloud SQL, Pub/Sub 권한
- Storage, Logging 권한
- 기타 리소스 관리 권한

**3-2. 조직 레벨 커스텀 역할 생성 (조직이 있는 경우)**

```bash
./3_2_create_custom_org_role_with_permissions.sh
```

**실행 과정:**
- `config/roles.json`에서 조직 권한 목록 로드
- 조직 레벨 커스텀 역할 생성
- 생성된 역할 ID: `organizations/[ORGANIZATION_ID]/roles/[CUSTOM_ORG_ROLE_NAME]`

**포함되는 권한들:**
- Resource Manager 권한 (folders, organizations, projects)
- 조직 및 폴더 조회 권한

#### 4단계: 권한 및 API 할당

**4-1. 프로젝트 레벨 권한 및 API 할당**

```bash
./4_1_assign_roles_and_apis.sh
```

**실행 과정:**
- 프로젝트 내 서비스 계정 목록 표시
- 사용자가 서비스 계정 선택
- `config/apis.json`에서 API 목록 로드 및 활성화
- 커스텀 역할 및 기본 역할 할당

**활성화되는 API들:**
- Cloud Resource Manager
- Cloud Identity
- IAM
- Logging
- Compute Engine
- Cloud SQL
- BigQuery
- Cloud Storage
- Pub/Sub
- Cloud Functions
- Recommender
- Cloud Asset Inventory
- Eventarc
- Cloud Billing
- Monitoring

**할당되는 역할들:**
- 커스텀 역할 (생성된 프로젝트 레벨 역할)
- `roles/recommender.viewer`
- `roles/compute.viewer`

**4-2. 조직 레벨 권한 및 API 할당 (조직이 있는 경우)**

```bash
./4_2_assing_org_roles_and_apis.sh
```

**실행 과정:**
- 조직 내 서비스 계정 목록 표시
- 사용자가 서비스 계정 선택
- 조직 레벨 커스텀 역할 할당
- 조직 레벨 API 활성화

### 설정 파일 설명

#### config/apis.json
활성화할 Google Cloud API 목록을 정의합니다.

```json
{
    "apis": [
        "cloudresourcemanager.googleapis.com",
        "iam.googleapis.com",
        "bigquery.googleapis.com",
        // ... 기타 API들
    ]
}
```

#### config/roles.json
커스텀 역할에 포함할 권한들을 정의합니다.

```json
{
    "project_permissions": [
        "bigquery.jobs.create",
        "bigquery.tables.get",
        // ... 프로젝트 레벨 권한들
    ],
    "project_roles": [
        "roles/recommender.viewer",
        "roles/compute.viewer"
    ],
    "org_permissions": [
        "resourcemanager.folders.get",
        "resourcemanager.organizations.get",
        // ... 조직 레벨 권한들
    ],
    "org_roles": []
}
```

### 완전한 실행 예시

```bash
# 1. 프로젝트 클론 및 디렉토리 이동
git clone <repository-url>
cd gcloud-service-account-manager-dev/scripts

# 2. 초기 설정 (계정, 조직, 프로젝트 선택)
./1_init.sh

# 3. 서비스 계정 생성
./2_create_service_account.sh my-sa

# 4. 커스텀 역할 생성
./3_1_create_custom_role_with_permissions.sh
./3_2_create_custom_org_role_with_permissions.sh

# 5. 권한 및 API 할당
./4_1_assign_roles_and_apis.sh
./4_2_assing_org_roles_and_apis.sh
```

### 주의사항

1. **사전 요구사항:**
   - Google Cloud 계정에 적절한 권한 필요
   - gcloud CLI가 설치되어 있어야 함
   - jq 도구가 설치되어 있어야 함

2. **권한 요구사항:**
   - 서비스 계정 생성 권한
   - 커스텀 역할 생성 권한
   - API 활성화 권한
   - IAM 권한 할당 권한

3. **조직 설정:**
   - 조직이 없는 경우 조직 관련 스크립트는 건너뛸 수 있음
   - 조직이 있는 경우 조직 관리자 권한 필요

4. **보안 고려사항:**
   - 생성된 서비스 계정의 키 파일은 안전하게 보관
   - 필요한 최소 권한만 부여하는 것을 권장
   - 정기적인 권한 검토 및 정리 필요

### 문제 해결

**일반적인 오류 및 해결 방법:**

1. **인증 오류:**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **권한 부족 오류:**
   - Google Cloud 콘솔에서 적절한 역할 할당 확인
   - 조직 관리자에게 권한 요청

3. **API 활성화 실패:**
   - API 활성화 권한 확인
   - 프로젝트 설정 확인

4. **서비스 계정 생성 실패:**
   - 서비스 계정 이름 중복 확인
   - IAM 권한 확인

### 결과 확인

모든 스크립트 실행 완료 후 다음 명령어로 결과를 확인할 수 있습니다:

```bash
# 서비스 계정 목록 확인
gcloud iam service-accounts list --project=[PROJECT_ID]

# 커스텀 역할 확인
gcloud iam roles list --project=[PROJECT_ID]

# 활성화된 API 확인
gcloud services list --enabled --project=[PROJECT_ID]

# 서비스 계정 권한 확인
gcloud projects get-iam-policy [PROJECT_ID] --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:[SA_EMAIL]"
```
