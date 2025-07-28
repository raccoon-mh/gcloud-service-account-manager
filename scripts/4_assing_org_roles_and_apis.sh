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

# Load organization roles from JSON file
ORG_ROLES=($(jq -r '.org_roles[].role' "$CONFIG_ROLES_FILE"))

echo "Loaded configuration:"
echo "  APIs to enable: ${#APIS_TO_ENABLE[@]} APIs"
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

# Get all projects in the organization
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

# Get all folders in the organization and their projects
echo "Searching for projects in all folders under organization..."
ALL_FOLDERS=$(gcloud resource-manager folders list --organization="$ORGANIZATION_ID" --format="value(name)" 2>/dev/null)

if [ ! -z "$ALL_FOLDERS" ]; then
    echo "Found folders in organization:"
    for folder in $ALL_FOLDERS; do
        echo "  - Folder: $folder"
        # Get projects in this folder
        FOLDER_PROJECTS=$(gcloud projects list --filter="parent.id=$folder" --format="value(projectId)" 2>/dev/null)
        if [ ! -z "$FOLDER_PROJECTS" ]; then
            echo "    Projects in folder:"
            for project in $FOLDER_PROJECTS; do
                echo "      - $project"
                PROJECTS_IN_ORG="$PROJECTS_IN_ORG $project"
            done
        fi
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

for role in "${ORG_ROLES[@]}"; do
    echo "  - Assigning $role..."
    gcloud organizations add-iam-policy-binding "$ORGANIZATION_ID" \
        --member="serviceAccount:$SELECTED_ACCOUNT" \
        --role="$role" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to assign organization role: $role"
        exit 1
    fi
done

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
echo "Organization Roles Assigned: ${#ORG_ROLES[@]}"
echo "=================================================="
