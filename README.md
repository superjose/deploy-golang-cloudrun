# Deploy Go to Google Cloud Run

Idempotent scripts (They won't create duplicate resources if ran again) that will deploy your dockerized golang application to Google Cloud Run instantaneously with a single command `gen.bash`.

It will also bring down all the resources when you don't need them `del.bash`. (This won't delete the local files)

It installs CLIs in your machine and bootstraps a Pulumi code that you will be able to leverage all the required services and have your application running. (See How it Works)

## How to use:

1. Clone the repository (or download the .zip file in the releases page)
2. Configure the `config.json` with your information (At least: `project_name`, `dockerfile_relative_path`, `pulumi_relative_path`)
3. Run the `gen.bash` script.

```bash
bash gen.bash
```

4. Navigate to the recently created `pulumi` (`cd ./pulumi`) folder, and:

```bash
pulumi up
```

When you want to bring everything down:

```bash
bash del.bash
```

## How it works:

This repo has all the files you need to get your dockerized application deployed.

Clone the repo somewhere in your project. Configure the `dockerfile_relative_path` on the `config.json`. This should point to your `Dockerfile` relative to the `gen.bash`.

<img src="./images/docker-explanation.avif" width="350px" />

You should unzip them somewhere in your project (e.g. <root>/deploy).

The scripts will:

1. Install the required CLI tools (gcloud, expect, docker, jq, pulumi, golang)
2. Configure the required permissions in GCloud
3. Scaffold the right Pulumi scripts for you

We check whether each of these are installed on your system and install them if not. This will install the following CLI tools:

1. [Docker](https://docker.com)
2. [Pulumi CLI](https://pulumi.com)
3. [Go](https://golang.org)
4. [Google CLI](https://cloud.google.com/sdk)
5. [jq](https://stedolan.github.io/jq/)
6. [Expect](https://core.tcl.tk/expect/index)

The Google SDK is used to enable the first services.
Pulumi is then used to orchestrate the entire process. jq is used to parse the JSON output from the Google SDK. Expect is used to handle certain edge cases from the Pulumi and Google Cloud CLIs.

## Configuration

Open `config.json` and edit its values.

- `project_name`
  The name of the project. This is the display value that you will see in Google Cloud's console.

- `project_description`
  The description of the project.

- `project_stack`:
  The stack in which Pulumi will be configured. Either dev, staging, production, prod, etc.

- `project_language`:
  Currently supporting go, you should leave it as it is.

- `gcp_project_id`:
  The Google Cloud's unique Project ID which the CLI will create the project.

- `gcp_service_account_name`
  The service accounts are used by Pulumi to perform operations in Google Cloud. This is the name that will show up in IAM. The name should be unique, lowercase, have no spaces and no special characters (except hyphens).

- `gcp_service_account_display_name`
  The service accounts are used by Pulumi to perform operations in Google Cloud. This is the name that will show up in IAM. The name should be unique, lowercase, have no spaces and no special characters (except hyphens).

- `gcp_service_account_display_name`
  Same as above. But this will be the human readable name.

- `gcp_service_account_description`
  The description of the service account.

- `gcp_pulumi_service_account_key_path`
  The file path in which we'll save the the key for Pulumi to connect to Google Cloud.

- `gcp_pulumi_admin_role_name`
  This is the Google Cloud Role that we will assign to the service account. This role will have the necessary permissions to deploy to Google Cloud with the services you've selected.

- `gcp_docker_image_name`
  This is the name that will be visible in Google Cloud Run's Artifact Registry. This isn't the name of your local Docker image. This is part of the Pulumi code.

- `gcp_artifact_registry_service_name`
  This is the name of the Artifact Registry service that will be created in Google Cloud. This is part of the Pulumi code. Artifact Registry is used to store the Docker image.

- `gcp_artifact_registry_repository_name`
  This is the name of the Artifact Registry repository that will be created in Google Cloud. This is part of the Pulumi code. We need to store the Docker image in a repository inside Artifact Registry.

- `gcp_cloud_run_admin_service_name`
  This is the name of the Cloud Run service that will be created in Google Cloud. This is part of the Pulumi code. This service will be used to manage the Cloud Run services.

- `gcp_cloud_run_service_name`
  This is the name of the Cloud Run service that will be created in Google Cloud. This is part of the Pulumi code. This service will be used to deploy the Docker image to Google Cloud Run.

- `gcp_location`
  This is the location where the resources will be deployed. You can find a list [here](https://cloud.google.com/about/locations). This is part of the Pulumi code
