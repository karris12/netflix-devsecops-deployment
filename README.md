# Deploying a Netflix Clone on Kubernetes using DevSecOps methodology

In this project we would be deploying Netflix Clone application on an EKS cluster using DevSecOps methodology. We would be making use of security tools like SonarQube, OWASP Dependency Check and Trivy.
We would also be monitoring our EKS cluster using monitoring tools like Prometheus and Grafana. Most importantly we will be using ArgoCD for the Deployment.

## Step 1: Launch an EC2 Instance and install Jenkins, SonarQube, Docker and Trivy

We would be making use of Terraform to launch the EC2 instance. We would be adding a script as userdata for the installation of Jenkins, SonarQube, Trivy and Docker. 

## Step 2: Access Jenkins at port 8080 and install required plugins

Install the following plugins:

1. NodeJS 
2. Eclipse Temurin Installer
3. SonarQube Scanner
4. OWASP Dependency Check
5. Docker
6. Docker Commons
7. Docker Pipeline
8. Docker API
9. docker-build-step

## Step 3: Set up SonarQube

For the SonarQube Configuration, first access the Sonarqube Dashboard using the url http://elastic_ip:9000

1. Create the token 
Administration -> Security -> Users -> Create a token 

2. Add this token as a credential in Jenkins 

3. Go to Manage Jenkins -> System -> SonarQube installation 
Add URL of SonarQube and for the credential select the one added in step 2.

4. Go to Manage Jenkins -> Tools -> SonarQube Scanner Installations
-> Install automatically.

### SonarQube version and upgrades

The EC2 install script deploys SonarQube Community Build `26.9.0.129388-community`, the latest Community Build image available on October 3, 2026. Community Build is released monthly; this pinned tag avoids an install silently changing between deployments. Update the image tag in `jenkins-sonarqube-trivy-server/userdata.sh` when choosing a later release.

The install script uses named Docker volumes for SonarQube data, extensions, and logs, and configures the host's `vm.max_map_count` setting. Keep these volumes when updating an installation.

**Do not apply a Terraform change to `userdata.sh` to upgrade an existing server without first backing it up and planning the supported SonarQube upgrade path.** The previous install script used `sonarqube:lts-community` without volumes, so its database and files are in the container's writable layer. Also, `user_data_replace_on_change = true` in the EC2 Terraform configuration means a user-data change replaces the EC2 instance. Back up and migrate the existing data through the required intermediate versions before replacing that instance or container. See SonarSource's [update path guidance](https://docs.sonarsource.com/sonarqube-community-build/server-update-and-maintenance/update/determine-path/) and [Docker update instructions](https://docs.sonarsource.com/sonarqube-community-build/server-update-and-maintenance/update/update/).

## Step 4: Set up OWASP Dependency Check 

1. Go to Manage Jenkins -> Tools -> Dependency-Check Installations
-> Install automatically
2. In Manage Jenkins -> Credentials, add a **Secret text** credential containing your NVD API key with the ID `owasp-nvd-api-key`. The pipeline references this credential; do not put the key directly in the Jenkinsfile.

## Step 5: Set up Docker for Jenkins

1. Go to Manage Jenkins -> Tools -> Docker Installations -> Install automatically

2. And then go to Manage Jenkins -> Credentials -> System -> Global Credentials -> Add credentials. Add username and password for the docker registry (You need to create an account on Dockerhub). 
3. Add the TMDB API key as a **Secret text** credential with ID `tmdb-api-key`. The pipeline checks out the application repository (`gauri17-pro/nextflix`), which contains the `package.json` and Dockerfile required for the Docker build.

## Step 6: Create a pipeline in order to build and push the dockerized image securely using multiple security tools

Go to Dashboard -> New Item -> Pipeline 

Use the code below for the Jenkins pipeline. 

```bash
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
                        test -s app/package.json || {
                            echo "ERROR: app/package.json is missing."
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
        stage("TRIVY"){
            steps{
                sh "trivy image netflix > trivyimage.txt"
                script{
                    input(message: "Are you sure to proceed?", ok: "Proceed")
                }
            }
        }
        stage("Docker Push"){
            steps{
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
    ```

## Step 7: Create an EKS Cluster using Terraform 

Prerequisite: Install kubectl and helm before executing the commands below 

## Step 8: Deploy Prometheus and Grafana on EKS 

In order to access the cluster use the command below:

```
aws eks update-kubeconfig --name "Cluster-Name" --region "Region-of-operation"
```

1. We need to add the Helm Stable Charts for your local.

```bash
helm repo add stable https://charts.helm.sh/stable
```

2. Add prometheus Helm repo

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

3. Create Prometheus namespace

```bash
kubectl create namespace prometheus
```

4. Install kube-prometheus stack

```bash
helm install stable prometheus-community/kube-prometheus-stack -n prometheus
```

5. Edit the service and make it LoadBalancer

```
kubectl edit svc stable-kube-prometheus-sta-prometheus -n prometheus
```

6. Edit the grafana service too to change it to LoadBalancer

```
kubectl edit svc stable-grafana -n prometheus
```

## Step 9: Deploy ArgoCD on EKS to fetch the manifest files to the cluster

1. Create a namespace argocd
```
kubectl create namespace argocd
```

2. Add argocd repo locally
```
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
```

3. By default, argocd-server is not publically exposed. In this scenario, we will use a Load Balancer to make it usable:
```
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

4. We get the load balancer hostname using the command below:
```
kubectl get svc argocd-server -n argocd -o json
```

5. Once you get the load balancer hostname details, you can access the ArgoCD dashboard through it.

6. We need to enter the Username and Password for ArgoCD. The username will be admin by default. For the password, we need to run the command below:
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```


