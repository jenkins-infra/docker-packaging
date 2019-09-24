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
    createrepo \
    debhelper \
    devscripts \
    expect \
    make \
    maven \
    rpm \
    tzdata \
    unzip &&\
  apt-get clean &&\ 
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
