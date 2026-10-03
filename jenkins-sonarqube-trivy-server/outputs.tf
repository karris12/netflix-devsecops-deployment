output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.eip.public_ip
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = module.ec2_instance.id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = module.sg.id
}

output "jenkins_url" {
  description = "Jenkins Access URL"
  value       = "http://${aws_eip.eip.public_ip}:8080"
}

output "sonarqube_url" {
  description = "SonarQube Access URL"
  value       = "http://${aws_eip.eip.public_ip}:9000"
}
