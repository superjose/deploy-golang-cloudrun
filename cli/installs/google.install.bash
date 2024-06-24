
#!/bin/bash

source $(pwd)/cli/shared.bash

# This CLI script will 
# 1. Authenticate with Google Cloud CLI.
# 2. Create the project for you.

# Required Parameters
# project_name="delete3"
# project_description="A Pulumi Project Used to Deploy a Golang application"
# project_stack="dev"

# We read each of the parameters passed
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
        # Optional. It will be generated if not provided
        --gcp_project_id)
            gcp_project_id="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
    esac
done


# Check for Google Cloud CLI
if command -v gcloud > /dev/null 2>&1; then
    echo "Google Cloud CLI is installed."
else
    echo "Google Cloud CLI is not installed."
fi

authenticated_account=$(gcloud auth list --format="value(account)" --filter=status:ACTIVE)

if [ -z "$authenticated_account" ]; then
    echo "No active authenticated user found in google."
    echo "We will now open a google auth login using glocud auth login"
    echo "Once finished open this script again"
    gcloud auth login
else
    # https://cloud.google.com/sdk/gcloud/reference/auth/login
    echo "Authenticated as $authenticated_account"
fi


# Checks if the project exists. If it does, skip creation
gcp_project=$(gcloud projects describe "$gcp_project_id" --format=json 2>&1)
# Check if the gcloud command output is valid JSON using jq
if echo "$gcp_project" | jq -e . >/dev/null 2>&1; then
    # Extract the lifecycleState from the JSON
    lifecycle_state=$(echo "$gcp_project" | jq -r '.lifecycleState')
    
    # Check if lifecycleState is DELETE_REQUESTED
    if [ "$lifecycle_state" == "DELETE_REQUESTED" ]; then    
        echo "Restoring project $gcp_project_id"
        # Uncomment the following line to actually restore the project
        gcloud projects undelete $gcp_project_id
    fi
    exit 0
fi


# Function to generate a unique project ID
generate_project_id() {
    local random_part=$(generate_random_number) # Random number between 100 and 999
    echo "${project_name}-${random_part}"
}

# Function to check if a project ID exists
project_exists() {
    local project_id=$1
    if gcloud projects describe $project_id &> /dev/null; then
        return 0 # project exists
    else
        echo "Project with ID $project_id does not exist."
        return 1 # project does not exist
    fi
}

# Function to create a new project
create_project() {
    local project_id=$1
    gcloud projects create $project_id --name $project_name
}

# Main logic to generate project ID and create project if it doesn't exist
attempt_limit=5
attempt_count=0

if [ -z "$gcp_project_id" ]; then
    echo "Generating a new project ID..."
    new_project_id=$(generate_project_id)
else
    echo "Using provided project ID: $gcp_project_id"
    new_project_id="$gcp_project_id"
fi

while [ $attempt_count -lt $attempt_limit ]; do
    if ! project_exists $new_project_id; then
        echo "Creating project with ID: $new_project_id"
        project_result=$(create_project $new_project_id 2>&1)
        if [[ "$project_result" =~ *"Please try an alternative ID"* ]]; then
            echo "Project ID $new_project_id is not available, generating a new one..."
            new_project_id=$(generate_project_id)
            ((attempt_count++))
            continue
        fi  
        echo $project_result

        if [[ "$project_result" =~ failed ]]; then
            echo "Project creation failed."
            exit 1
        fi
        break
    else
        echo "Project ID $new_project_id already exists, generating a new one..."
        new_project_id=$(generate_project_id)
        ((attempt_count++))
    fi
done

if [ $attempt_count -eq $attempt_limit ]; then
    echo "Failed to create a unique project after $attempt_limit attempts."
    exit 1
fi

if gcloud projects list --format="get(projectId)" --filter="name:${project_name}" | grep -q .; then
    echo "Project with name $project_name exists."
else
    echo "Project with name $project_name does not exist."
fi

exit 0
