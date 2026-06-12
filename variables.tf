variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy identifier"
}

variable "user_ocid" {
  type        = string
  description = "OCI user identifier"
}

variable "fingerprint" {
  type        = string
  description = "OCI fingerprint for the key pair"
}

variable "region" {
  type        = string
  description = "OCI region"
}

variable "compartment" {
  type        = string
  description = "Compartment to test proof of concepts"
}

variable "public_cidr_block" {
  type        = string
  description = "Public IPV4 address"
}

variable "private_cidr_block" {
  type        = string
  description = "Private IPV4 address"
}

variable "vcn_cidr_block" {
  type        = string
  description = "IP subnet range of VCN"
}

variable "vcn_name" {
  type        = string
  description = "Virtual cloud network name"
}

variable "gateway_name" {
  type        = string
  description = "Internet gateway name"
}

variable "route_table_cidr" {
  type        = string
  description = "Internet gateway name"
}

variable "source_id" {
  type        = string
  description = "Source id image of compute instance"
}


variable "pub_key" {}

variable "pvt_key" {}

variable "dir" {}

variable "kms_ocid" {}