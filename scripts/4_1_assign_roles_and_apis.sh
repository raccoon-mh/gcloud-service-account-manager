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
echo "  Project ID: $PROJECT_ID"
echo "  Project Name: $NAME"
echo ""

# ==============================================================================
# Load configuration from files
# ==============================================================================

# Load APIs from JSON file
APIS_TO_ENABLE=($(jq -r '.apis[]' "$CONFIG_APIS_FILE"))

# Load role
ROLE_ID="projects/$PROJECT_ID/roles/$CUSTOM_ROLE_NAME"

echo "Loaded configuration:"
echo "  APIs to enable: ${#APIS_TO_ENABLE[@]} APIs"
echo "  Role to assign: $ROLE_ID"
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
# for account in "${SERVICE_ACCOUNT_LIST[@]}"; do
#     echo "  - $account"
# done
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
echo "Project: $PROJECT_ID"
echo ""

# ==============================================================================
# Enable APIs
# ==============================================================================

echo "=================================================="
echo "Enabling APIs for project: $PROJECT_ID"
echo "=================================================="

for api in "${APIS_TO_ENABLE[@]}"; do
    echo "  - Enabling $api..."
    gcloud services enable "$api" --project="$PROJECT_ID"
    if [ $? -ne 0 ]; then
        echo "Failed to enable API: $api"
        exit 1
    fi
done

echo ""
echo "All APIs enabled successfully."
echo ""

# ==============================================================================
# Assign roles
# ==============================================================================

echo "=================================================="
echo "Assigning roles to service account: $SELECTED_ACCOUNT"
echo "=================================================="


echo "  - Assigning $ROLE_ID..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SELECTED_ACCOUNT" \
    --role="$ROLE_ID" \
    --condition=None > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to assign role: $ROLE_ID"
    exit 1
fi

echo ""
echo "All roles assigned successfully."
echo ""

# ==============================================================================
# Summary
# ==============================================================================

echo "=================================================="
echo "Operation completed successfully!"
echo "=================================================="
echo "Service Account: $SELECTED_ACCOUNT"
echo "Project: $PROJECT_ID"
echo "APIs Enabled: ${#APIS_TO_ENABLE[@]}"
echo "Roles Assigned: $ROLE_ID"
echo "=================================================="
