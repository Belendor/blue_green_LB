output "av_zones" {
  description = "Availabily zones"
  value       = data.aws_availability_zones.available.names
}

output "puublic_ec2_ips" {
  value = [
    for instance in module.ec2_instance :  join("", ["http://", instance.public_ip])
  ]
}