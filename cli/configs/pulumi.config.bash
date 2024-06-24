
source $(pwd)/cli/shared.bash

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project_name)
            project_name="$2"
            shift 2
            ;;

        --gcp_project_id)
            gcp_project_id="$2"
            shift 2
            ;;
        --pulumi_dir)
            pulumi_dir="$2"
            shift 2
            ;;
        --original_dir)
            original_dir="$2"
            shift 2
            ;;
        --gcp_pulumi_service_account_key_path)
           gcp_pulumi_service_account_key_path="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done
#

cd "$pulumi_dir"
# Install go packages, assuming go.mod file is present in the directory
go mod tidy



echo "Setting up gcp:credentials"
pulumi config set gcp:credentials "$gcp_pulumi_service_account_key_path"

echo "Setting up gcp:project"
# Set the project Id
pulumi config set gcp:project "$gcp_project_id"

# Configure the env file to load the configuration


env_path="./.env"

if [ ! -f "$env_path" ]; then
  # File does not exist, create the file
  touch "$env_path"
  echo ".env file created."
  echo "GOOGLE_CREDENTIALS_FILE_PATH=\"$gcp_pulumi_service_account_key_path\"" >> "$env_path"
else
    echo ".env file already exists. Updating..."
    if grep -q "^GOOGLE_CREDENTIALS_FILE_PATH=" "$env_path"; then
        # Replace the line
        sed -i '' "s|^GOOGLE_CREDENTIALS_FILE_PATH=.*|GOOGLE_CREDENTIALS_FILE_PATH=\"$gcp_pulumi_service_account_key_path\"|" "$env_path"
    else
        # Add the line if it doesn't exist
        echo "GOOGLE_CREDENTIALS_FILE_PATH=\"$gcp_pulumi_service_account_key_path\"" >> "$env_path"
    fi
fi

cd "$original_dir"
