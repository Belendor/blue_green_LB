output "av_zones" {
  description = "Availabily zones"
  value       = data.aws_availability_zones.available.names
}
