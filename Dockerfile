ARG JX_RELEASE_VERSION=2.5.1
ARG JENKINS_AGENT_VERSION=4.11.2-2

FROM ghcr.io/jenkins-x/jx-release-version:${JX_RELEASE_VERSION} AS jx-release-version
FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-jdk11 AS jenkins-agent

## Ubuntu 18.04 is required only for the package `createrepo` (https://packages.ubuntu.com/bionic/createrepo - version 0.10.3-1)
## Switching to Debian, or Ubuntu 20+ requires to use `createrepo_c` (https://github.com/rpm-software-management/createrepo_c - version 0.18.0 latest)
FROM ubuntu:18.04
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
LABEL project="https://github.com/jenkins-infra/docker-packaging"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

## Always install the latest package and pip versions
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    apt-utils \
    createrepo \
    curl \
    build-essential \
    debhelper \
    devscripts \
    expect \
    fakeroot \
    git \
    gpg \
    gpg-agent \
    make \
    openssh-server \
    openssl \
    python3-pip \
    rpm \
    rsync \
    tzdata \
    unzip \
  && apt-get clean \
  && pip3 install --no-cache-dir jinja2 \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG JV_VERSION=0.2.0
RUN curl -o jenkins-version-linux-amd64.tar.gz -L https://github.com/jenkins-infra/jenkins-version/releases/download/${JV_VERSION}/jenkins-version-linux-amd64.tar.gz && \
  tar xvfz jenkins-version-linux-amd64.tar.gz && \
  mv jv /usr/local/bin && \
  rm jenkins-version-linux-amd64.tar.gz && \
  jv --version

ARG GH_VERSION=2.4.0
RUN curl --silent --show-error --location --output /tmp/gh.tar.gz \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
  && tar xvfz /tmp/gh.tar.gz -C /tmp \
  && mv /tmp/gh_${GH_VERSION}_linux_amd64/bin/gh /usr/local/bin/gh \
  && chmod a+x /usr/local/bin/gh \
  && gh --help

ARG AZURE_CLI_VERSION=2.0.59
## Always install the latest package and pip versions
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
  && curl --silent --show-error --location https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
  && echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list \
  && apt-get update \
  && apt-get install --yes --no-install-recommends azure-cli="${AZURE_CLI_VERSION}-1~$(lsb_release -cs)" \
  && az --version \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## Repeating the ARGs from top level to allow them on this scope
ARG JX_RELEASE_VERSION=2.5.1
COPY --from=jx-release-version /usr/bin/jx-release-version /usr/bin/jx-release-version

## Install JDK11 to for the jenkins-agent (same JDK version as the controller)
ARG JDK11_VERSION=11.0.13+8
ARG JDK11_HOME=/opt/jdk-11
## Always install the latest packages
# hadolint ignore=DL3008
RUN apt-get update \
  ## Prevent Java null pointer exception due to missing fontconfig
  && apt-get install --yes --no-install-recommends fontconfig \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && mkdir -p "${JDK11_HOME}" \
  && jdk11_short_version="${JDK11_VERSION//+/_}" \
  && curl --silent --show-error --location --output /tmp/jdk11.tgz \
    "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${JDK11_VERSION}/OpenJDK11U-jdk_x64_linux_hotspot_${jdk11_short_version}.tar.gz" \
  && tar xzf /tmp/jdk11.tgz --strip-components=1 -C "${JDK11_HOME}" \
  && rm -f /tmp/jdk11.tgz \
  # Declare this installation to update-alternatives with the weight of its major version (so by default, most recent is the default unless changed later)
  && update-alternatives --install /usr/bin/java java "${JDK11_HOME}"/bin/java 11

ARG JDK8_VERSION="8u312-b07"
ARG JDK8_HOME=/opt/jdk-8
## Always install the latest packages
# hadolint ignore=DL3008
RUN apt-get update \
  ## Prevent Java null pointer exception due to missing fontconfig
  && apt-get install --yes --no-install-recommends fontconfig \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && mkdir -p "${JDK8_HOME}" \
  && jdk8_short_version="${JDK8_VERSION//-/}" \
  && curl --silent --show-error --location --output /tmp/jdk8.tgz \
    "https://github.com/adoptium/temurin8-binaries/releases/download/jdk${JDK8_VERSION}/OpenJDK8U-jdk_x64_linux_hotspot_${jdk8_short_version}.tar.gz" \
  && tar xzf /tmp/jdk8.tgz --strip-components=1 -C "${JDK8_HOME}" \
  && rm -f /tmp/jdk8.tgz \
  # Declare this installation to update-alternatives with the weight of its major version (so by default, most recent is the default unless changed later)
  && update-alternatives --install /usr/bin/java java "${JDK8_HOME}"/bin/java 8

## Define the default java to be used
ENV JAVA_HOME="${JDK8_HOME}"
## Use 1000 to be sure weight is always the bigger
RUN update-alternatives --install /usr/bin/java java "${JAVA_HOME}"/bin/java 1000 \
# Ensure JAVA_HOME variable is availabel to all shells
  && echo "JAVA_HOME=${JAVA_HOME}" >> /etc/environment \
  && java -version

## Maven is required for Debian packaging step (at least)
ARG MAVEN_VERSION=3.8.4
RUN curl --fail --silent --location --show-error --output "/tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
  "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
  && tar zxf "/tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -C /usr/share/ \
  && ln -s "/usr/share/apache-maven-${MAVEN_VERSION}/bin/mvn" /usr/local/bin/mvn \
  && rm -f "/tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
  && mvn -version

## We need some files from the official jenkins-agent image
COPY --from=jenkins-agent /usr/share/jenkins/agent.jar /usr/share/jenkins/agent.jar
COPY --from=jenkins-agent /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-agent

## Copy packaging-specific RPM macros
COPY ./conf.d/rpm_macros /etc/rpm/macros
COPY ./conf.d/devscripts.conf /etc/devscripts.conf

# Create default user (must be the same as the official jenkins-agent image)
ARG JENKINS_USERNAME=jenkins
ENV USER=${JENKINS_USERNAME}
ENV HOME=/home/"${JENKINS_USERNAME}"
RUN useradd -m -u 1000 "${JENKINS_USERNAME}"

USER $JENKINS_USERNAME

RUN mkdir "${HOME}"/.ssh \
  && ssh-keyscan -t rsa pkg.origin.jenkins.io >> "${HOME}"/.ssh/known_hosts

LABEL io.jenkins-infra.tools="createrepo,bash,debhelper,fakeroot,git,gpg,gh,jx-release-version,java,jv,jenkins-agent,make"
LABEL io.jenkins-infra.tools.gh.version="${GH_VERSION}"
LABEL io.jenkins-infra.tools.jx-release-version.version="${JX_RELEASE_VERSION}"
LABEL io.jenkins-infra.tools.jenkins-agent.version="${JENKINS_AGENT_VERSION}"
LABEL io.jenkins-infra.tools.java.version="${JDK11_VERSION}"
LABEL io.jenkins-infra.tools.jv.version="${JV_VERSION}"


ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
