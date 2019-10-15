.PHONY: .build

IMAGE = 'jenkinsciinfra/packaging'
TAG = $(shell git rev-parse HEAD | cut -c1-6)

build:
	docker build --no-cache -t $(IMAGE):$(TAG) -t $(IMAGE):latest -f Dockerfile .

publish:
	 docker push $(IMAGE):$(TAG)
	 docker push $(IMAGE):latest

run:
	docker run -i -t --rm --entrypoint /bin/bash $(IMAGE):$(TAG)

