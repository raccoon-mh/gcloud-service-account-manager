#!/bin/bash

# ==============================================================================
# Configuration and setup
# ==============================================================================

# Absolute paths for configuration files
CONFIG_APIS_FILE="../config/apis.json"
CONFIG_ROLES_FILE="../config/roles.json"
CONFIG_ENV_FILE="../config.env"

# Check if configuration files exist
if [ ! -f "$CONFIG_APIS_FILE" ]; then
    echo "API configuration file not found: $CONFIG_APIS_FILE"
    exit 1
fi

if [ ! -f "$CONFIG_ROLES_FILE" ]; then
    echo "Roles configuration file not found: $CONFIG_ROLES_FILE"
    exit 1
fi

if [ ! -f "$CONFIG_ENV_FILE" ]; then
    echo "Environment configuration file not found: $CONFIG_ENV_FILE"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq command is required but not installed."
    echo "Ubuntu/Debian: sudo apt-get install jq"
    echo "CentOS/RHEL: sudo yum install jq"
    echo "macOS: brew install jq"
    exit 1
fi

# Load config.env file
source "$CONFIG_ENV_FILE"

echo "Configuration loaded:"
echo "  Organization ID: $ORGANIZATION_ID"
echo "  Organization Name: $ORGANIZATION_NAME"
echo "  Project ID: $PROJECT_ID"
echo "  Project Name: $NAME"
echo ""

# ==============================================================================
# Load configuration from files
# ==============================================================================

# Load APIs from JSON file
APIS_TO_ENABLE=($(jq -r '.apis[]' "$CONFIG_APIS_FILE"))

# Load custom organization role
ROLE_ID="organizations/$ORGANIZATION_ID/roles/$CUSTOM_ORG_ROLE_NAME"

# Load organization roles from JSON file
ORG_ROLES=($(jq -r '.org_roles[]' "$CONFIG_ROLES_FILE"))

echo "Loaded configuration:"
echo "  APIs to enable: ${#APIS_TO_ENABLE[@]} APIs"
echo "  Custom organization role to assign: $ROLE_ID"
echo "  Organization roles to assign: ${#ORG_ROLES[@]} roles"
echo "" 

# ==============================================================================
# List service accounts in configured project
# ==============================================================================

echo "=================================================="
echo "Service Accounts in Project: $PROJECT_ID"
echo "=================================================="

# Switch to the configured project
echo "Switching to project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"
if [ $? -ne 0 ]; then
    echo "Failed to switch to project: $PROJECT_ID"
    exit 1
fi

# Get service accounts for the configured project
SERVICE_ACCOUNT_LIST=($(gcloud iam service-accounts list --project="$PROJECT_ID" --format="value(email)" 2>/dev/null))

