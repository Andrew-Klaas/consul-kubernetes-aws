module "consul" {
  source  = "hashicorp/consul/aws"
  version = "0.5.0"
  vpc_id = "${module.vpc.vpc_id}"
  cluster_name = "stenio-consul"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "stenio-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
    Owner = "Stenio"
    TTL = "72"
  }
}

module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = "stenio-eks-cluster"
  subnets      = ["${concat(module.vpc.private_subnets, module.vpc.public_subnets)}"]
  vpc_id       = "${module.vpc.vpc_id}"
  worker_additional_security_group_ids = ["${module.consul.security_group_id_clients}", "${module.consul.security_group_id_servers}"]
  map_roles = [
    {
      role_arn = "arn:aws:iam::753646501470:group/Administrators"
      username = "admins"
      group    = "system:masters"
    },
  ]
  map_users = [
    {
      user_arn = "arn:aws:iam::753646501470:user/stenio"
      username = "stenio"
      group    = "system:masters"
    },
  ]
  tags = {
    Owner = "stenio"
    TTL   = "72"
  }
}
resource "aws_iam_policy" "albIngressControllerEksPolicy" {
  name_prefix = "albIngressControllerEksPolicyStenio"
  description = "ALB ingress controller eks policy"
  policy      = "${file("alb-iam-policy.json")}"
}
resource "aws_iam_role_policy_attachment" "albIngressControllerEksPolicyAttachment" {
  policy_arn = "${aws_iam_policy.albIngressControllerEksPolicy.arn}"
  role       = "${module.eks.worker_iam_role_name}"
}