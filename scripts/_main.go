package main

import (
	"errors"
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/pulumi/pulumi-docker/sdk/v3/go/docker"
	"github.com/pulumi/pulumi-gcp/sdk/v7/go/gcp/artifactregistry"
	"github.com/pulumi/pulumi-gcp/sdk/v7/go/gcp/cloudrun"
	"github.com/pulumi/pulumi-gcp/sdk/v7/go/gcp/projects"
	"github.com/pulumi/pulumi/sdk/v3/go/pulumi"
)

// This is the name you created in Google Cloud Platform (GCP).
const gcpProjectId = "deploy-to-cloud-run-go"

// The Docker Image Name
const dockerImageName = "my-app-docker"
const artifactRegistryServiceName = "artifact-registry-api"
const artifactRegistryRepoName = "my-app-artifact-repo"
const artifactRegistryRepoLocation = "us-east1"
const cloudRunAdminServiceName = "cloud-run-admin-service"
const cloudRunServiceName = "cloud-run-service"

// For more info: https://cloud.google.com/run/docs/locations
const cloudRunLocation = "us-east1"

// The tag for the Docker image
const imageTag = "latest"

// This is a url like: us-east1-docker.pkg.dev
// It is used to push the Docker image to Google Container Registry
// For more info: https://cloud.google.com/container-registry/docs/pushing-and-pulling
// The format is: <region>-docker.pkg.dev
var dockerGCPServer = cloudRunLocation + "-docker.pkg.dev"

// The full path to the Docker image
// It is used to deploy the Docker image to Google Cloud Run
// The format is: <region>-docker.pkg.dev/<project-id>/<repo-name>/<image-name>:<tag>
// For more info: https://cloud.google.com/run/docs/deploying
// Example: us-east1-docker.pkg.dev/deploy-to-cloud-run-go/my-app--artifact-repo/my-app-docker:latest
var dockerImageWithPath = dockerGCPServer + "/" + gcpProjectId + "/" + artifactRegistryRepoName + "/" + dockerImageName + ":" + imageTag

func main() {

	// Load the .env file
	err := godotenv.Load()

	if err != nil {
		log.Fatal("Error loading .env file")
	}

	pulumi.Run(func(ctx *pulumi.Context) error {

		enabledServices, serviceResultErr := enableServices(ctx)

		if serviceResultErr != nil {
			return serviceResultErr
		}

		artifactRegistryRepo, createArtifactErr := createArtifactRegistryNewRepository(ctx, &enabledServices)
		if createArtifactErr != nil {
			return createArtifactErr
		}

		dockerImage, buildAndPushErr := buildAndPushToContainerRegistry(ctx, &enabledServices, artifactRegistryRepo)

		if buildAndPushErr != nil {
			return buildAndPushErr
		}

		deployContainerErr := deployContainerToCloudRun(ctx, &enabledServices, dockerImage)

		if deployContainerErr != nil {
			return deployContainerErr
		}

		return nil
	})
}

type EnabledServices struct {
	CloudRunService         *projects.Service `pulumi:"cloudRunService"`
	ArtifactRegistryService *projects.Service `pulumi:"artifactRegistryService"`
}

func enableServices(ctx *pulumi.Context) (EnabledServices, error) {
	cloudResourceManager, cloudResourceErr := projects.NewService(ctx, "cloud-resource-manager", &projects.ServiceArgs{
		Service: pulumi.String("cloudresourcemanager.googleapis.com"),
		Project: pulumi.String(gcpProjectId),
	})

	if cloudResourceErr != nil {
		return EnabledServices{}, cloudResourceErr
	}

	cloudRunService, cloudRunAdminErr := projects.NewService(ctx, cloudRunAdminServiceName, &projects.ServiceArgs{
		Service: pulumi.String("run.googleapis.com"),
		Project: pulumi.String(gcpProjectId),
	}, pulumi.DependsOn([]pulumi.Resource{cloudResourceManager}))

	if cloudRunAdminErr != nil {
		return EnabledServices{}, cloudRunAdminErr
	}

	artifactRegistryService, err := projects.NewService(ctx, artifactRegistryServiceName, &projects.ServiceArgs{
		Service: pulumi.String("artifactregistry.googleapis.com"),
	}, pulumi.DependsOn([]pulumi.Resource{cloudResourceManager}))

	if err != nil {
		return EnabledServices{}, err
	}
	return EnabledServices{
		CloudRunService:         cloudRunService,
		ArtifactRegistryService: artifactRegistryService,
	}, nil
}

