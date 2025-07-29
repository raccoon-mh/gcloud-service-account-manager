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
# Load permissions from roles.json
# ==============================================================================

# Load project permissions from JSON file
PROJECT_PERMISSIONS=($(jq -r '.project_permissions[]' "$CONFIG_ROLES_FILE"))

echo "Loaded ${#PROJECT_PERMISSIONS[@]} project permissions from roles.json"
echo ""

# ==============================================================================
# Create custom role with permissions
# ==============================================================================

echo "Creating custom role: $CUSTOM_ROLE_NAME"
echo "Project: $PROJECT_ID"
echo "Description: $CUSTOM_ROLE_DESCRIPTION"
echo ""

# ==============================================================================
# User confirmation
# ==============================================================================

echo "Please review the following configuration:"
echo "=================================================="
echo "Custom Role Name: $CUSTOM_ROLE_NAME"
echo "Project ID: $PROJECT_ID"
echo "Project Name: $NAME"
echo "Description: $CUSTOM_ROLE_DESCRIPTION"
echo "Permissions Count: ${#PROJECT_PERMISSIONS[@]}"
echo "=================================================="
echo ""

# Show first 10 permissions as preview
echo "Permissions preview (showing first 10):"
for i in "${!PROJECT_PERMISSIONS[@]}"; do
    if [ $i -lt 10 ]; then
        echo "  - ${PROJECT_PERMISSIONS[$i]}"
    else
        echo "  ... and ${#PROJECT_PERMISSIONS[@]} more permissions"
        break
    fi
done
echo ""

# Ask for user confirmation
read -p "Do you want to proceed with creating this custom role? (y/n): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

echo ""
echo "Proceeding with custom role creation..."
echo ""

echo "Creating custom role with permissions..."

# Use jq to create the permissions string directly from JSON
PERMISSIONS_STRING=$(jq -r '.project_permissions | join(",")' "$CONFIG_ROLES_FILE")

gcloud iam roles create $CUSTOM_ROLE_NAME \
    --project=$PROJECT_ID \
    --title=$CUSTOM_ROLE_NAME \
    --description="$CUSTOM_ROLE_DESCRIPTION" \
    --permissions="$PERMISSIONS_STRING"

if [ $? -eq 0 ]; then
    echo ""
    echo "Custom role created successfully: $CUSTOM_ROLE_NAME"
    echo "Permissions count: ${#PROJECT_PERMISSIONS[@]}"
else
    echo ""
    echo "Failed to create custom role: $CUSTOM_ROLE_NAME"
    exit 1
fi