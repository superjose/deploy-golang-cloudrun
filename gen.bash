#!/bin/bash
# DEBUG ONLY
source $(pwd)/cli/shared.bash

echo "Welcome to Deploud! We will get the project ready."
echo "This script is idempotent - Execute it as many times as you want without any side effects."

cat << EOF
We will install:
- Docker
- Expect
- jq
- Google Cloud SDK CLI"
- Pulumi CLI

Additionally, as there are one time configurations, you will need
to open your browser to perform them:

- Google Cloud SDK CLI: Login to your Google Account
- Google Cloud Billing: Enable billing for the project

EOF


# PREPARE
# We use jq to read from the config.json
# The config.json will be updated by the bash scripts in case it 
# finds any conflicting values
jq_install_path="$(pwd)/cli/installs/jq.install.bash"
chmod +x  "$jq_install_path"
bash $jq_install_path
config_path="$(pwd)/config.json"
# END PREPARE


original_dir=$(pwd)
script_base_path="$(pwd)/scripts"
pulumi_script="$script_base_path/_main.go"
roles_script="$script_base_path/_roles.gcp.yml"

project_name=$(jq -r '.project_name' "$config_path")
project_description=$(jq -r '.project_description' "$config_path")
project_stack=$(jq -r '.project_stack' "$config_path")
project_language=$(jq -r '.project_language' "$config_path")
gcp_service_account_name=$(jq -r '.gcp_service_account_name' "$config_path")
gcp_service_account_display_name=$(jq -r '.gcp_service_account_display_name' "$config_path")
gcp_service_account_description=$(jq -r '.gcp_service_account_description' "$config_path")
gcp_project_id=$(jq -r '.gcp_project_id' "$config_path")
gcp_pulumi_service_account_key_path=$(jq -r '.gcp_pulumi_service_account_key_path' "$config_path")
gcp_pulumi_service_account_key_path="${gcp_pulumi_service_account_key_path/#\~/$HOME}"
gcp_pulumi_admin_role_name=$(jq -r '.gcp_pulumi_admin_role_name' "$config_path")
dockerfile_relative_path=$(jq -r '.dockerfile_relative_path' "$config_path")
pulumi_relative_path=$(jq -r '.pulumi_relative_path' "$config_path")

pulumi_relative_dir="./pulumi"
pulumi_dir="$pulumi_relative_dir"
# pulumi_dir=$(realpath  "$pulumi_relative_dir")
relative_dockerfile_path=$(rpath --relative-to="$pulumi_relative_dir" "$dockerfile_relative_path")

gcp_roles_path="$pulumi_dir/roles.gcp.yml"
# Add executable permissions
expect_install_path="$(pwd)/cli/installs/expect.install.bash"
docker_install_path="$(pwd)/cli/installs/docker.install.bash"
google_install_path="$(pwd)/cli/installs/google.install.bash"
pulumi_install_path="$(pwd)/cli/installs/pulumi.install.bash"
golang_install_path="$(pwd)/cli/installs/golang.install.bash"

google_config_path="$(pwd)/cli/configs/google.config.bash"
pulumi_config_path="$(pwd)/cli/configs/pulumi.config.bash"

chmod +x  "$expect_install_path"
chmod +x  "$docker_install_path"
chmod +x  "$golang_install_path"

chmod +x  "$google_install_path"
chmod +x  "$pulumi_install_path"

chmod +x  "$google_config_path"
chmod +x  "$pulumi_config_path"


# CLI INSTALLATIONS
# We need to create the project in the respective cloud provider.
# ----------------------------------

# Install Required CLI Tools
bash $expect_install_path
bash $docker_install_path
bash $golang_install_path


# Execute Google CLI Setup
bash $google_install_path --project_name "$project_name" \
    --project_description "$project_description" \
    --project_stack "$project_stack" \
    --gcp_project_id "$gcp_project_id"

google_install_result=$?

if [ $google_install_result -ne 0 ]; then
    echo "$google_install-path failed."
    exit $google_install_result
fi

bash $pulumi_install_path --project_name "$project_name" \
    --project_description "$project_description" --pulumi_dir "$pulumi_dir" \
    --original_dir "$original_dir"  --project_stack "$project_stack"\
    --project_language "$project_language"
