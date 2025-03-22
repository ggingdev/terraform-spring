variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
  default     = "test-cluster"
}

variable "cluster_version" {
  description = "Kubernetes 버전"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.21.0.0/16"
}

variable "azs" {
  description = "가용영역"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "private_subnets_cidr" {
  description = "프라이빗 서브넷 CIDR block"
  type        = list(string)
  default     = ["10.21.32.0/24", "10.21.33.0/24"]
}

variable "public_subnets_cidr" {
  description = "퍼블릭 서브넷 CIDR block"
  type        = list(string)
  default     = ["10.21.0.0/24", "10.21.1.0/24"]
}

variable "node_instance_type" {
  description = "노드 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "노드 그룹 내 목표 노드 수"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "노드 그룹 내 최소 목표 노드 수"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "노드 그룹 내 최대 목표 노드 수"
  type        = number
  default     = 5
}