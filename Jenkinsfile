pipeline {
    agent any
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
    }
    stages {
        stage('clean workspace') {
            steps {
                cleanWs()
            }
        }
        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/gauri17-pro/nextflix.git'
            }
        }
        stage("Sonarqube Analysis") {
            steps {
                withSonarQubeEnv('sonar-server') {
                    sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Netflix \
                    -Dsonar.projectKey=Netflix'''
                }
            }
        }
        stage('OWASP FS SCAN') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'OWASP DP-Check', nvdCredentialsId: 'owasp-nvd-api-key'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('TRIVY FS SCAN') {
            steps {
                script {
                    try {
                        sh "trivy fs . > trivyfs.txt" 
                    }catch(Exception e){
                        input(message: "Are you sure to proceed?", ok: "Proceed")
                    }
                }
            }
        }
        stage("Docker Build Image"){
            steps{
                withCredentials([string(credentialsId: 'tmdb-api-key', variable: 'TMDB_API_KEY')]) {
                    sh '''
                        test -f package.json || {
                            echo "Docker build context must contain package.json"
                            exit 1
                        }
                        docker build --build-arg API_KEY="$TMDB_API_KEY" -t netflix .
                    '''
                }
            }
        }
        stage("TRIVY"){
            steps{
                sh "trivy image netflix > trivyimage.txt"
                script{
                    input(message: "Are you sure to proceed?", ok: "Proceed")
                }
            }
        }

        stage('Push to Nexus') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'nexus-docker-credentials',
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASSWORD'
        )]) {
            sh '''
                set +x
                printf '%s' "$NEXUS_PASSWORD" |
                    docker login localhost:8082 \
                        --username "$NEXUS_USER" \
                        --password-stdin

                docker tag netflix:latest localhost:8082/netflix:${BUILD_NUMBER}
                docker push localhost:8082/netflix:${BUILD_NUMBER}
                docker logout localhost:8082
            '''
        }
    }
}
        stage("Docker Push"){
            steps{
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker'){   
                    sh "docker tag netflix agodzo/netflix:latest "
                    sh "docker push agodzo/netflix:latest"
                    }
                }
            }
        }
    }
}