func createArtifactRegistryNewRepository(ctx *pulumi.Context, enabledServices *EnabledServices) (*artifactregistry.Repository, error) {

	if enabledServices == nil || enabledServices.ArtifactRegistryService == nil {
		return nil, errors.New("enabledServices cannot be nil")
	}

	dependingResources := []pulumi.Resource{
		enabledServices.ArtifactRegistryService,
	}

	repo, err := artifactregistry.NewRepository(ctx, artifactRegistryRepoName, &artifactregistry.RepositoryArgs{
		Location:     pulumi.String(artifactRegistryRepoLocation),
		RepositoryId: pulumi.String(artifactRegistryRepoName),
		Format:       pulumi.String("DOCKER"),
		Description:  pulumi.String("The repository that will hold social-log Docker images."),
		Project:      pulumi.String(gcpProjectId),
	}, pulumi.DependsOn(dependingResources))

	if err != nil {
		return nil, err
	}

	return repo, nil
}

func buildAndPushToContainerRegistry(ctx *pulumi.Context, enabledServices *EnabledServices, artifactRegistryRepo *artifactregistry.Repository) (*docker.Image, error) {

	if enabledServices == nil || enabledServices.ArtifactRegistryService == nil {
		return nil, errors.New("enabledServices cannot be nil")
	}

	if artifactRegistryRepo == nil {
		return nil, errors.New("artifactRegistryRepo cannot be nil")
	}

	// Lookup GOOGLE_CREDENTIALS environment variable which should hold the path to the JSON key file
	jsonKeyPath, present := os.LookupEnv("GOOGLE_CREDENTIALS_FILE_PATH")
	if !present {
		return nil, errors.New("GOOGLE_CREDENTIALS_FILE_PATH environment variable is not set")
	}

	// Read the JSON key file
	jsonKey, err := os.ReadFile(jsonKeyPath)
	if err != nil {
		return nil, err
	}

	dependingSources := []pulumi.Resource{
		enabledServices.ArtifactRegistryService,
		artifactRegistryRepo,
	}

	// Build and push Docker image to Google Container Registry using the JSON key
	image, err := docker.NewImage(ctx, dockerImageName, &docker.ImageArgs{
		Build: &docker.DockerBuildArgs{
			Context: pulumi.String("../"), // Adjust the context according to your project structure

			ExtraOptions: pulumi.StringArray{
				// This option is needed for devices running on ARM architecture, such as Apple M1/M2/MX CPUs
				pulumi.String("--platform=linux/amd64"),
			},
		},
		ImageName: pulumi.String(dockerImageWithPath),
		Registry: &docker.ImageRegistryArgs{
			Server:   pulumi.String(dockerGCPServer),
			Username: pulumi.String("_json_key"),     // Special username for GCP
			Password: pulumi.String(string(jsonKey)), // Provide the contents of the key file
		},
	}, pulumi.DependsOn(dependingSources))
	if err != nil {
		return nil, err
	}

	return image, nil
}

func deployContainerToCloudRun(ctx *pulumi.Context, enabledServices *EnabledServices, dockerImage *docker.Image) error {

	if enabledServices == nil || enabledServices.CloudRunService == nil {
		return errors.New("enabledServices cannot be nil")
	}

	if dockerImage == nil {
		return errors.New("dockerImage cannot be nil")
	}

	dependingSources := []pulumi.Resource{
		enabledServices.CloudRunService,
		dockerImage,
	}

	appService, err := cloudrun.NewService(ctx, cloudRunServiceName, &cloudrun.ServiceArgs{
		Project:  pulumi.String(gcpProjectId),
		Location: pulumi.String(cloudRunLocation), // Choose the appropriate region for your service
		Template: &cloudrun.ServiceTemplateArgs{
			Spec: &cloudrun.ServiceTemplateSpecArgs{
				Containers: cloudrun.ServiceTemplateSpecContainerArray{
					&cloudrun.ServiceTemplateSpecContainerArgs{
						Image: dockerImage.ImageName,
						Resources: &cloudrun.ServiceTemplateSpecContainerResourcesArgs{
							Limits: pulumi.StringMap{
								"memory": pulumi.String("256Mi"), // Adjust the memory limit as needed
							},
						},
					},
				},
			},
		},
		Traffics: cloudrun.ServiceTrafficArray{
			&cloudrun.ServiceTrafficArgs{
				Percent:        pulumi.Int(100),
				LatestRevision: pulumi.Bool(true),
			},
		},
	}, pulumi.DependsOn(dependingSources))

	if err != nil {
		return err
	}

	_, iamErr := cloudrun.NewIamMember(ctx, "invoker", &cloudrun.IamMemberArgs{
		Service:  appService.Name,
		Location: appService.Location,
		Role:     pulumi.String("roles/run.invoker"),
		Member:   pulumi.String("allUsers"),
	})

	if iamErr != nil {
		return iamErr
	}

	ctx.Export("containerUrl", appService.Statuses.Index(pulumi.Int(0)).Url().ToOutput(ctx.Context()))
	return nil
}
