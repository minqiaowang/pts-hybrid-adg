variable "tenancy_ocid" {}
variable "region" {}
# variable "display_name" { default = "workshop" }
variable "AD" { default = 1 }
variable "Image-Id" {default="ocid1.image.oc1..aaaaaaaafc323nq572bujhzwja7e6df532ioqq7qididhmnujpgbshm2zrzq"}
variable "instance_shape" {
  default = "VM.Standard2.1"
}
variable "package_version" {
  default = "Oracle Database 19.9.0.0.201020 - OL7U9"
  #default = "Oracle Database 19.7.0.0.200414"
  #default = "Oracle Database 19.9.0.0.201020 - AL7U9"
}

variable "compartment_ocid" {}
variable "ssh_public_key" {}

variable "num_instances" {
  default = "1"
}

terraform {
  required_version = ">= 0.12.0"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

provider "oci" {
  tenancy_ocid = "${var.tenancy_ocid}"
  region       = "${var.region}"
}


variable "VCN-example" { default = "10.0.0.0/16" }
resource "oci_core_virtual_network" "example-vcn" {
  cidr_block     = "${var.VCN-example}"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "primary-vcn"
  dns_label      = "primaryvcn"
}

# --- Create a new Internet Gateway
resource "oci_core_internet_gateway" "example-ig" {
  compartment_id = "${var.compartment_ocid}"
  display_name   = "primary-internet-gateway"
  vcn_id         = "${oci_core_virtual_network.example-vcn.id}"
}
#---- Create Route Table
resource "oci_core_route_table" "example-rt" {
  compartment_id = "${var.compartment_ocid}"
  vcn_id         = "${oci_core_virtual_network.example-vcn.id}"
  display_name   = "primary-route-table"
  route_rules {
    cidr_block        = "0.0.0.0/0"
    network_entity_id = "${oci_core_internet_gateway.example-ig.id}"
  }
}

#--- Create a public Subnet 1 in AD1 in the new vcn
resource "oci_core_subnet" "example-public-subnet1" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1], "name")}"
  cidr_block          = "10.0.1.0/24"
  display_name        = "primary-public-subnet1"
  dns_label           = "subnet1"
  compartment_id      = "${var.compartment_ocid}"
  vcn_id              = "${oci_core_virtual_network.example-vcn.id}"
  route_table_id      = "${oci_core_route_table.example-rt.id}"
  dhcp_options_id     = "${oci_core_virtual_network.example-vcn.default_dhcp_options_id}"
}


#--- Defualt  Network Security List

resource "oci_core_default_security_list" "default-security-list" {
  manage_default_resource_id = "${oci_core_virtual_network.example-vcn.default_security_list_id}"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }


  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 1521
      max = 1521
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 443
      max = 443
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"

    tcp_options {
      min = 22
      max = 22
    }

  }
}

##
# Found image id from Marketplace and get signature
##
#    Resource Elements

resource "oci_marketplace_accepted_agreement" "test_accepted_agreement" {
  #Required
  agreement_id    = oci_marketplace_listing_package_agreement.test_listing_package_agreement.agreement_id
  compartment_id  = var.compartment_ocid
  listing_id      = data.oci_marketplace_listing.test_listing.id
  #package_version = data.oci_marketplace_listing.test_listing.default_package_version
  package_version = data.oci_marketplace_listing_packages.test_listing_packages.listing_packages[0].package_version
  signature       = oci_marketplace_listing_package_agreement.test_listing_package_agreement.signature
}
resource "oci_marketplace_listing_package_agreement" "test_listing_package_agreement" {
  #Required
  agreement_id    = data.oci_marketplace_listing_package_agreements.test_listing_package_agreements.agreements[0].id
  listing_id      = data.oci_marketplace_listing.test_listing.id
  #package_version = data.oci_marketplace_listing.test_listing.default_package_version
  package_version = data.oci_marketplace_listing_packages.test_listing_packages.listing_packages[0].package_version
}

#    Data Elements

data "oci_marketplace_listing_package_agreements" "test_listing_package_agreements" {
  #Required
  listing_id      = data.oci_marketplace_listing.test_listing.id
  #package_version = data.oci_marketplace_listing.test_listing.default_package_version
  package_version = data.oci_marketplace_listing_packages.test_listing_packages.listing_packages[0].package_version
  #Optional
  compartment_id = var.compartment_ocid
}
data "oci_marketplace_listing_package" "test_listing_package" {
  #Required
  listing_id      = data.oci_marketplace_listing.test_listing.id
  #package_version = data.oci_marketplace_listing.test_listing.default_package_version
  package_version = data.oci_marketplace_listing_packages.test_listing_packages.listing_packages[0].package_version
  #Optional
  compartment_id = var.compartment_ocid
}
data "oci_marketplace_listing_packages" "test_listing_packages" {
  #Required
  listing_id = data.oci_marketplace_listing.test_listing.id

  #Optional
  compartment_id = var.compartment_ocid
  package_version = var.package_version
}

data "oci_marketplace_listing" "test_listing" {
  listing_id     = data.oci_marketplace_listings.test_listings.listings[0].id
  compartment_id = var.compartment_ocid
}

data "oci_marketplace_listings" "test_listings" {
  #category       = ["Other"]
  name = ["Oracle Database"]
  compartment_id = var.compartment_ocid
}

data "oci_core_app_catalog_listing_resource_version" "test_catalog_listing" {
  listing_id = data.oci_marketplace_listing_package.test_listing_package.app_catalog_listing_id
  resource_version = data.oci_marketplace_listing_package.test_listing_package.app_catalog_listing_resource_version
}

# Compute Instances
resource "oci_core_instance" "ssworkshop_instance" {
  count               = "${var.num_instances}"
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.AD - 1], "name")}"
  compartment_id      = "${var.compartment_ocid}"
  display_name        = "primary${count.index}"
  shape               = "${var.instance_shape}"

  create_vnic_details {
    subnet_id = "${oci_core_subnet.example-public-subnet1.id}"
    display_name     = "primary"
    assign_public_ip = true
    hostname_label   = "primary${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_app_catalog_listing_resource_version.test_catalog_listing.listing_resource_id

  }

  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}"
    user_data           = "${base64encode(file("custom-db.sh"))}"
  }

}

output "instance_public_ips" {
  value = ["${oci_core_instance.ssworkshop_instance.*.public_ip}"]
}
