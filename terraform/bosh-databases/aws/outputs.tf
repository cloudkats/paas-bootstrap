output "bosh_database_name" {
  value = "${postgresql_database.bosh.name}"
}

output "credhub_database_name" {
  value = "${postgresql_database.credhub.name}"
}