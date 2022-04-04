# BIG-IP

############################ Private IPs ############################

# Reserve IPs on external subnet for BIG-IP nic0
resource "google_compute_address" "ext" {
  name         = "bigip-ext"
  subnetwork   = var.extSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

# Reserve VIP on external subnet for BIG-IP nic0
resource "google_compute_address" "vip" {
  name         = "bigip-ext-vip"
  subnetwork   = var.extSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

# Reserve IPs on management subnet for BIG-IP nic1
resource "google_compute_address" "mgt" {
  name         = "bigip-mgt"
  subnetwork   = var.mgmtSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

# Reserve IPs on internal subnet for BIG-IP nic2
resource "google_compute_address" "int" {
  name         = "bigip-int"
  subnetwork   = var.intSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

############################ Public IPs ############################

# Create Public IPs - VIP
resource "google_compute_address" "vip1" {
  name = format("%s-vip1-%s", var.projectPrefix, random_id.buildSuffix.hex)
}

# Forwarding rule for Public IP
resource "google_compute_forwarding_rule" "vip1" {
  name       = format("%s-forwarding-rule-%s", var.projectPrefix, random_id.buildSuffix.hex)
  target     = google_compute_target_instance.f5vm01.id
  ip_address = google_compute_address.vip1.address
  port_range = "1-65535"
}

resource "google_compute_target_instance" "f5vm01" {
  name     = format("%s-ti-%s", var.projectPrefix, random_id.buildSuffix.hex)
  instance = module.bigip.bigip_instance_ids
  zone     = var.gcp_zone_1
}

############################ Onboard Scripts ############################

# Setup Onboarding scripts
locals {
  f5_onboard1 = templatefile("${path.module}/f5_onboard.tmpl", {
    regKey                            = var.license1
    f5_username                       = var.f5_username
    f5_password                       = var.f5_password
    svc_acct                          = var.svc_acct
    telemetry_secret                  = var.telemetry_secret
    telemetry_privateKeyId            = var.telemetry_privateKeyId
    ssh_keypair                       = file(var.ssh_key)
    gcp_project_id                    = var.gcp_project_id
    INIT_URL                          = var.INIT_URL
    DO_URL                            = var.DO_URL
    AS3_URL                           = var.AS3_URL
    TS_URL                            = var.TS_URL
    FAST_URL                          = var.FAST_URL
    DO_VER                            = split("/", var.DO_URL)[7]
    AS3_VER                           = split("/", var.AS3_URL)[7]
    TS_VER                            = split("/", var.TS_URL)[7]
    FAST_VER                          = split("/", var.FAST_URL)[7]
    dns_server                        = var.dns_server
    dns_suffix                        = var.dns_suffix
    ntp_server                        = var.ntp_server
    timezone                          = var.timezone
    bigIqLicenseType                  = var.bigIqLicenseType
    bigIqHost                         = var.bigIqHost
    bigIqPassword                     = var.bigIqPassword
    bigIqUsername                     = var.bigIqUsername
    bigIqLicensePool                  = var.bigIqLicensePool
    bigIqSkuKeyword1                  = var.bigIqSkuKeyword1
    bigIqSkuKeyword2                  = var.bigIqSkuKeyword2
    bigIqUnitOfMeasure                = var.bigIqUnitOfMeasure
    bigIqHypervisor                   = var.bigIqHypervisor
    NIC_COUNT                         = true
    gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
  })
}

# Create F5 BIG-IP VMs
module "bigip" {
  source              = "F5Networks/bigip-module/gcp"
  prefix              = format("%s-3nic", var.projectPrefix)
  project_id          = var.gcp_project_id
  zone                = var.gcp_zone_1
  image               = var.image_name
  service_account     = var.svc_acct
  f5_username         = var.f5_username
  f5_password         = var.f5_password
  f5_ssh_publickey    = var.ssh_key
  mgmt_subnet_ids     = [{ "subnet_id" = var.mgmtSubnet, "public_ip" = true, "private_ip_primary" = google_compute_address.mgt.address }]
  external_subnet_ids = [{ "subnet_id" = var.extSubnet, "public_ip" = true, "private_ip_primary" = google_compute_address.ext.address, "private_ip_secondary" = google_compute_address.vip.address }]
  internal_subnet_ids = [{ "subnet_id" = var.intSubnet, "public_ip" = false, "private_ip_primary" = google_compute_address.int.address, "private_ip_secondary" = "" }]
  custom_user_data    = local.f5_onboard1
  sleep_time          = "30s"
}
