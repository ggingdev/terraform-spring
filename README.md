# SpoonLabs DevOps Engineer 과제

## 개요

AWS Cloud를 활용한 Kubernetes 클러스터 구축 및 프라이빗 서브넷 내부 pod 접근을 위한 로드밸런서 세팅

---

## 리소스 구성

### 1. VPC

- 리전 내 2개 가용영역
- 각 가용영역에 퍼블릭/프라이빗 서브넷 구성
- 2개 가용영역 내 퍼블릿 서브넷에 NAT 게이트웨이 구성

### 2. EKS

- 프라이빗 서브넷에 관리형 노드 그룹 2개 생성
- 각 노드 그룹 내 2개 목표 노드 설정

### 3. 보안 그룹(ALB)

- ALB 외부 통신을 위한 80, 8080 포트 인그레스 허용 규칙 설정  

### 4. ALB

- 2개 퍼블릭 서브넷과 통신 설정
- 각 노드의 8080(HTTP) 포트를 대상그룹으로 설정
- `/api/users` 에 대한 헬스체크 수행 및 요청에 대한 정상 응답 코드 2XX 설정
- EKS의 노드 그룹의 오토스케일링 그룹을 ALB 대상그룹에 연결

### 5. 보안 그룹 규칙(EKS)

- 노드그룹에 8080 포트 인그레스 허용 규칙 설정
- ALB를 통한 인그레스 트래픽에 한해서 허용 규칙 설정

---

## 구현 조건 별 적용 방법

### 1. AWS의 모든 자원은 Terraform으로 구성

- 조건
  - Terraform registry의 공식 Module을 사용

    ```terraform
    # main.tf

    module "vpc" {
    ...
    }
    
    module "eks" {
    ...
    }
    ```

### 2. 네트워크 구성(문항 내 다이어그램)

- 조건
  - Public Subnet은 ALB와 인터넷 게이트웨이 연결을 위함

    ```terraform
    # main.tf

    resource "aws_lb" "eks_alb" {
      ...
      subnets            = module.vpc.public_subnets
      ...
    }
    ```

    > ALB에 2개 퍼블릭 서브넷 할당

  - Private Subnet은 EC2와 같은 리소스가 NAT를 통해 외부 통신하는 용도
  - Private Subnet에서 외부 통신 시 같은 Zone의 NAT를 이용

    ```terraform
    # main.tf
    
    module "vpc" {
      ...
      enable_nat_gateway     = true
      single_nat_gateway     = false
      one_nat_gateway_per_az = true
      ...
    }
    ```

    > NAT 게이트웨이(`enable_nat_gateway`) 활성화  
    > 가용 영역 별로 이원화된 서브넷에서 개별 NAT 게이트웨이로 통신하기 위해 `single_nat_gateway` 비활성화 및 `one_nat_gateway_per_az` 활성화
  
### 3. Amazon EKS의 관리형 노드는 각각의 Private Subnet에 위치

```terraform
# main.tf

module "eks" {
  ...
  eks_managed_node_groups = {
    private_ng_subnet_1 = {
      ...  
      subnet_ids = [module.vpc.private_subnets[0]]
      ...
    },

    private_ng_subnet_2 = {
      ...
      subnet_ids = [module.vpc.private_subnets[1]]
      ...
    }
  }
  ...
}
```

> 각 노드그룹에 서로 다른 가용영역의 프라이빗 서브넷 ID 할당

### 4. Deployment에 구성될 Pod는 Spring Boot 이미지로 제작하여 컨테이너 레지스트리에 업로드

```terraform
# deployment.tf

resource "kubernetes_deployment" "springboot_app" {
  metadata {
    name = "springboot"
    labels = {
      app = "springboot-app"
    }
  }
  ...
      spec {
        container {
          name  = "springboot"
          image = "ggingdev/springboot:latest"
          ...
        }
...
}
```

> `./springboot-docker` 내의 Spring Boot 앱 이미지 빌드 및 Docker Hub 푸쉬  
> `ggingdev/springboot:latest` 이미지 실행

### 5. 만들어진 이미지는 affinity 옵션을 통하여 Private Subnet에 전개된 노드에 위치

```terraform
# deployment.tf

resource "kubernetes_deployment" "springboot_app" {
  ...
  spec {
    ...
    template {
      ...
      spec {
        ...
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "subnet-type"
                  operator = "In"
                  values   = ["private"]
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [module.eks]
}
```

> `required_during_scheduling_ignored_during_execution` 를 통한 affinity 적용  
> `subnet-type=private` 라벨이 적용된 노드에 affinity 적용

### 6. Application Load Balancer는 인터넷으로 접근이 가능하며 구성된 Pod로 라우팅

```terraform
# main.tf

resource "aws_lb" "eks_alb" {
  ...
  subnets            = module.vpc.public_subnets
  ...
}
```

> 인터넷 접근을 위해 퍼블릭 서브넷에 위치

```terraform
# main.tf

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
```

> 80, 8080 포트 인바운드 트래픽을 대상그룹으로 라우팅

```terraform
# main.tf

resource "aws_security_group_rule" "eks_nodes_ingress_8080" {
  description              = "Allow ALB to access pods on 8080"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.alb_sg.id
  type                     = "ingress"
}
```

> 8080 포트로 서비스 되는 Spring Boot 앱에 접근하기 위해 EKS 노드 보안그룹에 8080 포트 인바운드 규칙 허용
