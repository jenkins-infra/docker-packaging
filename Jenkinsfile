pipeline {
  agent {
    label 'docker'
  }

  options {
    buildDiscarder logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '10')
    timeout(time: 1, unit: 'HOURS')
    timestamps()
  }

  triggers {
    pollSCM('H H * * 0')
  }

  stages {
    stage('Build') {
      steps {
          sh 'make build'
      }
    }
    stage('Publish'){
      when {
        environment name: 'JENKINS_URL', value: 'https://trusted.ci.jenkins.io:1443/'
      }
      steps {
        script {
          infra.withDockerCredentials {
            sh 'make publish'
          }
        }
      }
    }
  }
}

