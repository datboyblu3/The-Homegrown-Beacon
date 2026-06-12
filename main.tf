# Get secret from OCI Vault
data "oci_secrets_secretbundle" "passwd_vault"{
  secret_id = var.kms_ocid
}

locals {
    opc_new_password    = base64decode(data.oci_secrets_secretbundle.passwd_vault.secret_bundle_content.0.content)
}

resource "oci_core_vcn" "security_lab_vcn" {
  cidr_block     = var.vcn_cidr_block
  display_name   = "security-lab-vcn"
  compartment_id = var.compartment
}

resource "oci_core_internet_gateway" "security_lab_igw" {
  display_name   = var.gateway_name
  vcn_id         = oci_core_vcn.security_lab_vcn.id
  compartment_id = var.compartment
}

resource "oci_core_route_table" "security_lab_route_table" {
  vcn_id         = oci_core_vcn.security_lab_vcn.id
  compartment_id = var.compartment

  route_rules {
    destination       = var.route_table_cidr
    network_entity_id = oci_core_internet_gateway.security_lab_igw.id
  }
}

resource "oci_core_subnet" "security_lab_public_subnet" {
  vcn_id                     = oci_core_vcn.security_lab_vcn.id
  cidr_block                 = var.public_cidr_block
  display_name               = "security-lab-public-subnet"
  compartment_id             = var.compartment
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.security_lab_route_table.id
}

resource "oci_core_subnet" "security_lab_private_subnet" {
  vcn_id         = oci_core_vcn.security_lab_vcn.id
  cidr_block     = var.private_cidr_block
  display_name   = "security-lab-private-subnet"
  compartment_id = var.compartment
  route_table_id = oci_core_route_table.security_lab_route_table.id
}

resource "oci_core_security_list" "security_lab_fw" {
  display_name   = "security-lab-fw"
  compartment_id = var.compartment
  vcn_id         = oci_core_vcn.security_lab_vcn.id

  # Outbound Rules
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    description = "Allow all outbound traffic"
  }

  # Inbound Rules
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
    description = "Allow SSH traffic"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
    description = "Allow HTTP traffic"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
    description = "Allow HTTPS traffic"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 8888
      max = 8888
    }
    description = "Allow mTLS traffic"
  }

  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 53
      max = 53
    }
    description = "Allow inbound DNS traffic"
  }

  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    udp_options {
      min = 5555
      max = 5555
    }
    description = "Reverse and/or Bind shell to C2"
  }

  #Allow outbound connections for sliver beacon callbacks
  egress_security_rules {
    protocol    = "17" # UDP
    destination = "0.0.0.0/0"
    description = "Allow outbound UDP traffic"
  }

  egress_security_rules {
    protocol    = "6" # TCP
    destination = "0.0.0.0/0"
    description = "Allow outbound TCP traffic"
  }
  
}

resource "oci_core_instance" "security_lab_instance" {
  availability_domain = data.oci_identity_availability_domains.security_lab_ad.availability_domains[0].name
  compartment_id      = var.compartment
  display_name        = "security-lab-instance"
  shape               = "VM.Standard2.8" # Choose your shape
  #opc_new_password    = base64decode(data.oci_secrets_secretbundle.passwd_vault.secret_bundle_content.0.content)

  create_vnic_details {
    subnet_id        = oci_core_subnet.security_lab_private_subnet.id
    assign_public_ip = true
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/oci_key.pub") # Path to your public key
  }

  source_details {
    source_type = "image"
    source_id   = var.source_id
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install python3.9 -y"
    ]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "opc"
      private_key = file("~/.ssh/oci_key")
    }
  }

  provisioner "local-exec" {
    working_dir = var.dir
    command     = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${self.public_ip},'  -u opc --private-key '~/.ssh/oci_key' -e '~/.ssh/oci_key.pub' get_stager.yml -vvv --ask-become-pass"
  }

  provisioner "remote-exec" {
    inline = [
      # Change opc password
      "echo 'opc:${local.opc_new_password}' | sudo chpasswd",
      "echo 'opc password updated successfully!"
    ]
  }
}

data "oci_identity_availability_domains" "security_lab_ad" {
  compartment_id = var.tenancy_ocid
}