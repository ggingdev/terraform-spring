module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.19.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets_cidr
  public_subnets  = var.public_subnets_cidr

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
  }

  tags = {
    Terraform = "true"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.21"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    disk_size      = 50
    instance_types = [var.node_instance_type]
  }

  eks_managed_node_groups = {
    private_ng_subnet_1 = {
      name = "private-ng-subnet-1"

      min_size     = 1
      max_size     = 3
      desired_size = 2

      subnet_ids = [module.vpc.private_subnets[0]]

      capacity_type = "ON_DEMAND"

      labels = {
        "subnet-type"   = "private"
        "node-location" = "private-subnet-1"
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
        "subnet-group"                                  = "private-subnet-1"
      }
    },

    private_ng_subnet_2 = {
      name = "private-ng-subnet-2"

      min_size     = 1
      max_size     = 3
      desired_size = 2

      subnet_ids = [module.vpc.private_subnets[1]]

      capacity_type = "ON_DEMAND"

      labels = {
        "subnet-type"   = "private"
        "node-location" = "private-subnet-2"
      }

      tags = {
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
        "subnet-group"                                  = "private-subnet-2"
      }
    }
  }

  manage_aws_auth_configmap = true

  tags = {
    Terraform = "true"
  }
}

resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "8080 port from anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.cluster_name}-alb-sg"
    Terraform = "true"
  }
}

resource "aws_lb" "eks_alb" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Terraform = "true"
  }
}

resource "aws_lb_target_group" "eks_tg_8080" {
  name        = "${var.cluster_name}-tg-8080"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    enabled             = true
    interval            = 30
    path                = "/api/users"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200-299"
  }

  tags = {
    Terraform = "true"
  }
}

resource "aws_lb_listener" "eks_listener_80" {
  load_balancer_arn = aws_lb.eks_alb.arn
  port              = "80"
  protocol          = "HTTP"
  depends_on        = [aws_lb_target_group.eks_tg_8080]

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_tg_8080.arn
  }
}

resource "aws_lb_listener" "eks_listener_8080" {
  load_balancer_arn = aws_lb.eks_alb.arn
  port              = "8080"
  protocol          = "HTTP"
  depends_on        = [aws_lb_target_group.eks_tg_8080]

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_tg_8080.arn
  }
}

resource "aws_security_group_rule" "eks_nodes_ingress_8080" {
  description              = "Allow ALB to access pods on 8080"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.alb_sg.id
  type                     = "ingress"
}

data "aws_autoscaling_groups" "ng_subnet_1" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }

  filter {
    name   = "tag:eks:nodegroup-name"
    values = ["private-ng-subnet-1"]
  }

  depends_on = [module.eks]
}

data "aws_autoscaling_groups" "ng_subnet_2" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }

  filter {
    name   = "tag:eks:nodegroup-name"
    values = ["private-ng-subnet-2"]
  }

  depends_on = [module.eks]
}

resource "aws_autoscaling_attachment" "ng_subnet_1_attachment" {
  autoscaling_group_name = module.eks.eks_managed_node_groups["private_ng_subnet_1"].node_group_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.eks_tg_8080.arn
}

resource "aws_autoscaling_attachment" "ng_subnet_2_attachment" {
  autoscaling_group_name = module.eks.eks_managed_node_groups["private_ng_subnet_2"].node_group_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.eks_tg_8080.arn
}
