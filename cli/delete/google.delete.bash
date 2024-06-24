
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gcp_project_id)
          gcp_project_id="$2"
            shift 2
            ;;
        --gcp_service_account_name)
            gcp_service_account_name="$2"
            shift 2
            ;;
        --gcp_pulumi_service_account_key_path)
           gcp_pulumi_service_account_key_path="$2"
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

# We delete the service account key json file. We use the -f flag 
# to avoid errors if the file does not exist
rm -f "$gcp_pulumi_service_account_key_path"

service_account_keys=$(gcloud iam service-accounts keys list --iam-account="$gcp_service_account_name@$gcp_project_id.iam.gserviceaccount.com" --format="json" 2>&1)

if [[ ! "$service_account_keys" =~ .*"or it may not exist".* ]]; then
    echo "Deleting service account keys for "$gcp_service_account_name""
    gcloud iam service-accounts keys delete "$gcp_pulumi_service_account_key_path" \
        --iam-account="$gcp_service_account_name@$gcp_project_id.iam.gserviceaccount.com" \
        --project="$gcp_project_id"
fi


gcloud_role=$(gcloud iam roles describe "$gcp_pulumi_admin_role_name" --project="$gcp_project_id" --format=json 2>&1)

# removes the gcloud iam role if exists.
if jq -e . >/dev/null 2>&1 <<<"$gcloud_role"; then
    if ! echo "$gcloud_role" | jq -e '.deleted == true' >/dev/null 2>&1; then
        gcloud iam roles delete "$gcp_pulumi_admin_role_name" --project="$gcp_project_id"
    fi
elif [[ ! "$gcloud_role" =~ "NOT_FOUND: The role named" ]]; then
    echo "Deleting service account role $gcp_pulumi_admin_role_name"
    gcloud iam roles delete "$gcp_pulumi_admin_role_name" --project="$gcp_project_id"
fi

service_account=$(gcloud iam service-accounts describe "$gcp_service_account_name@$gcp_project_id.iam.gserviceaccount.com" 2>&1)

if [[ ! "$service_account" == *"NOT_FOUND: Unknown service account"* && ! "$service_account" == *"denied on resource (or it may not exist"* ]]; then    echo "Deleting service account role "$gcp_service_account_name" and role "$gcp_pulumi_admin_role_name""
    gcloud iam service-accounts delete "$gcp_service_account_name@$gcp_project_id.iam.gserviceaccount.com"
fi





# Check if billing is enabled for the project. 
# This is needed. Otherwise pulumi up will fail. 
# Note that the link generated may not work as expected if you have multiple accounts
gcloud_billing_project=$(gcloud billing projects describe "$gcp_project_id" --format="json")

is_billing_enabled=$(echo "$gcloud_billing_project" | jq '.billingEnabled')

if [[ "$is_billing_enabled" == "true" ]]; then
    cat << EOF
Billing is enabled for the project. Please disable billing for the project by removing it.
Opening the google cloud billing page in the browser
If you have multiple accounts, the link may not work. Go to the billing page manually. 
(https://console.cloud.google.com/billing)
EOF
    
    open "https://console.cloud.google.com/billing/manage?project=$gcp_project_id&hl=en&"
    echo "Please, run this script again to finish removing the project."
    echo "We won't proceed with the deletion of the project until billing is disabled."
    exit 0
fi

gcp_project=$(gcloud projects describe "$gcp_project_id" --format=json 2>&1)

if jq -e . >/dev/null 2>&1 <<<"$gcp_project"; then
    if ! echo "$gcp_project" | jq '.lifecycleState == "DELETE_REQUESTED" or .lifecycleState == "DELETED"' >/dev/null 2>&1; then    
        echo "Deleting project $gcp_project_id"
        gcloud projects delete $gcp_project_id
    fi
elif [[ ! "$gcp_project" =~ *"(or it may not exist)"* ]]; then
    echo "Deleting project $gcp_project_id"
    gcloud projects delete $gcp_project_id
fi

