#!/bin/bash

echo "=== Google Cloud Authentication Account Check ==="
echo ""

# 현재 활성 계정 확인
current_account=$(gcloud config get-value account 2>/dev/null)

# gcloud auth list 실행하여 계정 목록 가져오기 (웹 콘솔 호환)
auth_list=$(gcloud auth list --format="value(ACCOUNT)")

# 웹 콘솔과 일반 터미널 모두 지원하는 방식으로 파싱
accounts=()
while IFS= read -r line; do
    # 빈 라인이나 헤더 라인 건너뛰기
    if [[ -z "$line" ]] || [[ "$line" == "ACTIVE:"* ]] || [[ "$line" == "ACCOUNT:"* ]]; then
        continue
    fi
    
    # 유효한 이메일 주소인지 확인
    if [[ "$line" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        accounts+=("$line")
    fi
done <<< "$auth_list"

# 계정이 없으면 안내
if [ ${#accounts[@]} -eq 0 ]; then
    echo "No authenticated accounts found."
    echo "Please login with the following command:"
    echo "gcloud auth login"
    exit 1
fi

# 현재 활성 계정이 있고, 인증된 계정 목록에 있는지 확인
if [[ -n "$current_account" ]]; then
    account_found=false
    for account in "${accounts[@]}"; do
        if [[ "$account" == "$current_account" ]]; then
            account_found=true
            break
        fi
    done
    
    if [[ "$account_found" == true ]]; then
        echo "Current active account found: $current_account"
        echo "Do you want to use this account? (y/n): "
        read -r use_current_account
        
        if [[ "$use_current_account" =~ ^[Yy]$ ]]; then
            selected_account="$current_account"
            echo "Using current account: $selected_account"
        else
            # 계정 선택 프로세스 진행
            echo ""
            echo "Available account list:"
            echo ""

            for i in "${!accounts[@]}"; do
                if [[ "${accounts[$i]}" == "$current_account" ]]; then
                    echo "  $((i+1)). ${accounts[$i]} (current active)"
                else
                    echo "  $((i+1)). ${accounts[$i]}"
                fi
            done

            echo ""
            echo "Enter the account number to select (1-${#accounts[@]}): "
            read -r selection

            # 입력 검증
            if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#accounts[@]} ]; then
                echo "Invalid number. Please enter a number between 1-${#accounts[@]}."
                exit 1
            fi

            # 선택된 계정 인덱스 계산
            selected_index=$((selection-1))
            selected_account="${accounts[$selected_index]}"

            # 계정 전환
            echo ""
            echo "Switching to account: $selected_account"
            gcloud config set account "$selected_account"
        fi
    else
        echo "Current configured account ($current_account) is not in the authenticated accounts list."
        echo "Please select an account."
        echo ""
        echo "Available account list:"
        echo ""

        for i in "${!accounts[@]}"; do
            echo "  $((i+1)). ${accounts[$i]}"
        done

        echo ""
        echo "Enter the account number to select (1-${#accounts[@]}): "
        read -r selection

        # 입력 검증
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#accounts[@]} ]; then
            echo "Invalid number. Please enter a number between 1-${#accounts[@]}."
            exit 1
        fi

        # 선택된 계정 인덱스 계산
        selected_index=$((selection-1))
        selected_account="${accounts[$selected_index]}"

        # 계정 전환
        echo ""
        echo "Switching to account: $selected_account"
        gcloud config set account "$selected_account"
    fi
else
    # 현재 활성 계정이 없는 경우
    echo "No current active account found."
    echo "Please select an account."
    echo ""
    echo "Available account list:"
    echo ""

    for i in "${!accounts[@]}"; do
        echo "  $((i+1)). ${accounts[$i]}"
    done

    echo ""
    echo "Enter the account number to select (1-${#accounts[@]}): "
    read -r selection

    # 입력 검증
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#accounts[@]} ]; then
        echo "Invalid number. Please enter a number between 1-${#accounts[@]}."
        exit 1
    fi

    # 선택된 계정 인덱스 계산
    selected_index=$((selection-1))
    selected_account="${accounts[$selected_index]}"

    # 계정 전환
    echo ""
    echo "Switching to account: $selected_account"
    gcloud config set account "$selected_account"
fi

# 계정 확인
echo ""
echo "=== Account Configuration Complete ==="
echo "Selected account: $selected_account"
gcloud auth list

# 조직 ID 선택
echo ""
echo "=== Google Cloud Organization ID Selection ==="
echo ""

# 조직 목록 가져오기 (웹 콘솔 호환)
organizations=()
organization_ids=()

# 조직 이름과 ID를 별도로 가져오기
org_names=($(gcloud organizations list --format="value(DISPLAY_NAME)" 2>/dev/null))
org_ids=($(gcloud organizations list --format="value(ID)" 2>/dev/null))

# 배열에 추가
for i in "${!org_names[@]}"; do
    if [[ -n "${org_names[$i]}" && -n "${org_ids[$i]}" ]]; then
        organizations+=("${org_names[$i]}")
        organization_ids+=("${org_ids[$i]}")
    fi
done

# 조직이 없으면 안내
if [ ${#organizations[@]} -eq 0 ]; then
    echo "No accessible organizations found."
    echo "Please check if your account has organization access permissions."
    echo "If no organization exists, leave empty."
    selected_organization_id=""
    selected_organization_name=""
else
    # 조직 목록 표시
    echo "Available organization list:"
    echo ""

    for i in "${!organizations[@]}"; do
        echo "  $((i+1)). ${organizations[$i]} (${organization_ids[$i]})"
    done

    echo ""
    echo "Enter the organization number to select (1-${#organizations[@]}) or enter 0 if no organization: "
    read -r org_selection

    # 입력 검증
    if ! [[ "$org_selection" =~ ^[0-9]+$ ]] || [ "$org_selection" -lt 0 ] || [ "$org_selection" -gt ${#organizations[@]} ]; then
        echo "Invalid number. Please enter a number between 0-${#organizations[@]}."
        exit 1
    fi

    # 선택된 조직 인덱스 계산
    if [ "$org_selection" -eq 0 ]; then
        selected_organization_id=""
        selected_organization_name=""
        echo "No organization selected."
    else
        selected_org_index=$((org_selection-1))
        selected_organization_name="${organizations[$selected_org_index]}"
        selected_organization_id="${organization_ids[$selected_org_index]}"
        echo "Selected organization: $selected_organization_name ($selected_organization_id)"
    fi
fi

echo ""
echo "=== Google Cloud Project Selection ==="
echo ""

# 프로젝트 목록 가져오기 (조직 내의 모든 프로젝트 포함)
echo "Fetching all accessible projects..."

if [[ -n "$selected_organization_id" ]]; then
    echo "Searching for all projects in organization: $selected_organization_name ($selected_organization_id)"
    
    # 먼저 조직 직접 하위의 프로젝트들을 가져오기
    projects_list=$(gcloud projects list --filter="parent.id=$selected_organization_id" --format="value(PROJECT_ID,NAME,PROJECT_NUMBER)" --sort-by=NAME)
    
    # 웹 콘솔 형식에 맞게 파싱
    if [[ -n "$projects_list" && "$projects_list" != *"Listed 0 items"* ]]; then
        echo "Found projects directly under organization:"
        PARSED_PROJECTS=""
        project_count=0
        
        while IFS=$'\t' read -r project_id project_name project_number; do
            if [[ -n "$project_id" && "$project_id" != "PROJECT_ID" ]]; then
                project_count=$((project_count + 1))
                echo "  - $project_name ($project_id)"
                PARSED_PROJECTS="$PARSED_PROJECTS"$'\n'"$project_id $project_name $project_number"
            fi
        done <<< "$projects_list"
        
        echo "  Total projects under organization: $project_count projects"
        projects_list="$PARSED_PROJECTS"
    fi
    
    # 프로젝트가 없으면 모든 접근 가능한 프로젝트에서 조직에 속한 것들 찾기
    if [ -z "$projects_list" ] || [[ "$projects_list" == *"Listed 0 items"* ]]; then
        echo "No projects found with parent filter, trying alternative methods..."
        projects_list=$(gcloud projects list --format="table(PROJECT_ID,NAME,PROJECT_NUMBER)" --filter="lifecycleState:ACTIVE" --sort-by=NAME)
    fi
    
    # 폴더 내의 프로젝트들도 추가 (재귀적으로 모든 폴더 검색)
    echo "Searching for projects in all folders under organization (including nested folders)..."
    
    # 재귀적으로 모든 폴더를 찾는 함수
    find_all_folders() {
        local parent_id="$1"
        local depth="$2"
        local indent=""
        
        # 들여쓰기 생성
        for ((i=0; i<depth; i++)); do
            indent="$indent  "
        done
        
        # 현재 레벨의 폴더들 찾기
        local folders=$(gcloud resource-manager folders list --folder="$parent_id" --format="value(name)" 2>/dev/null)
        
        if [ ! -z "$folders" ]; then
            echo "${indent}Found folders at depth $depth:"
            for folder in $folders; do
                echo "${indent}  - Folder: $folder"
                
                # 이 폴더 내의 프로젝트들 찾기
                local folder_projects=$(gcloud projects list --filter="parent.id=$folder" --format="value(PROJECT_ID,NAME,PROJECT_NUMBER)" 2>/dev/null)
                if [ ! -z "$folder_projects" ] && [[ "$folder_projects" != *"Listed 0 items"* ]]; then
                    # 프로젝트 개수 계산
                    local project_count=0
                    local folder_projects_data=""
                    
                    while IFS=$'\t' read -r project_id project_name project_number; do
                        if [[ -n "$project_id" && "$project_id" != "PROJECT_ID" ]]; then
                            project_count=$((project_count + 1))
                            echo "${indent}      - $project_name ($project_id)"
                            folder_projects_data="$folder_projects_data"$'\n'"$project_id $project_name $project_number"
                        fi
                    done <<< "$folder_projects"
                    
                    echo "${indent}    Projects in folder: $project_count projects"
                    
                    # projects_list에 폴더 프로젝트들 추가
                    if [[ -n "$folder_projects_data" ]]; then
                        projects_list="$projects_list"$'\n'"$folder_projects_data"
                    fi
                fi
                
                # 재귀적으로 하위 폴더들 검색
                find_all_folders "$folder" $((depth + 1))
            done
        fi
    }
    
    # 조직 바로 아래의 폴더들부터 시작
    ALL_FOLDERS=$(gcloud resource-manager folders list --organization="$selected_organization_id" --format="value(name)" 2>/dev/null)
    
    if [ ! -z "$ALL_FOLDERS" ]; then
        echo "Found folders in organization:"
        for folder in $ALL_FOLDERS; do
            echo "  - Folder: $folder"
            
            # 이 폴더 내의 프로젝트들 찾기
            FOLDER_PROJECTS=$(gcloud projects list --filter="parent.id=$folder" --format="value(PROJECT_ID,NAME,PROJECT_NUMBER)" 2>/dev/null)
            if [ ! -z "$FOLDER_PROJECTS" ] && [[ "$FOLDER_PROJECTS" != *"Listed 0 items"* ]]; then
                # 프로젝트 개수 계산
                project_count=0
                FOLDER_PROJECTS_DATA=""
                
                while IFS=$'\t' read -r project_id project_name project_number; do
                    if [[ -n "$project_id" && "$project_id" != "PROJECT_ID" ]]; then
                        project_count=$((project_count + 1))
                        echo "      - $project_name ($project_id)"
                        FOLDER_PROJECTS_DATA="$FOLDER_PROJECTS_DATA"$'\n'"$project_id $project_name $project_number"
                    fi
                done <<< "$FOLDER_PROJECTS"
                
                echo "    Projects in folder: $project_count projects"
                
                # projects_list에 폴더 프로젝트들 추가
                if [[ -n "$FOLDER_PROJECTS_DATA" ]]; then
                    projects_list="$projects_list"$'\n'"$FOLDER_PROJECTS_DATA"
                fi
            fi
            
            # 재귀적으로 하위 폴더들 검색
            find_all_folders "$folder" 1
        done
    fi
    
    # 중복 제거 및 정렬 (PROJECT_ID 기준)
    if [[ -n "$projects_list" ]]; then
        echo "Removing duplicates and sorting projects..."
        # PROJECT_ID를 기준으로 중복 제거
        projects_list=$(echo "$projects_list" | awk '!seen[$1]++' | sort -k2)
    fi
else
    # 조직이 선택되지 않은 경우, 사용자가 직접 접근 가능한 프로젝트만 가져오기
    projects_list=$(gcloud projects list --format="value(PROJECT_ID,NAME,PROJECT_NUMBER)" --filter="lifecycleState:ACTIVE" --sort-by=NAME)
    
    # 웹 콘솔 형식에 맞게 파싱
    if [[ -n "$projects_list" ]]; then
        PARSED_PROJECTS=""
        project_count=0
        
        while IFS=$'\t' read -r project_id project_name project_number; do
            if [[ -n "$project_id" && "$project_id" != "PROJECT_ID" ]]; then
                project_count=$((project_count + 1))
                PARSED_PROJECTS="$PARSED_PROJECTS"$'\n'"$project_id $project_name $project_number"
            fi
        done <<< "$projects_list"
        
        echo "Found $project_count accessible projects"
        projects_list="$PARSED_PROJECTS"
    fi
fi

# 프로젝트 목록을 배열로 변환
projects=()
project_ids=()
project_numbers=()

# awk를 사용하여 안정적으로 파싱 (프로젝트 이름에 공백이 있어도 올바르게 파싱)
while IFS=$'\t' read -r project_id project_name project_number; do
    if [[ -n "$project_id" && "$project_id" != "PROJECT_ID" ]]; then
        projects+=("$project_name")
        project_ids+=("$project_id")
        project_numbers+=("$project_number")
    fi
done < <(echo "$projects_list" | awk '{
    # 첫 번째 필드는 PROJECT_ID
    project_id = $1
    # 마지막 필드는 PROJECT_NUMBER
    project_number = $NF
    # 중간의 모든 필드가 PROJECT_NAME (공백 포함)
    project_name = ""
    for (i = 2; i < NF; i++) {
        if (i > 2) project_name = project_name " "
        project_name = project_name $i
    }
    print project_id "\t" project_name "\t" project_number
}')

# 프로젝트가 없으면 안내
if [ ${#projects[@]} -eq 0 ]; then
    echo "No accessible projects found."
    echo "Please check if your account has project access permissions."
    exit 1
fi

# 프로젝트 목록 표시
echo "Available project list (${#projects[@]} projects found):"
echo ""

for i in "${!projects[@]}"; do
    # 현재 활성 프로젝트인지 확인
    current_project=$(gcloud config get-value project 2>/dev/null)
    if [[ "${project_ids[$i]}" == "$current_project" ]]; then
        echo "  $((i+1)). ${projects[$i]} (${project_ids[$i]}) (current active)"
    else
        echo "  $((i+1)). ${projects[$i]} (${project_ids[$i]})"
    fi
done

echo ""
echo "Enter the project number to select (1-${#projects[@]}): "
read -r project_selection

# 입력 검증
if ! [[ "$project_selection" =~ ^[0-9]+$ ]] || [ "$project_selection" -lt 1 ] || [ "$project_selection" -gt ${#projects[@]} ]; then
    echo "Invalid number. Please enter a number between 1-${#projects[@]}."
    exit 1
fi

# 선택된 프로젝트 인덱스 계산
selected_project_index=$((project_selection-1))
selected_project_name="${projects[$selected_project_index]}"
selected_project_id="${project_ids[$selected_project_index]}"
selected_project_number="${project_numbers[$selected_project_index]}"

# 프로젝트 전환
echo ""
echo "Switching to project: $selected_project_name ($selected_project_id)"
gcloud config set project "$selected_project_id"

# 전환 결과 확인
echo ""
echo "=== Project Switch Complete ==="
echo "Current account: $(gcloud config get-value account)"
echo "Current project: $(gcloud config get-value project)"
echo ""
echo "=== Final Status ==="
gcloud auth list
echo ""
gcloud projects list --limit=1

# config.env 파일 생성
echo ""
echo "=== Creating config.env file ==="
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

# CUSTOM ROLE CONFIG
CUSTOM_ROLE_NAME=$(echo ${selected_project_id} | tr '-' '_')_role
CUSTOM_ORG_ROLE_NAME=$(echo ${selected_project_id} | tr '-' '_')_role
CUSTOM_ROLE_DESCRIPTION="Custom role for $selected_project_name"

EOF

echo "config.env file has been created: $config_path"
echo ""
echo "Generated content:"
cat "$config_path"
