#!/bin/bash
local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
hostname="$(curl -s http://169.254.169.254/latest/meta-data/hostname)"
short_hostname=$(echo "$${hostname}" | awk -F '[.:]' '{print $1}')

#Add localhost to /etc/resolv.conf to resolve dns
#sudo sed -i '1s/^/nameserver 127.0.0.1\n/' /etc/resolv.conf

#add hostname to /etc/hosts
#sudo echo "127.0.0.1 $${hostname}" | sudo tee --append /etc/hosts
# Required because Amazon https://stackoverflow.com/questions/33441873/aws-error-sudo-unable-to-resolve-host-ip-10-0-xx-xx
sudo echo "$${local_ipv4} $${short_hostname}" | sudo tee --append /etc/hosts

echo "[---payments setup begin---]"

sudo apt-get update -qq
sudo apt-get install -y default-jdk unzip curl

# Provision payments service
mkdir /app
sudo chmod a+rwx /app
cd /app
wget https://github.com/emojify-app/payments/releases/download/v${payments_version}/spring-boot-payments-${payments_version}.jar

echo "Copy systemd services"

sudo tee /etc/systemd/system/payment.service > /dev/null <<"EOF"
  [Unit]
  Description = "Payments Service"
  
  [Service]
  KillSignal=INT
  ExecStart=/usr/bin/java -jar /app/spring-boot-payments-${payments_version}.jar
  Restart=on-failure
EOF

sudo systemctl enable payment.service
sudo systemctl add-wants multi-user.target payment.service

# Register the service with consul
sudo mkdir /etc/consul.d
sudo tee /etc/consul.d/payment-service.json > /dev/null <<"EOF"
{
  "service": {
    "name": "payment",
    "port": 8080,
    "check": {
      "id": "payment-check",
      "name": "Payment Health Check",
      "http": "http://localhost:8080/health",
      "interval": "10s",
      "timeout": "1s"
    },
    "connect": {
      "sidecar_service": {}
    }
  }
}
EOF

# Add the consul connect proxy
sudo tee /etc/systemd/system/payment-proxy.service > /dev/null <<"EOF"
  [Unit]
  Description = "Consul Connect Sidecar Proxy for Payment"
  
  [Service]
  KillSignal=INT
  ExecStart=/usr/local/bin/consul connect proxy -sidecar-for=payment
  Restart=on-failure
EOF

sudo systemctl enable payment-proxy.service
sudo systemctl add-wants multi-user.target payment-proxy.service

sudo systemctl start payment.service
sudo systemctl start payment-proxy.service

consul services register /etc/consul.d/payment-service.json

echo "[---creating Consul intentions---]"
consul intention create -deny emojify-api emojify-facebox
consul intention create -deny emojify-api payment
consul intention create -deny emojify-ingress emojify-api
consul intention create -deny emojify-ingress emojify-website

echo "[---payments setup complete---]"