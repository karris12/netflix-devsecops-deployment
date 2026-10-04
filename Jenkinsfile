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
                dir('app') {
                    git branch: 'main', url: 'https://github.com/gauri17-pro/nextflix.git'
                }
            }
        }
        stage("Sonarqube Analysis") {
            steps {
                dir('app') {
                    withSonarQubeEnv('sonar-server') {
                        sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Netflix \
                        -Dsonar.projectKey=Netflix'''
                    }
                }
            }
        }
        stage('OWASP FS SCAN') {
            steps {
                dir('app') {
                    dependencyCheck additionalArguments: '--scan . --disableYarnAudit --disableNodeAudit', odcInstallation: 'OWASP DP-Check', nvdCredentialsId: 'owasp-nvd-api-key'
                }
                dependencyCheckPublisher pattern: 'app/dependency-check-report.xml'
            }
        }
        stage('TRIVY FS SCAN') {
            steps {
                script {
                    try {
                        sh "trivy fs app > trivyfs.txt"
                    } catch(Exception e) {
                        input(message: "Are you sure to proceed?", ok: "Proceed")
                    }
                }
            }
        }
        stage('Docker Build Image') {
            steps {
                withCredentials([string(credentialsId: 'tmdb-api-key', variable: 'TMDB_API_KEY')]) {
                    sh '''
                        test -s app/package.json || {
                            echo "ERROR: app/package.json is missing. Verify the application checkout in the Checkout from Git stage."
                            ls -la app
                            exit 1
                        }
                        test -f app/Dockerfile || {
                            echo "ERROR: app/Dockerfile is missing from the application checkout."
                            ls -la app
                            exit 1
                        }
                        docker build --build-arg API_KEY="$TMDB_API_KEY" \
                            --file app/Dockerfile \
                            --tag netflix:latest \
                            app
                    '''
                }
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
                    DOCKER_INFO="$(docker info)"
                    printf '%s\n' "$DOCKER_INFO" | sed -n '/Insecure Registries/,+8p'
                    if ! printf '%s\n' "$DOCKER_INFO" | grep -Fq "$NEXUS_REGISTRY"; then
                        echo "ERROR: Docker daemon is not configured to allow the HTTP Nexus registry at $NEXUS_REGISTRY."
                        echo "Configure insecure-registries on the Docker daemon host and restart that daemon."
                        exit 1
                    fi
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
                withCredentials([usernamePassword(
                    credentialsId: 'docker-cred',
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_PASSWORD'
                )]) {
                    sh '''
                        set +x
                        export DOCKER_CONFIG="$(mktemp -d)"
                        trap 'rm -rf "$DOCKER_CONFIG"' EXIT

                        printf '%s' "$DOCKERHUB_PASSWORD" |
                            docker login --username "$DOCKERHUB_USER" --password-stdin

                        docker tag netflix:latest agodzo/netflix:latest
                        docker push agodzo/netflix:latest
                        docker logout
                    '''
                }
            }
        }
    }
}
