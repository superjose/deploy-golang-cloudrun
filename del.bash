cat <<EOF
This will remove all the resources created by the script.
This won't uninstall the CLIs installed by the script.
This will run pulumi destroy and pulumi stack rm.

This will NOT delete any of the files within the pulumi directory

We assume that all CLIs and programs are still installed

EOF


config_path="$(pwd)/config.json"

project_stack=$(jq -r '.project_stack' "$config_path")
gcp_service_account_name=$(jq -r '.gcp_service_account_name' "$config_path")
gcp_project_id=$(jq -r '.gcp_project_id' "$config_path")
gcp_pulumi_service_account_key_path=$(jq -r '.gcp_pulumi_service_account_key_path' "$config_path")
gcp_pulumi_service_account_key_path="${gcp_pulumi_service_account_key_path/#\~/$HOME}"
gcp_pulumi_admin_role_name=$(jq -r '.gcp_pulumi_admin_role_name' "$config_path")
pulumi_relative_path=$(jq -r '.pulumi_relative_path' "$config_path")


original_dir=$(pwd)
google_delete_path="$(pwd)/cli/delete/google.delete.bash"
pulumi_relative_dir="./pulumi"
pulumi_dir=$(realpath  "$pulumi_relative_dir")


chmod +x  "$google_delete_path"

cd "$pulumi_relative_path"
pulumi_stack=$(pulumi stack select "$project_stack" 2>&1)

if [[ ! "$pulumi_stack" =~ .*"no stack named".* ]]; then
    echo "Removing pulumi and destroying the stack"
    pulumi destroy -y
    pulumi stack rm "$project_stack" -y
fi

bash $google_delete_path \
    --gcp_project_id "$gcp_project_id" \
    --gcp_service_account_name "$gcp_service_account_name" \
    --gcp_pulumi_service_account_key_path "$gcp_pulumi_service_account_key_path" \
    --gcp_pulumi_admin_role_name "$gcp_pulumi_admin_role_name" \
    --config_path "$config_path"

echo "All of your resources have been deleted"