output "consul-server-public-ips" {
  value = "${data.aws_instances.consul_servers.public_ips}"
}

output "consul-clients-public-ips" {
  value = "${data.aws_instances.consul_clients.public_ips}"
}