output "dns_zone_id" {
  value       = aws_route53_zone.private.zone_id
  description = "Zone ID of the Route53 Private Hosted Zone"
}

output "dns_db_fqdn" {
  value       = aws_route53_record.db.fqdn
  description = "Fully Qualified Domain Name of the private DB record"
}
