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
                        echo "🔍 PR #${env.CHANGE_ID} detected → Project: ${env.SONAR_PROJECT_KEY}"
                    } else {
                        env.SONAR_PROJECT_KEY = 'commons-lang-main'
                        env.IS_PR = 'false'
                        echo "📌 Main branch → Project: ${env.SONAR_PROJECT_KEY}"
                    }
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
                sh 'echo "Branch: ${GIT_BRANCH}"'
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    mvn clean verify -DskipITs
                '''
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

        stage('Quality Gate') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    script {
                        sh 'sleep 5'
                        def qgStatus = sh(
                            script: '''
                                curl -s -u ${SONAR_TOKEN}: \
                                    "${SONAR_HOST}/api/qualitygates/project_status?projectKey=${SONAR_PROJECT_KEY}" \
                                    | grep -o '"status":"[^"]*"' | cut -d'"' -f4
                            ''',
                            returnStdout: true
                        ).trim()
                        
                        echo "Quality Gate Status: ${qgStatus}"
                        
                        if (qgStatus == 'ERROR') {
                            currentBuild.result = 'UNSTABLE'
                        }
                    }
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
