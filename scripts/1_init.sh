#!/bin/bash

echo "=== Google Cloud 인증 계정 선택 ==="
echo ""

# gcloud auth list 실행하여 계정 목록 가져오기
auth_list=$(gcloud auth list --format="table(ACCOUNT,ACTIVE)")

# 계정 목록을 배열로 변환
accounts=()
while IFS= read -r line; do
    # 헤더 라인 건너뛰기
    if [[ "$line" == "ACCOUNT"* ]]; then
        continue
    fi
    
    # 빈 라인 건너뛰기
    if [[ -z "$line" ]]; then
        continue
    fi
    
    # 계정 정보 파싱 (ACCOUNT ACTIVE 형식)
    if [[ $line =~ ^([^[:space:]]+)[[:space:]]+([*[:space:]]*)$ ]]; then
        account="${BASH_REMATCH[1]}"
        active="${BASH_REMATCH[2]}"
        if [[ -n "$account" ]]; then
            accounts+=("$account")
        fi
    fi
done <<< "$auth_list"

# 계정이 없으면 안내
if [ ${#accounts[@]} -eq 0 ]; then
    echo "인증된 계정이 없습니다."
    echo "다음 명령어로 로그인하세요:"
    echo "gcloud auth login"
    exit 1
fi

# 계정 목록 표시
echo "사용 가능한 계정 목록:"
echo ""

for i in "${!accounts[@]}"; do
    # 현재 활성 계정인지 확인
    current_account=$(gcloud config get-value account 2>/dev/null)
    if [[ "${accounts[$i]}" == "$current_account" ]]; then
        echo "  $((i+1)). ${accounts[$i]} (현재 활성)"
    else
        echo "  $((i+1)). ${accounts[$i]}"
    fi
done

echo ""
echo "선택할 계정 번호를 입력하세요 (1-${#accounts[@]}): "
read -r selection

# 입력 검증
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#accounts[@]} ]; then
    echo "잘못된 번호입니다. 1-${#accounts[@]} 사이의 숫자를 입력하세요."
    exit 1
fi

# 선택된 계정 인덱스 계산
selected_index=$((selection-1))
selected_account="${accounts[$selected_index]}"

# 계정 전환
echo ""
echo "계정을 전환합니다: $selected_account"
gcloud config set account "$selected_account"

# 전환 결과 확인
echo ""
echo "=== 계정 전환 완료 ==="
gcloud auth list

# 조직 ID 선택
echo ""
echo "=== Google Cloud 조직 ID 선택 ==="
echo ""

# 조직 목록 가져오기
organizations_list=$(gcloud organizations list --format="table(DISPLAY_NAME,ID)" 2>/dev/null)

# 조직 목록을 배열로 변환
organizations=()
organization_ids=()
while IFS= read -r line; do
    # 헤더 라인 건너뛰기
    if [[ "$line" == "DISPLAY_NAME"* ]]; then
        continue
    fi
    
    # 빈 라인 건너뛰기
    if [[ -z "$line" ]]; then
        continue
    fi
    
    # 조직 정보 파싱 (DISPLAY_NAME ID 형식)
    if [[ $line =~ ^([^[:space:]]+)[[:space:]]+([0-9]+)$ ]]; then
        org_name="${BASH_REMATCH[1]}"
        org_id="${BASH_REMATCH[2]}"
        if [[ -n "$org_id" ]]; then
            organizations+=("$org_name")
            organization_ids+=("$org_id")
        fi
    fi
done <<< "$organizations_list"

# 조직이 없으면 안내
if [ ${#organizations[@]} -eq 0 ]; then
    echo "접근 가능한 조직이 없습니다."
    echo "계정에 조직 접근 권한이 있는지 확인하세요."
    echo "조직이 없는 경우 빈 값을 입력하세요."
    selected_organization_id=""
    selected_organization_name=""
else
    # 조직 목록 표시
    echo "사용 가능한 조직 목록:"
    echo ""

    for i in "${!organizations[@]}"; do
        echo "  $((i+1)). ${organizations[$i]} (${organization_ids[$i]})"
    done

    echo ""
    echo "선택할 조직 번호를 입력하세요 (1-${#organizations[@]}) 또는 조직이 없는 경우 0을 입력하세요: "
    read -r org_selection

    # 입력 검증
    if ! [[ "$org_selection" =~ ^[0-9]+$ ]] || [ "$org_selection" -lt 0 ] || [ "$org_selection" -gt ${#organizations[@]} ]; then
        echo "잘못된 번호입니다. 0-${#organizations[@]} 사이의 숫자를 입력하세요."
        exit 1
    fi

    # 선택된 조직 인덱스 계산
    if [ "$org_selection" -eq 0 ]; then
        selected_organization_id=""
        selected_organization_name=""
        echo "조직을 선택하지 않았습니다."
    else
        selected_org_index=$((org_selection-1))
        selected_organization_name="${organizations[$selected_org_index]}"
        selected_organization_id="${organization_ids[$selected_org_index]}"
        echo "선택된 조직: $selected_organization_name ($selected_organization_id)"
    fi
fi

echo ""
echo "=== Google Cloud 프로젝트 선택 ==="
echo ""

# 프로젝트 목록 가져오기
projects_list=$(gcloud projects list --format="table(PROJECT_ID,NAME,PROJECT_NUMBER)")

# 프로젝트 목록을 배열로 변환
projects=()
project_ids=()
project_numbers=()
while IFS= read -r line; do
    # 헤더 라인 건너뛰기
    if [[ "$line" == "PROJECT_ID"* ]]; then
        continue
    fi
    
    # 빈 라인 건너뛰기
    if [[ -z "$line" ]]; then
        continue
    fi
    
    # 프로젝트 정보 파싱 (PROJECT_ID NAME PROJECT_NUMBER 형식)
    if [[ $line =~ ^([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+)$ ]]; then
        project_id="${BASH_REMATCH[1]}"
        project_name="${BASH_REMATCH[2]}"
        project_number="${BASH_REMATCH[3]}"
        if [[ -n "$project_id" ]]; then
            projects+=("$project_name")
            project_ids+=("$project_id")
            project_numbers+=("$project_number")
        fi
    fi
done <<< "$projects_list"

# 프로젝트가 없으면 안내
if [ ${#projects[@]} -eq 0 ]; then
    echo "접근 가능한 프로젝트가 없습니다."
    echo "계정에 프로젝트 접근 권한이 있는지 확인하세요."
    exit 1
fi

# 프로젝트 목록 표시
echo "사용 가능한 프로젝트 목록:"
echo ""

for i in "${!projects[@]}"; do
    # 현재 활성 프로젝트인지 확인
    current_project=$(gcloud config get-value project 2>/dev/null)
    if [[ "${project_ids[$i]}" == "$current_project" ]]; then
        echo "  $((i+1)). ${projects[$i]} (${project_ids[$i]}) (현재 활성)"
    else
        echo "  $((i+1)). ${projects[$i]} (${project_ids[$i]})"
    fi
done

echo ""
echo "선택할 프로젝트 번호를 입력하세요 (1-${#projects[@]}): "
read -r project_selection

# 입력 검증
if ! [[ "$project_selection" =~ ^[0-9]+$ ]] || [ "$project_selection" -lt 1 ] || [ "$project_selection" -gt ${#projects[@]} ]; then
    echo "잘못된 번호입니다. 1-${#projects[@]} 사이의 숫자를 입력하세요."
    exit 1
fi

# 선택된 프로젝트 인덱스 계산
selected_project_index=$((project_selection-1))
selected_project_name="${projects[$selected_project_index]}"
selected_project_id="${project_ids[$selected_project_index]}"
selected_project_number="${project_numbers[$selected_project_index]}"

# 프로젝트 전환
echo ""
echo "프로젝트를 전환합니다: $selected_project_name ($selected_project_id)"
gcloud config set project "$selected_project_id"

# 전환 결과 확인
echo ""
echo "=== 프로젝트 전환 완료 ==="
echo "현재 계정: $(gcloud config get-value account)"
echo "현재 프로젝트: $(gcloud config get-value project)"
echo ""
echo "=== 최종 상태 ==="
gcloud auth list
echo ""
gcloud projects list --limit=1

# config.env 파일 생성
echo ""
echo "=== config.env 파일 생성 ==="
config_path="../config.env"

cat > "$config_path" << EOF
# USER CONFIG
ACCOUNT=$selected_account

# PROJECT CONFIG
PROJECT_NUMBER=$selected_project_number
PROJECT_ID=$selected_project_id
NAME=$selected_project_name

# ORGANIZATION CONFIG
ORGANIZATION_ID=$selected_organization_id
ORGANIZATION_NAME=$selected_organization_name

EOF

echo "config.env 파일이 생성되었습니다: $config_path"
echo ""
echo "생성된 내용:"
cat "$config_path"
