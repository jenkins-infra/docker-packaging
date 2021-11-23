FROM ubuntu:18.04

LABEL \
  project="https://github.com/jenkins-infra/docker-packaging"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

COPY ./conf.d/rpm_macros /etc/rpm/macros
COPY ./conf.d/devscripts.conf /etc/devscripts.conf

## Always install the latest package and pip versions
# hadolint ignore=DL3008,DL3013
RUN \
  apt-get update &&\
  apt-get install --yes --no-install-recommends \
    apt-utils \
    createrepo \
    curl \
    debhelper \
    devscripts \
    expect \
    git \
    gpg \
    make \
    maven \
    openssh-server \
    python3-pip \
    rpm \
    rsync \
    tzdata \
    unzip &&\
  apt-get clean &&\
  pip3 install --no-cache-dir jinja2  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG JV_VERSION=0.2.0
RUN curl -o jenkins-version-linux-amd64.tar.gz -L https://github.com/jenkins-infra/jenkins-version/releases/download/${JV_VERSION}/jenkins-version-linux-amd64.tar.gz && \
  tar xvfz jenkins-version-linux-amd64.tar.gz && \
  mv jv /usr/local/bin && \
  rm jenkins-version-linux-amd64.tar.gz && \
  jv --version

ARG JENKINS_USERNAME=jenkins
RUN useradd -m -u 1000 "${JENKINS_USERNAME}"

USER $JENKINS_USERNAME

RUN \
  mkdir /home/jenkins/.ssh && \
  ssh-keyscan -t rsa pkg.origin.jenkins.io >> /home/jenkins/.ssh/known_hosts
