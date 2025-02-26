#!/bin/bash

# Function to download and install Terraform
install_terraform() {
    echo "Terraform not found. Installing..."
    terraform_url="https://releases.hashicorp.com/terraform/1.10.5/terraform_1.10.5_linux_amd64.zip"
    terraform_zip="/tmp/terraform.zip"
    if [ ! -f "$terraform_zip" ]; then
        wget -O "$terraform_zip" "$terraform_url"
    else
        echo "Terraform zip file already downloaded."
    fi
    unzip -o "$terraform_zip" -d /usr/local/bin
    chmod +x /usr/local/bin/terraform
    rm "$terraform_zip"
}

# Function to download and install Azure CLI
install_azure_cli() {
    echo "Azure CLI not found. Installing..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

# Function to install jq
install_jq() {
    echo "jq not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y jq
}

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    install_terraform
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    install_azure_cli
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    install_jq
fi

# Check if already logged in to Azure
account_info=$(az account show -o json 2>&1)
if [[ "$account_info" != *"Please run 'az login'"* ]]; then
    echo "Already logged in to Azure."
else
    # Log in to Azure with tenant ID
    tenant_id="daf25b37-838d-4e08-896b-ac9f645720f8"
    echo "Logging in to Azure tenant $tenant_id..."
    az login --tenant "$tenant_id"
fi

# Set the subscription ID
subscription_id=$(az account show --query "id" -o tsv)
echo "Using subscription ID: $subscription_id"

# Create a Service Principal
echo "Creating a Service Principal..."
sp=$(az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$subscription_id" --query "{ client_id: appId, client_secret: password, tenant_id: tenant }" -o json)

# Output environment variables for Terraform
echo "Setting environment variables for Terraform..."
export ARM_CLIENT_ID=$(echo "$sp" | jq -r '.client_id')
export ARM_CLIENT_SECRET=$(echo "$sp" | jq -r '.client_secret')
export ARM_SUBSCRIPTION_ID="$subscription_id"
export ARM_TENANT_ID=$(echo "$sp" | jq -r '.tenant_id')

echo "Environment variables set. You can now use Terraform to deploy to Azure."

# Ensure the state directory and files are properly set up
if [ ! -d ".terraform" ]; then
    echo "Creating .terraform directory..."
    mkdir -p ".terraform"
fi

# Ensure the state file is properly initialized with valid JSON
if [ ! -f "terraform.tfstate" ]; then
    echo "Creating initial state file..."
    echo '{"version": 4, "terraform_version": "1.10.5", "serial": 0, "lineage": "", "outputs": {}, "resources": []}' > "terraform.tfstate"
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Run Terraform plan with debug logging
echo "Running Terraform plan with debug logging..."
export TF_LOG="DEBUG"
terraform plan
