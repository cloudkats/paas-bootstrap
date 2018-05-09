output "default_security_groups" {
  value = ["${aws_security_group.default.id}"]
}

output "internal_cidr" {
  value = "${aws_subnet.az1.cidr_block}"
}

output "internal_gw" {
  value = "${var.default_gw_ip}"
}

output "subnet_id" {
  value = "${aws_subnet.az1.id}"
}

output "az" {
  value = "${var.az1}"
}

output "region" {
  value = "${var.region}"
}

output "bosh_iam_instance_profile" {
  value = "${aws_iam_instance_profile.bosh.name}"
}

output "bosh_security_group_id" {
  value = "${aws_security_group.bosh.id}"
}