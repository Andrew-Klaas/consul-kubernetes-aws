
variable "cluster_name" {
  description = "Name of Consul cluster"
  default     = "stenio-consul-cluster"
}
variable "ami_id" {
  description = "Ami containing Consul binary"
  default     = "ami-0f07aa5439b49a298"
}
variable "aws_org_id" {
  description = "org id as present in the arn"
  default     = "753646501470"
}
variable "aws_user_name" {
  description = "user name of the AWS account that will connect to EKS Kubernetes"
  default     = "stenio"
}

variable "num_servers" {
  description = "Name of an existing ssh key to associate with instances"
  default     = "3"
}
variable "num_clients" {
  description = "How many Consul clients to deploy"
  default     = "1"
}
variable "ssh_key_name" {
  description = "Name of an existing ssh key to associate with instances"
  default     = "stenio-aws"
}
variable "cluster_tag_key" {
  description = "Name of an existing ssh key to associate with instances"
  default     = "ConsulAutoJoinTag"
}

variable "owner" {
  description = "User responsible for this cloud environment, resources will be tagged with this"
  default = "Stenio Ferreira"
}

variable "ttl" {
  default     = 24
  description = "Tag indicating time to live for this cloud environment"
}