if [ ${#SERVICE_ACCOUNT_LIST[@]} -eq 0 ]; then
    echo "No service accounts found in project: $PROJECT_ID"
    exit 1
fi

echo "Found ${#SERVICE_ACCOUNT_LIST[@]} service account(s):"
echo ""

# ==============================================================================
# User selection
# ==============================================================================

# Display numbered list
for i in "${!SERVICE_ACCOUNT_LIST[@]}"; do
    account="${SERVICE_ACCOUNT_LIST[$i]}"
    echo "$((i+1)). $account"
done

echo ""

# Get user selection
read -p "Select service account (1-${#SERVICE_ACCOUNT_LIST[@]}): " selection

# Validate selection
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#SERVICE_ACCOUNT_LIST[@]} ]; then
    echo "Invalid selection. Please enter a number between 1 and ${#SERVICE_ACCOUNT_LIST[@]}."
    exit 1
fi

# Get selected service account
SELECTED_INDEX=$((selection-1))
SELECTED_ACCOUNT="${SERVICE_ACCOUNT_LIST[$SELECTED_INDEX]}"

echo ""
echo "Selected: $SELECTED_ACCOUNT"
echo "Organization: $ORGANIZATION_NAME ($ORGANIZATION_ID)"
echo ""

# ==============================================================================
# Enable APIs for all projects in organization
# ==============================================================================

echo "=================================================="
echo "Enabling APIs for all projects in organization: $ORGANIZATION_NAME"
echo "=================================================="

# Get all projects in the organization (including nested folders)
echo "Searching for all projects in organization: $ORGANIZATION_NAME ($ORGANIZATION_ID)"

# First, try to get projects directly under the organization
PROJECTS_IN_ORG=$(gcloud projects list --filter="parent.id=$ORGANIZATION_ID" --format="value(projectId)")

# If no projects found, try alternative methods
if [ -z "$PROJECTS_IN_ORG" ]; then
    echo "No projects found with parent filter, trying alternative methods..."
    
    # Get all projects and filter by organization
    ALL_PROJECTS=$(gcloud projects list --format="value(projectId)")
    PROJECTS_IN_ORG=""
    
    for project in $ALL_PROJECTS; do
        # Get project details to check if it belongs to our organization
        PROJECT_ORG=$(gcloud projects describe "$project" --format="value(parent.id)" 2>/dev/null)
        if [ "$PROJECT_ORG" = "$ORGANIZATION_ID" ]; then
            PROJECTS_IN_ORG="$PROJECTS_IN_ORG $project"
        fi
    done
fi

# If still no projects found, try getting all projects and check their organization
if [ -z "$PROJECTS_IN_ORG" ]; then
    echo "Still no projects found, getting all projects..."
    PROJECTS_IN_ORG=$(gcloud projects list --format="value(projectId)")
fi

# 재귀적으로 모든 폴더를 찾는 함수
find_all_folders_recursive() {
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
            local folder_projects=$(gcloud projects list --filter="parent.id=$folder" --format="value(projectId)" 2>/dev/null)
            if [ ! -z "$folder_projects" ]; then
                echo "${indent}    Projects in folder: $folder"
                for project in $folder_projects; do
                    echo "${indent}      - $project"
                    PROJECTS_IN_ORG="$PROJECTS_IN_ORG $project"
                done
            fi
            
            # 재귀적으로 하위 폴더들 검색
            find_all_folders_recursive "$folder" $((depth + 1))
        done
    fi
}

# Get all folders in the organization and their projects (including nested folders)
echo "Searching for projects in all folders under organization (including nested folders)..."
ALL_FOLDERS=$(gcloud resource-manager folders list --organization="$ORGANIZATION_ID" --format="value(name)" 2>/dev/null)

if [ ! -z "$ALL_FOLDERS" ]; then
    echo "Found folders in organization:"
    for folder in $ALL_FOLDERS; do
        echo "  - Folder: $folder"
        
        # 이 폴더 내의 프로젝트들 찾기
        FOLDER_PROJECTS=$(gcloud projects list --filter="parent.id=$folder" --format="value(projectId)" 2>/dev/null)
        if [ ! -z "$FOLDER_PROJECTS" ]; then
            echo "    Projects in folder:"
            for project in $FOLDER_PROJECTS; do
                echo "      - $project"
                PROJECTS_IN_ORG="$PROJECTS_IN_ORG $project"
            done
        fi
        
        # 재귀적으로 하위 폴더들 검색
        find_all_folders_recursive "$folder" 1
    done
fi

# Remove duplicates and clean up the list
PROJECTS_IN_ORG=$(echo $PROJECTS_IN_ORG | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [ -z "$PROJECTS_IN_ORG" ]; then
    echo "No projects found in organization: $ORGANIZATION_NAME"
    exit 1
fi

echo "Found projects in organization:"
for project in $PROJECTS_IN_ORG; do
    echo "  - $project"
done
echo ""

# Enable APIs for each project
for project in $PROJECTS_IN_ORG; do
    echo "Enabling APIs for project: $project"
    for api in "${APIS_TO_ENABLE[@]}"; do
        echo "  - Enabling $api..."
        gcloud services enable "$api" --project="$project" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to enable API: $api in project: $project"
            # Continue with other projects instead of exiting
        fi
    done
    echo "  APIs enabled for project: $project"
    echo ""
done

echo ""
echo "API enabling completed for all projects."
echo ""

# ==============================================================================
# Assign organization roles
# ==============================================================================

echo "=================================================="
echo "Assigning organization roles to service account: $SELECTED_ACCOUNT"
echo "=================================================="

# Assign custom organization role
echo "  - Assigning custom organization role: $ROLE_ID..."
gcloud organizations add-iam-policy-binding "$ORGANIZATION_ID" \
    --member="serviceAccount:$SELECTED_ACCOUNT" \
    --role="$ROLE_ID" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to assign custom organization role: $ROLE_ID"
    exit 1
fi

# Assign organization roles from roles.json
if [ ${#ORG_ROLES[@]} -gt 0 ]; then
    echo "  - Assigning organization roles from roles.json..."
    for role in "${ORG_ROLES[@]}"; do
        echo "    - Assigning role: $role..."
        gcloud organizations add-iam-policy-binding "$ORGANIZATION_ID" \
            --member="serviceAccount:$SELECTED_ACCOUNT" \
            --role="$role" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to assign organization role: $role"
            exit 1
        fi
    done
else
    echo "  - No organization roles found in roles.json"
fi

echo ""
echo "All organization roles assigned successfully."
echo ""

# ==============================================================================
# Summary
# ==============================================================================

echo "=================================================="
echo "Operation completed successfully!"
echo "=================================================="
echo "Service Account: $SELECTED_ACCOUNT"
echo "Organization: $ORGANIZATION_NAME ($ORGANIZATION_ID)"
echo "Projects Processed: $(echo $PROJECTS_IN_ORG | wc -w)"
echo "APIs Enabled: ${#APIS_TO_ENABLE[@]}"
echo "Custom Organization Role Assigned: $ROLE_ID"
echo "Organization Roles Assigned: ${#ORG_ROLES[@]}"
if [ ${#ORG_ROLES[@]} -gt 0 ]; then
    for role in "${ORG_ROLES[@]}"; do
        echo "  - $role"
    done
fi
echo "=================================================="
