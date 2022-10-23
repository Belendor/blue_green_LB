output "av_zones" {
  description = "Availabily zones"
  value       = data.aws_availability_zones.available.names
}

output "public_ec2_ips" {
  value = [
    for instance in module.ec2_instance :  join("", ["http://", instance.public_ip])
  ]
}

output "elb_dns" {
  description = "DNS name of Load Balancer"
  value = "http://${module.elb.elb_dns_name}"
}