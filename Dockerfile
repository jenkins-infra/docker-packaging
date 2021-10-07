FROM ubuntu:18.04

LABEL \
  project="https://github.com/jenkins-infra/docker-packaging"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

COPY ./conf.d/rpm_macros /etc/rpm/macros
COPY ./conf.d/devscripts.conf /etc/devscripts.conf

RUN \
  apt-get update &&\ 
  apt-get install -y \
    apt-utils \
    openssh-server \
    python3-pip \
    createrepo \
    debhelper \
    devscripts \
    expect \
    make \
    maven \
    rpm \
    rsync \
    tzdata \
    unzip &&\
  apt-get clean &&\ 
  pip3 install jinja2  && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG JV_VERSION=0.0.3
RUN curl -o jenkins-version-linux-amd64.tar.gz -L https://github.com/jenkins-infra/jenkins-version/releases/download/${JV_VERSION}/jenkins-version-linux-amd64.tar.gz && \
  tar xvfz jenkins-version-linux-amd64.tar.gz && \
  mv jv /usr/local/bin && \
  rm jenkins-version-linux-amd64.tar.gz && \
  jv --version

RUN useradd -m -u 1000 jenkins

USER jenkins

RUN \
  mkdir /home/jenkins/.ssh && \
  ssh-keyscan -t rsa pkg.origin.jenkins.io >> /home/jenkins/.ssh/known_hosts
