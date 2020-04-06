FROM ubuntu:19.04

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

RUN useradd -m -u 1000 jenkins

USER jenkins

RUN \
  mkdir /home/jenkins/.ssh && \
  ssh-keyscan -t rsa pkg.jenkins.io >> /home/jenkins/.ssh/known_hosts
