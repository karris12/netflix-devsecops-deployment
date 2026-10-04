#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg docker.io openjdk-21-jre

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
chmod 644 /etc/apt/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list

curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
chmod 644 /etc/apt/keyrings/trivy.gpg
echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list

apt-get update -y
apt-get install -y jenkins trivy

trivy fs --scanners vuln,misconfig,secret --exit-code 0 --skip-dirs /proc,/sys,/dev,/run,/var/lib/docker / > /var/log/trivy-filesystem-scan.txt 2>&1 || echo "Trivy filesystem scan did not complete; see /var/log/trivy-filesystem-scan.txt"

usermod -aG docker ubuntu
usermod -aG docker jenkins
systemctl enable --now docker
systemctl enable jenkins
systemctl restart jenkins

docker run -d --name sonar --restart unless-stopped -p 9000:9000 sonarqube:lts-community

docker volume create nexus-data
docker run -d --name nexus --restart unless-stopped -p 8081:8081 -v nexus-data:/nexus-data -e 'INSTALL4J_ADD_VM_PARAMS=-Xms1536m -Xmx1536m -XX:MaxDirectMemorySize=1536m -Djava.util.prefs.userRoot=/nexus-data/javaprefs' sonatype/nexus3:latest



