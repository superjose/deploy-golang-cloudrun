source $(pwd)/cli/shared.bash

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project_name)
            project_name="$2"
            shift 2
            ;;
        --project_description)
            project_description="$2"
            shift 2
            ;;
        --project_stack)
            project_stack="$2"
            shift 2
            ;;
        --gcp_project_id)
          gcp_project_id="$2"
            shift 2
            ;;
        --gcp_service_account_name)
            gcp_service_account_name="$2"
            shift 2
            ;;
        --gcp_service_account_display_name)
            gcp_service_account_display_name="$2"
            shift 2
            ;;
        --gcp_service_account_description)
            gcp_service_account_description="$2"
            shift 2
            ;;
        --gcp_pulumi_service_account_key_path)
           gcp_pulumi_service_account_key_path="$2"
            shift 2
            ;;
        --gcp_pulumi_admin_role_name)
           gcp_pulumi_admin_role_name="$2"
            shift 2
            ;;
        --gcp_roles_path)
            gcp_roles_path="$2"
            shift 2
            ;;
        --config_path)
            config_path="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done

create_service_account() {
    local max_retries=5
    local retry_count=$1
    local append_suffix=$2

    local new_service_account_name="${gcp_service_account_name}" 
    if [[ -n "$append_suffix" ]]; then
        new_service_account_name="${gcp_service_account_name}-${append_suffix}"
    fi 

    if [[ $retry_count -eq $max_retries ]]; then
        echo "Max retries reached while creating the service account. Exiting..."
        exit 1
    fi

    output=$(gcloud iam service-accounts create "$new_service_account_name" \
    --description="$gcp_service_account_description" \
    --project="$gcp_project_id" \
    --display-name="$gcp_service_account_display_name" 2>&1)

   if [[ "$output" == *"Service account $gcp_service_account_name already exists"* ]]; then
       random_number=$(generate_random_number)
       echo "Service account already exists. Retrying with a random number: $random_number"
       create_service_account $((retry_count + 1)) $random_number
       return $?
   fi 

   

   echo "The new name is $new_service_account_name"
   # Write the successful gcp_service_account_name to the config.json
   update_config ".gcp_service_account_name" "$new_service_account_name"
   echo $output
}

create_pulumi_role() {
    local max_retries=5
    local retry_count=$1
    local append_suffix=$2

    local new_role_name="${gcp_pulumi_admin_role_name}" 
    if [[ -n "$append_suffix" ]]; then
        new_role_name="${gcp_pulumi_admin_role_name}-${append_suffix}"
    fi 

    if [[ $retry_count -eq $max_retries ]]; then
        echo "Max retries reached while creating the role. Exiting..."
        exit 1
    fi

    output=$(gcloud iam roles create "$new_role_name" \
    --project="$gcp_project_id" \
    --file="$gcp_roles_path" 2>&1)

   if [[ "$output" == *"Role $gcp_pulumi_admin_role_name already exists"* ]]; then
       random_number=$(generate_random_number)
       echo "Role already exists. Retrying with a random number: $random_number"
       create_pulumi_role $((retry_count + 1)) $random_number
       return $?
   fi 

   echo "Creating role: $new_role_name"
   # Write the successful gcp_service_account_name to the config.json
   update_config ".gcp_pulumi_admin_role_name" "$new_role_name"
   echo $output
}




# Check if project Id does not exist
if [[ -z "$gcp_project_id" ]]; then
    gcp_project_id=$(gcloud projects list --format="get(projectId)" --filter="name:${project_name}" 2>&1)
    update_config ".gcp_project_id" "$gcp_project_id"
fi


service_account=$(gcloud iam service-accounts describe "$gcp_service_account_name@$gcp_project_id.iam.gserviceaccount.com" 2>&1)


if [[ "$service_account" == *"NOT_FOUND: Unknown service account"* ]]; then
    echo "Service account "$gcp_service_account_name" was not found. Creating..."
    create_service_account
fi

# Download the credentials for the service accounts and store them locally in the keys directory
if [ ! -s "$gcp_pulumi_service_account_key_path" ]; then
    gcloud iam service-accounts keys create "$gcp_pulumi_service_account_key_path" \
        --iam-account="$gcp_service_account_name@$gcp_project_id.iam.gserviceaccount.com" \
        --project="$gcp_project_id"
fi


gcloud_role=$(gcloud iam roles describe "$gcp_pulumi_admin_role_name" --project="$gcp_project_id" 2>&1)


if [[ "$gcloud_role" == *"NOT_FOUND: The role named"* ]]; then
    echo "The Role $gcp_service_account_name was not found. Creating..."
    create_pulumi_role
else 
    echo "The role $gcp_pulumi_admin_role_name already exists. Updating..."
    # Google cloud will ask us if we want to update the role. We will say
    # yes. Additionally we do not provide an etag as we assume that the roles
    # will not be updated concurrently
    yes | gcloud iam roles update "$gcp_pulumi_admin_role_name" \
    --project="$gcp_project_id" \
    --file="$gcp_roles_path"
fi

iam_policy=$(gcloud projects get-iam-policy "$gcp_project_id" --format=json)

iam_policy_role="projects/$gcp_project_id/roles/$gcp_pulumi_admin_role_name"
iam_policy_member="serviceAccount:$gcp_service_account_name@$gcp_project_id.iam.gserviceaccount.com"

is_present=$(echo "$iam_policy" | jq --arg role "$iam_policy_role" --arg member "$iam_policy_member" '
  .bindings[] | select(.role == $role and .members[] == $member) | length > 0
')

if [[ "$is_present" != "true" ]]; then
  echo "The specified role and member are not present."
  echo "Attaching the policy binding"
  gcloud projects add-iam-policy-binding "$gcp_project_id" --role "$iam_policy_role"  --member  "$iam_policy_member"
fi

# Check if billing is enabled for the project. 
# This is needed. Otherwise pulumi up will fail. 
# Note that the link generated may not work as expected if you have multiple accounts
gcloud_billing_project=$(gcloud billing projects describe "$gcp_project_id" --format="json")

is_billing_enabled=$(echo "$gcloud_billing_project" | jq '.billingEnabled')

if [[ "$is_billing_enabled" != "true" ]]; then
    echo "Billing is not enabled for the project. Please enable billing for the project."
    echo "Opening the google cloud billing page in the browser"
    echo "If you have multiple accounts, the link may not work. Go to the billing page manually. (https://console.cloud.google.com/billing) \n\n\n"
    open "https://console.cloud.google.com/billing/linkedaccount?project=$gcp_project_id&hl=en&"
fi