pulumi_result=$?

if [ $pulumi_result -ne 0 ]; then
    echo "$pulumi_result-path failed."
    exit $pulumi_result
fi

# Install the script 
cp $pulumi_script $pulumi_dir/main.go
cp $roles_script "$gcp_roles_path" 


# Update and read it again
gcp_project_id=$(jq -r '.gcp_project_id' "$config_path")

bash $google_config_path --project_name "$project_name" \
    --project_description "$project_description" --project_stack "$project_stack"\
    --gcp_service_account_name "$gcp_service_account_name" \
    --gcp_service_account_display_name "$gcp_service_account_display_name" \
    --gcp_project_id "$gcp_project_id" \
    --gcp_service_account_description "$gcp_service_account_description" \
    --gcp_pulumi_service_account_key_path "$gcp_pulumi_service_account_key_path" \
    --gcp_pulumi_admin_role_name "$gcp_pulumi_admin_role_name" \
    --gcp_roles_path "$gcp_roles_path" \
    --config_path "$config_path"
    
google_config_result=$?


if [ $google_config_result -ne 0 ]; then
    echo "$google_config_path failed."
    exit $google_config_result
fi

bash $pulumi_config_path --project_name "$project_name" \
    --gcp_project_id "$gcp_project_id" \
    --pulumi_dir "$pulumi_dir" \
    --original_dir "$original_dir" \
    --gcp_pulumi_service_account_key_path "$gcp_pulumi_service_account_key_path" 

# We read it again, in case it was updated
gcp_project_id=$(jq -r '.gcp_project_id' "$config_path")
gcp_docker_image_name=$(jq -r '.gcp_docker_image_name' "$config_path")
gcp_artifact_registry_service_name=$(jq -r '.gcp_artifact_registry_service_name' "$config_path")
gcp_artifact_registry_repository_name=$(jq -r '.gcp_artifact_registry_repository_name' "$config_path")
gcp_cloud_run_admin_service_name=$(jq -r '.gcp_cloud_run_admin_service_name' "$config_path")
gcp_cloud_run_service_name=$(jq -r '.gcp_cloud_run_service_name' "$config_path")
gcp_location=$(jq -r '.gcp_location' "$config_path")
gcp_image_tag=$(jq -r '.gcp_image_tag' "$config_path")


echo "Updating main.go file"

# Run sed to make the replacements
sed -i '' \
    -e "s/const gcpProjectId = \"[^\"]*\"/const gcpProjectId = \"$gcp_project_id\"/" \
    -e "s/const dockerImageName = \"[^\"]*\"/const dockerImageName = \"$gcp_docker_image_name\"/" \
    -e "s/const artifactRegistryServiceName = \"[^\"]*\"/const artifactRegistryServiceName = \"$gcp_artifact_registry_service_name\"/" \
    -e "s/const artifactRegistryRepoName = \"[^\"]*\"/const artifactRegistryRepoName = \"$gcp_artifact_registry_repository_name\"/" \
    -e "s/const artifactRegistryRepoLocation = \"[^\"]*\"/const artifactRegistryRepoLocation = \"$gcp_location\"/" \
    -e "s/const cloudRunAdminServiceName = \"[^\"]*\"/const cloudRunAdminServiceName = \"$gcp_cloud_run_admin_service_name\"/" \
    -e "s/const cloudRunServiceName = \"[^\"]*\"/const cloudRunServiceName = \"$gcp_cloud_run_service_name\"/" \
    -e "s/const cloudRunLocation = \"[^\"]*\"/const cloudRunLocation = \"$gcp_location\"/" \
    -e "s/const imageTag = \"[^\"]*\"/const imageTag = \"$gcp_image_tag\"/" \
    -e "s|Context: pulumi.String([^)]*),|Context: pulumi.String(\"$relative_dockerfile_path\"),|" \
    "$pulumi_dir/main.go"


# Updates the go file with proper names
# Run sed to make the replacements
echo "Project setup is complete. You can now start developing your application."

echo "To run the application:"
echo "
 1. Start Docker.
 2. Go to the pulumi directory, and run pulumi up.
"