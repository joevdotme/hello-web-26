"""Pulumi program — builds and runs the hello-web-26 Flask app via Docker."""

import pulumi
import pulumi_docker as docker
import pulumi_terraform as terraform

config = pulumi.Config()
host_port = config.get_int("hostPort") or 5000

# Build the Docker image from the project root (one level up from infra/).
image = docker.Image(
    "hello-web-26-image",
    build=docker.DockerBuildArgs(context=".."),
    image_name="hello-web-26:latest",
    skip_push=True,
)

# Run the container locally.
container = docker.Container(
    "hello-web-26-container",
    image=image.image_name,
    ports=[docker.ContainerPortArgs(internal=5000, external=host_port)],
    restart="unless-stopped",
    opts=pulumi.ResourceOptions(depends_on=[image]),
)

pulumi.export("container_name", container.name)
pulumi.export("url", pulumi.Output.concat("http://localhost:", str(host_port)))

# Optionally surface outputs from the Terraform-managed AWS serverless stack.
# Requires `make tf-up` to have been run first.
# Enable with: pulumi config set readTfState true
if config.get_bool("readTfState"):
    tf_state = terraform.state.RemoteStateReference(
        "tf-local-state",
        backend_type="local",
        args=terraform.state.LocalBackendArgs(
            path="../terraform/terraform.tfstate",
        ),
    )
    pulumi.export("tf_api_url", tf_state.get_output("api_url"))
    pulumi.export("tf_function_name", tf_state.get_output("function_name"))
