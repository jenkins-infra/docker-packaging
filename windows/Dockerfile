ARG JENKINS_AGENT_VERSION=4.11.2-3

# https://github.com/jenkinsci/docker-agent/blob/master/11/windows/windowsservercore-ltsc2019/Dockerfile - base agent
# https://github.com/jenkinsci/docker-inbound-agent/blob/master/11/windows/windowsservercore-ltsc2019/Dockerfile - inbound agent (from base agent)
FROM jenkins/inbound-agent:${JENKINS_AGENT_VERSION}-jdk11-nanoserver-1809 AS jenkins-agent

FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019 as dotnet
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Copy JDK installation
COPY --from=jenkins-agent C:/openjdk-11 C:/openjdk-11
ENV JAVA_HOME C:\openjdk-11

# Copy Git tooling
COPY --from=jenkins-agent c:/mingit c:/mingit
# Ensure that git LFS is installed correctly
RUN  C:\mingit\cmd\git.exe lfs install; \
    $CurrentPath = (Get-Itemproperty -path 'hklm:\system\currentcontrolset\control\session manager\environment' -Name Path).Path ; \
    $NewPath = $CurrentPath + ';C:\mingit\cmd' ; \
    Set-ItemProperty -path 'hklm:\system\currentcontrolset\control\session manager\environment' -Name Path -Value $NewPath

# Define default user for Jenkins Agent usage
ARG user=jenkins

RUN net accounts /maxpwage:unlimited ; \
    net user "$env:user" /add /expire:never /passwordreq:no ; \
    net localgroup Administrators /add $env:user ; \
    Set-LocalUser -Name $env:user -PasswordNeverExpires 1; \
    New-Item -ItemType Directory -Path C:/ProgramData/Jenkins | Out-Null

# Get Agent JAR and scripts
COPY --from=jenkins-agent C:/ProgramData/Jenkins C:/ProgramData/Jenkins
ARG AGENT_ROOT=C:/Users/$user
ARG AGENT_WORKDIR=${AGENT_ROOT}/Work

ENV AGENT_WORKDIR=${AGENT_WORKDIR}

USER $user

RUN New-Item -Type Directory $('{0}/.jenkins' -f $env:AGENT_ROOT) | Out-Null ; \
    New-Item -Type Directory $env:AGENT_WORKDIR | Out-Null

VOLUME ${AGENT_ROOT}/.jenkins
VOLUME ${AGENT_WORKDIR}
WORKDIR ${AGENT_ROOT}

ENTRYPOINT ["powershell.exe", "-f", "C:/ProgramData/Jenkins/jenkins-agent.ps1"]
