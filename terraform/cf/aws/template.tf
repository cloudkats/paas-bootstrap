provider "template" {}

data "template_file" "cloud_controller_policy" {
  template = "${file("${path.module}/templates/cloud_controller_policy.json")}"

  vars {
    environment              = "${var.environment}"
    cf_blobstore_kms_key_arn = "${aws_kms_key.cf-blobstore-key.arn}"
  }
}
