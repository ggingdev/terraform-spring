output "cluster_id" {
  description = "EKS 클러스터 ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "EKS 클러스터 보안그룹"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes 클러스터 이름"
  value       = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  description = "Kubernetes 클러스터 인증 정보"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "프라이빗 서브넷 ID"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "퍼블릿 서브넷 ID"
  value       = module.vpc.public_subnets
}

output "configure_kubectl" {
  description = "kubectl 명령어"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "alb_dns_name" {
  description = "ALB DNS 이름"
  value       = aws_lb.eks_alb.dns_name
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = module.vpc.igw_id
}

output "alb_8080_target_group_arn" {
  description = "대상그룹(8080) ARN"
  value       = aws_lb_target_group.eks_tg_8080.arn
}