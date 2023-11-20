# This line specifies that the 'build' target is a phony target, meaning it doesn't represent a file.
.PHONY: .build

# Define variables for the Docker image name and tag.
IMAGE = 'jenkinsciinfra/packaging'
TAG = $(shell git rev-parse HEAD | cut -c1-6)

# 'build' target builds a Docker image using the Dockerfile in the current directory.
build:
	docker build --no-cache -t $(IMAGE):$(TAG) -t $(IMAGE):latest -f Dockerfile .

# 'publish' target pushes the Docker image to a container registry.
publish:
	# Push the image with the specific TAG
	docker push $(IMAGE):$(TAG)
	# Push the image with the 'latest' tag for the most recent version.

# 'run' target runs a Docker container based on the specified image and tag, providing an interactive shell.
run:
	docker run -i -t --rm --entrypoint /bin/bash $(IMAGE):$(TAG)
