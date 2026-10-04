pipeline {
    agent any
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        NEXUS_REGISTRY = '172.31.44.164:8082'
    }
    stages {
        stage('clean workspace') {
            steps {
                cleanWs()
            }
        }
        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/karris12/netflix-devsecops-deployment.git'
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
                    } catch(Exception e) {
                        input(message: "Are you sure to proceed?", ok: "Proceed")
                    }
                }
            }
        }
        stage('Docker Build Image') {
    steps {
        sh '''
            docker build --build-arg API_KEY=${TMDB_API_KEY} -t netflix .
        '''
    }
}
        stage("TRIVY") {
            steps {
                sh "trivy image netflix > trivyimage.txt"
                script {
                    input(message: "Are you sure to proceed?", ok: "Proceed")
                }
            }
        }
        stage('Push to Nexus') {
            steps {
                sh '''
                    echo "Docker endpoint: ${DOCKER_HOST:-default context}"
                    echo "Docker context: $(docker context show)"
                    REGISTRY_CONFIG="$(docker info --format '{{json .RegistryConfig.IndexConfigs}}')"
                    echo "Docker registry configuration: $REGISTRY_CONFIG"
                    case "$REGISTRY_CONFIG" in
                        *'"172.31.44.164:8082"'*) ;;
                        *)
                            echo "ERROR: Docker daemon is not configured to allow the HTTP Nexus registry at 172.31.44.164:8082."
                            echo "Configure insecure-registries on the Docker daemon host and restart that daemon."
                            exit 1
                            ;;
                    esac
                '''
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-docker-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASSWORD'
                )]) {
                    sh '''
                        set +x
                        printf '%s' "$NEXUS_PASSWORD" | \
                            docker login "$NEXUS_REGISTRY" \
                                --username "$NEXUS_USER" \
                                --password-stdin

                        docker tag netflix:latest "$NEXUS_REGISTRY/netflix:${BUILD_NUMBER}"
                        docker push "$NEXUS_REGISTRY/netflix:${BUILD_NUMBER}"
                        docker logout "$NEXUS_REGISTRY"
                    '''
                }
            }
        }
        stage("Docker Push") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {   
                        sh "docker tag netflix agodzo/netflix:latest"
                        sh "docker push agodzo/netflix:latest"
                    }
                }
            }
        }
    }
}