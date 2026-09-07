pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
        timeout(time: 20, unit: 'MINUTES')
    }

    environment {
        SONAR_HOST = 'http://13.206.75.229:9000'
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    if (env.CHANGE_ID) {
                        env.SONAR_PROJECT_KEY = "commons-lang-pr-${env.CHANGE_ID}"
                        env.IS_PR = 'true'
                        echo "🔍 PR #${env.CHANGE_ID}"
                    } else {
                        env.SONAR_PROJECT_KEY = 'commons-lang-main'
                        env.IS_PR = 'false'
                        echo "📌 Main branch"
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Test') {
            steps {
                sh 'which mvn || echo "Maven not found, checking java..."'
                sh 'java -version'
                sh 'mvn --version'
                sh 'mvn clean verify -DskipITs'
            }
        }

        stage('SonarQube Scan') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        mvn sonar:sonar \
                            -Dsonar.host.url=${SONAR_HOST} \
                            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                            -Dsonar.projectName=commons-lang \
                            -Dsonar.login=${SONAR_TOKEN}
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
