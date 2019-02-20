# Consul-Kubernetes-AWS
Demo of Consul - EKS Kubernetes integration using Helm.

The steps required are:
- Create AWS ami using Packer
- Install aws-iam-authenticator to issue command to your EKS cluster
- Run Terraform to create Consul cluster and EKS cluster
- Terraform will also create a Consul client with the [payment](https://github.com/emojify-app/payments/) service app installed and registered to Consul cluster
- Use kubectl from your desktop to install tiller, Helm and the Consul connectivity
- Deploy demo app using microservices from inside and outside your EKS Kubernetes cluster

## Demo Overview
Steps for demo:
1. Terraform will create a Consul cluster with one client, and an EKS Kubernetes cluster
2. From your desktop, install helm and deploy consul-helm. Now your Kubernetes cluster has joined the Consul cluster
3. Deploy the emojify app in Kubernetes.

## Requirements
- [Packer](https://www.packer.io/intro/getting-started/install.html)
- [Terraform](https://learn.hashicorp.com/terraform/getting-started/install.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
- [aws cli (latest version)](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
- [A free account on machinebox](https://machinebox.io/)

## Steps
### Packer
Create a Consul image:
- Run aws login or et environment vars  
```
export AWS_ACCESS_KEY_ID=[your key id]
export AWS_SECRET_ACCESS_KEY=[your access key]
```
- Update packer/vars.json.example. If you want to use Consul open source, set the version. If you want to use Enterprise, set the environment variable CONSUL_DOWNLOAD_URL
- Execute
```
packer build -var-file=vars.json packer.json
```

### Terraform
- Update variables.tf with any desired custom values, in particular:
```
. ami id of the packer image you created
. aws_org: id of your AWS org
. aws_user_name: your aws user name
. ssh_key_name: ensure you have an existing ec2 key in aws. If not instructions on how to create [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
```
- Ensure aws-iam-authenticator binary is accessible from PATH
- Execute
```
terraform init
terraform plan
# If you agree with the plan and are ready to deploy,
terraform apply
```
- This will create a kubeconfig file, that will be used to connect remotely to the EKS Kubernetes cluster
- Verify you can connect to Consul UI by copying one of the IPs in the "consul-public-ips" output and going to port 8500
```
http://PUBLIC-IP:8500
```

### Deploy Helm
- Configure kubectl:
```
# Enter the path to the kubeconfig file created in the terraform folder:
export KUBECONFIG=PATH/TO/kubeconfig_stenio-eks-cluster
# validate it can find remote
kubectl get svc
# Output:
# NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
# kubernetes   ClusterIP   172.20.0.1   <none>        443/TCP   6m
```
- Update helm/demo.values.yaml to match your Consul datacenter name and Consul Auto-Join tag key and value
- Execute
```
cd ../helm
./install_helm.sh
./run_helm.sh
```

### Emojify
- Create free account on [Machine Box](https://machinebox.io/)
- Copy your API keys in the files emojify-k8s-connect-demo/emojify/facebox.yml, emojify-k8s-connect-demo/emojify-connect/facebox.yml, emojify-k8s-connect-demo/emojify-enterprise/facebox.yml
under "MB_KEY"

### Demo
#### Show emojify app, within Kubernetes
- Go to Consul server public IP, port 8500
- Ensure kubernetes is listed
- Deploy app
- Execute commands, following [Jason Harley's webinar](https://www.hashicorp.com/resources/running-consul-kubernetes-beyond)
```
cd ../emojify-k8s-connect-demo
kubectl apply -f ./emojify
kubectl get svc
kubectl describe svc emojify-ingress | awk -F\: '/LoadBalancer Ingress/ {gsub(/ /, "", $0); print $2}'

Image example: https://www.irishexaminer.com/remote/snappa.static.pressassociation.io/assets/2014/12/05100314/1417773793-16b42d184fe6d4dc27f5abf844e783c2-1038x576.jpg?width=600
```
#### Show emojify app, connecting to payments app outside kubernetes
- Ensure payments app is running in the consul client
```
ssh -i PATH-TO-YOUR-PEM-KEY ubutu@PRIVATEIP
sudo systemctl start payment.service
sudo systemctl start payment-proxy.service
consul services register /etc/consul.d/payment-service.json


tree emojify-connect
# The diff will show what changes required to enable connect. You will see that instead of relying on public ip address, now it is pointing to internal address. This is to leverage the proxy, which will manage the connections using secure TLS.
git diff --no-index -- emojify/api.yml emojify-connect/api.yml
kubectl apply -f ./emojify-connect
# If app fails, ensure intentions are allowed

# Now let's enable the payments app and update emojify to use it
ssh -i YOUR-AWS-KEY ubuntu@IP-CONSUL-CLIENT
# Register payments service in Consul
consul services register /etc/consul.d/payment-service.json
# Start payments service and proxy
sudo systemctl start payment.service
sudo systemctl start payment-proxy.service
exit
# Now, back to emojify. The diff shows what changes needed to enable payments
git diff --no-index -- emojify-connect/api.yml emojify-enterprise/api.yml
kubectl apply -f ./emojify-enterprise
```