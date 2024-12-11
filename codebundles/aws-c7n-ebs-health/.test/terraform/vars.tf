# Variables
variable "ebs_volume_name" {
  default = "ebs-test"
}

variable "ebs_volume_size" {
  default = 1
}

variable "region" {
  default = "us-west-2"
}

variable "availability_zone" {
  default = "us-west-2b"
}


variable "snapshot_volume_name" {
  default = "ebs-snapshot-test"
}

variable "snapshot_volume_size" {
  default = 1
}