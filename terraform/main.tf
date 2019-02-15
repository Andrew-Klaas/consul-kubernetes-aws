# Terraform 0.9.5 suffered from https://github.com/hashicorp/terraform/issues/14399, which causes this template the
# conditionals in this template to fail.
terraform {
  required_version = ">= 0.9.3, != 0.9.5"
}

# Required to get the public ips of autoscaling group
# https://github.com/terraform-providers/terraform-provider-aws/issues/511
data "aws_instances" "consul_servers" {
  depends_on = [ "module.consul_servers" ]
  instance_tags {
    Name = "${var.cluster_name}-server"
  }
}
data "aws_instances" "consul_clients" {
  depends_on = [ "module.consul_clients" ]
  instance_tags {
    Name = "${var.cluster_name}-client"
  }
}
# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER NODES
# ---------------------------------------------------------------------------------------------------------------------
module "consul_servers" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.0.1"
  source = "./modules/consul-cluster"

  cluster_name  = "${var.cluster_name}-server"
  cluster_size  = "${var.num_servers}"
  instance_type = "t2.medium"

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = "${var.cluster_tag_key}"
  cluster_tag_value = "${var.cluster_name}"

  ami_id    = "${var.ami_id}"
  user_data = "${data.template_file.user_data_server.rendered}"

  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.public_subnets}"

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = "${var.ssh_key_name}"

  tags = [
    {
      key                 = "Environment"
      value               = "development"
      propagate_at_launch = true
    },
    {
      key                 = "Owner"
      value               = "${var.owner}"
      propagate_at_launch = true
    },
    {
      key                 = "TTL"
      value               = "${var.ttl}"
      propagate_at_launch = true
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL SERVER EC2 INSTANCE WHEN IT'S BOOTING
# This script will configure and start Consul
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data_server" {
  template = "${file("modules/consul-cluster/root-example/user-data-server.sh.tpl")}"

  vars {
    cluster_tag_key   = "${var.cluster_tag_key}"
    cluster_tag_value = "${var.cluster_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL CLIENT NODES
# Note that you do not have to use the consul-cluster module to deploy your clients. We do so simply because it
# provides a convenient way to deploy an Auto Scaling Group with the necessary IAM and security group permissions for
# Consul, but feel free to deploy those clients however you choose (e.g. a single EC2 Instance, a Docker cluster, etc).
# ---------------------------------------------------------------------------------------------------------------------

module "consul_clients" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.0.1"
  source = "./modules/consul-cluster"

  cluster_name  = "${var.cluster_name}-client"
  cluster_size  = "${var.num_clients}"
  instance_type = "t2.micro"

  cluster_tag_key   = "consul-clients"
  cluster_tag_value = "${var.cluster_name}"

  ami_id    = "${var.ami_id}"
  user_data = <<EOF
${data.template_file.user_data_client.rendered} # Install and configure Consul client
${data.template_file.payments_userdata.rendered} # Configure Payments Service
EOF

  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.public_subnets}"

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allowed_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = "${var.ssh_key_name}"

  tags = [
    {
      key                 = "Environment"
      value               = "development"
      propagate_at_launch = true
    },
    {
      key                 = "Owner"
      value               = "${var.owner}"
      propagate_at_launch = true
    },
    {
      key                 = "TTL"
      value               = "${var.ttl}"
      propagate_at_launch = true
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL CLIENT EC2 INSTANCE WHEN IT'S BOOTING
# This script will configure and start Consul
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data_client" {
  template = "${file("modules/consul-cluster/root-example/user-data-client.sh.tpl")}"

  vars {
    cluster_tag_key   = "${var.cluster_tag_key}"
    cluster_tag_value = "${var.cluster_name}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL CLIENT EC2 INSTANCE WHEN IT'S BOOTING
# This script will install the payments app and register it as a Consul service
# ---------------------------------------------------------------------------------------------------------------------
data "template_file" "payments_userdata" {
  template = "${file("modules/consul-cluster/root-example/payments-userdata.sh.tpl")}"

  vars {
    payments_version = "0.1.0"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Create VPC and subnets
# 
# ---------------------------------------------------------------------------------------------------------------------

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
    Owner = "${var.owner}"
    TTL   = "${var.ttl}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE EKS KUBERNETES CLUSTER
# This will also generate a file that can be used to login using kubectl. See README for details.
# ---------------------------------------------------------------------------------------------------------------------
module "eks" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_name = "${var.aws_user_name}-eks-cluster"
  subnets      = ["${concat(module.vpc.private_subnets, module.vpc.public_subnets)}"]
  vpc_id       = "${module.vpc.vpc_id}"
  worker_additional_security_group_ids = ["${module.consul_servers.security_group_id}", "${module.consul_clients.security_group_id}"]
  map_roles = [
    {
      role_arn = "arn:aws:iam::${var.aws_org_id}:group/Administrators"
      username = "admins"
      group    = "system:masters"
    },
  ]
  map_users = [
    {
      user_arn = "arn:aws:iam::${var.aws_org_id}:user/${var.aws_user_name}"
      username = "${var.aws_user_name}"
      group    = "system:masters"
    },
  ]
  tags = {
    Owner = "${var.owner}"
    TTL   = "${var.ttl}"
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