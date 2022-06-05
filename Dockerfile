ARG JX_RELEASE_VERSION=2.5.1
ARG JENKINS_AGENT_VERSION=4.13-2

FROM ghcr.io/jenkins-x/jx-release-version:${JX_RELEASE_VERSION} AS jx-release-version
FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-jdk11 AS jenkins-agent

FROM ubuntu:22.04
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
LABEL project="https://github.com/jenkins-infra/docker-packaging"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG C.UTF-8

## Always install the latest package and pip versions
## TODO: Remove the "ln -s /usr/bin/createrepo_c /usr/bin/createrepo" call
## below once all consumers have been migrated from "createrepo" to
## "createrepo_c".
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    apt-utils \
    createrepo-c \
    curl \
    build-essential \
    debhelper \
    devscripts \
    expect \
    fakeroot \
    git \
    gpg \
    gpg-agent \
    gnupg2 \
    make \
    openssh-server \
    openssl \
    python3-pip \
    python3-pytest \
    python3-venv \
    rpm \
    rsync \
    tzdata \
    unzip \
  && ln -s /usr/bin/createrepo_c /usr/bin/createrepo \
  && apt-get clean \
  && pip3 install --no-cache-dir jinja2 \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG JV_VERSION=0.2.0
RUN curl -o "jenkins-version-linux-$(dpkg --print-architecture).tar.gz" -L "https://github.com/jenkins-infra/jenkins-version/releases/download/${JV_VERSION}/jenkins-version-linux-$(dpkg --print-architecture).tar.gz" && \
  tar xvfz "jenkins-version-linux-$(dpkg --print-architecture).tar.gz" && \
  mv jv /usr/local/bin && \
  rm "jenkins-version-linux-$(dpkg --print-architecture).tar.gz" && \
  jv --version

ARG GH_VERSION=2.11.3
RUN curl --silent --show-error --location --output /tmp/gh.tar.gz \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_$(dpkg --print-architecture).tar.gz" \
  && tar xvfz /tmp/gh.tar.gz -C /tmp \
  && mv "/tmp/gh_${GH_VERSION}_linux_$(dpkg --print-architecture)/bin/gh" /usr/local/bin/gh \
  && chmod a+x /usr/local/bin/gh \
  && gh --help

ARG AZURE_CLI_VERSION=2.37.0
## Always install the latest package and pip versions
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    libffi-dev \
    libsodium-dev \
    python3-dev \
  && SODIUM_INSTALL="system" python3 -m pip install --no-cache-dir pynacl \
  # switch back to the package manager version once https://github.com/Azure/azure-cli/issues/7368 is resolved
  && python3 -m pip install --no-cache-dir azure-cli=="${AZURE_CLI_VERSION}" \
  && az --version \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## Repeating the ARGs from top level to allow them on this scope
ARG JX_RELEASE_VERSION=2.5.1
COPY --from=jx-release-version /usr/bin/jx-release-version /usr/bin/jx-release-version

## Always install the latest packages
# hadolint ignore=DL3008
RUN apt-get update \
  ## Prevent Java null pointer exception due to missing fontconfig
  && apt-get install --yes --no-install-recommends fontconfig \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH "${JAVA_HOME}/bin:${PATH}"
COPY --from=jenkins-agent $JAVA_HOME $JAVA_HOME

## Use 1000 to be sure weight is always the bigger
RUN update-alternatives --install /usr/bin/java java "${JAVA_HOME}"/bin/java 1000 \
# Ensure JAVA_HOME variable is availabel to all shells
  && echo "JAVA_HOME=${JAVA_HOME}" >> /etc/environment \
  && echo "PATH=${JAVA_HOME}/bin:$PATH" >> /etc/environment \
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
COPY ./macros.d /usr/lib/rpm/macros.d

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
LABEL io.jenkins-infra.tools.jv.version="${JV_VERSION}"


ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
