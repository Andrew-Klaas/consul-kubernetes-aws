# Consul-Kubernetes-AWS
Demo of Consul - kubernetes integration using Helm and 

## TODO
- Ensure Consul instances get public ip/ load balancer

## Steps
### Packer
Create a Consul image using the repo https://github.com/hashicorp/terraform-aws-consul/tree/master/examples/consul-ami
```
clone repo
update config
packer build consul.json
```

### Terraform
- Update variables.tf with any desired custom values, including ami id
- Execute
```
terraform init
terraform plan
# If you agree with the plan and are ready to deploy,
terraform apply
```

### Deploy Helm
- Install aws-iam-authenticator and configure kubectl as described in
https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html
- Ensure helm/demo.values.yaml has correct values for your deployment
- Execute
```
cd helm
./install_helm.sh
./run_helm.sh
```