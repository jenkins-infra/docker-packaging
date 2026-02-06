ARG JENKINS_AGENT_VERSION=3355.v388858a_47b_33-9
ARG JAVA_VERSION=21.0.10_7
ARG JENKINS_AGENT_JDK_MAJOR=21
ARG BUILD_JDK_MAJOR=21

FROM eclipse-temurin:${JAVA_VERSION}-jdk-jammy AS jdk
FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-jdk${JENKINS_AGENT_JDK_MAJOR} AS jenkins-agent

FROM ubuntu:24.04
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]
LABEL project="https://github.com/jenkins-infra/docker-packaging"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8

## Always install the latest package versions
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    apt-utils \
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
    python3-jinja2 \
    python3-pytest \
    python3-venv \
    rpm `# Required to build RPMs` \
    createrepo-c `# Required to build RPMs` \
    rsync \
    tzdata \
    unzip \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && ln -s /usr/bin/createrepo_c /usr/bin/createrepo

ARG JV_VERSION=0.11.4
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

ARG JX_RELEASE_VERSION=2.5.2
RUN curl --silent --show-error --location --output /tmp/jx-release-version.tar.gz \
    "https://github.com/jenkins-x-plugins/jx-release-version/releases/download/v${JX_RELEASE_VERSION}/jx-release-version-linux-$(dpkg --print-architecture).tar.gz" \
  && tar xvfz /tmp/jx-release-version.tar.gz -C /tmp \
  && mv "/tmp/jx-release-version" /usr/bin/ \
  && chmod a+x /usr/bin/jx-release-version \
  && jx-release-version --help

ARG AZURE_CLI_VERSION=2.62.0
## Always install the latest package versions
# hadolint ignore=DL3008,DL3013
RUN apt-get update \
  && apt-get install --yes --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
  && curl --silent --show-error --location https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null \
  && echo "deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list \
  && apt-get update \
  && apt-get install --yes --no-install-recommends azure-cli="${AZURE_CLI_VERSION}-1~$(lsb_release -cs)" \
  && az --version \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## Install azcopy
ARG AZCOPY_VERSION=10.31.1
RUN ARCH="$(uname -m)"; \
    case "${ARCH}" in \
        aarch64|arm64) \
            azcopy_arch="arm64"; \
            ;; \
        amd64|x86_64) \
            azcopy_arch="x86_64"; \
            ;; \
        *) \
            echo "Unsupported arch: ${ARCH}"; \
            exit 1; \
            ;; \
    esac; \
    azcopy_pkg="$(mktemp)" \
    && curl --silent --show-error --location --output "${azcopy_pkg}" "https://github.com/Azure/azure-storage-azcopy/releases/download/v${AZCOPY_VERSION}/azcopy-${AZCOPY_VERSION}.${azcopy_arch}.deb" \
    && dpkg --install "${azcopy_pkg}" \
    # Sanity check
    && azcopy --version \
    # Cleanup
    && rm -f "${azcopy_pkg}"

## Always install the latest packages
# hadolint ignore=DL3008
RUN apt-get update \
  ## Prevent Java null pointer exception due to missing fontconfig
  && apt-get install --yes --no-install-recommends fontconfig \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Repeat ARG to scope it in this stage
ARG BUILD_JDK_MAJOR=21
ENV JAVA_HOME=/opt/jdk-"${BUILD_JDK_MAJOR}"
ENV PATH="${JAVA_HOME}/bin:${PATH}"

## Note: when using the same major versions, the temurin JDK overrides the agent JDK.
##    We need to keep this behavior as both JDK can differ. The long term solution is to switch this image to the "all in one".
# Repeat ARG to scope it in this stage
ARG JENKINS_AGENT_JDK_MAJOR=21
COPY --from=jenkins-agent /opt/java/openjdk /opt/jdk-"${JENKINS_AGENT_JDK_MAJOR}"
COPY --from=jdk /opt/java/openjdk ${JAVA_HOME}

## Use 1000 to be sure weight is always the bigger
RUN update-alternatives --install /usr/bin/java java "${JAVA_HOME}"/bin/java 1000 \
# Ensure JAVA_HOME variable is availabel to all shells
  && echo "JAVA_HOME=${JAVA_HOME}" >> /etc/environment \
  && echo "PATH=${JAVA_HOME}/bin:$PATH" >> /etc/environment \
  && java -version

## Maven is required for Debian packaging step (at least)
ARG MAVEN_VERSION=3.9.12
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
RUN deluser ubuntu && useradd -m -u 1000 "${JENKINS_USERNAME}"

USER $JENKINS_USERNAME

RUN git config --global pull.rebase false

ARG JENKINS_AGENT_VERSION=3355.v388858a_47b_33-9
LABEL io.jenkins-infra.tools="bash,debhelper,fakeroot,git,gpg,gh,jx-release-version,java,jv,jenkins-agent,make"
LABEL io.jenkins-infra.tools.gh.version="${GH_VERSION}"
LABEL io.jenkins-infra.tools.jx-release-version.version="${JX_RELEASE_VERSION}"
LABEL io.jenkins-infra.tools.jenkins-agent.version="${JENKINS_AGENT_VERSION}"
LABEL io.jenkins-infra.tools.jv.version="${JV_VERSION}"
LABEL io.jenkins-infra.tools.azcopy.version="${AZCOPY_VERSION}"

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
