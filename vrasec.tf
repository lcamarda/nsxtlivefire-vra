# configure some variables first
variable "nsx_ip" {
  default = "nsxmgr-01a.corp.local"
}

variable "nsx_password" {
  default = "VMware1!"
}


# Configure the VMware NSX-T Provider
provider "nsxt" {
  host                 = "${var.nsx_ip}"
  username             = "admin"
  password             = "${var.nsx_password}"
  allow_unverified_ssl = true
}



# Create NS Group vra-wordpress
resource "nsxt_ns_group" "vra-wordpress" {
  display_name = "vra-wordpress"
}

# Create NS Group vra-web
resource "nsxt_ns_group" "vra-web" {
  display_name = "vra-web"
}

# Create NS Group vra-web
resource "nsxt_ns_group" "vra-db" {
  display_name = "vra-db"
}

# Collect NS Service info
data "nsxt_ns_service" "mysql" {
  display_name = "MySQL"
}

data "nsxt_ns_service" "http" {
  display_name = "HTTP"
}

resource "nsxt_ip_set" "IPS_Management" {
  display_name = "IPS-Management"
  ip_addresses = ["192.168.110.10", "192.168.110.78"]
}

resource "nsxt_ip_set" "IPS-T1-Tenant1-uplink" {
  display_name = "IPS-T1-Tenant1-uplink"
  ip_addresses = ["192.168.110.10", "192.168.110.78"]
}


resource "nsxt_firewall_section" "vRAWordpress" {
  display_name = "vRA Wordpress"
  section_type = "LAYER3"
  stateful     = true

  rule {
    display_name = "Managment Outbound"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-wordpress.id}"
    }

    destination {
      target_type = "IPSet"
      target_id   = "${nsxt_ip_set.IPS_Management.id}"
    }

    applied_to {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-wordpress.id}"
    }
  }

  rule {
    display_name = "Managment Inbound"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-wordpress.id}"
    }

    source {
      target_type = "IPSet"
      target_id   = "${nsxt_ip_set.IPS_Management.id}"
    }

    applied_to {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-wordpress.id}"
    }
  }

  rule {
    display_name = "LB to Web"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-web.id}"
    }

    source {
      target_type = "IPSet"
      target_id   = "${nsxt_ip_set.IPS-T1-Tenant1-uplink.id}"
    }

    service {
      target_type = "NSService"
      target_id   = "${data.nsxt_ns_service.http.id}"
    }

    applied_to {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-web.id}"
    }
  }

  rule {
    display_name = "Web to DB allow MySQL"
    action       = "ALLOW"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-db.id}"
    }

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-web.id}"
    }

    service {
      target_type = "NSService"
      target_id   = "${data.nsxt_ns_service.mysql.id}"
    }

    applied_to {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-db.id}"
    }
  }

  rule {
    display_name = "Web to DB deny"
    action       = "DROP"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-db.id}"
    }

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-web.id}"
    }

    applied_to {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-db.id}"
    }
  }

  rule {
    display_name = "DB to Web deny"
    action       = "DROP"
    logged       = true
    ip_protocol  = "IPV4"
    direction    = "IN_OUT"

    source {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-db.id}"
    }

    destination {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-web.id}"
    }

    applied_to {
      target_type = "NSGroup"
      target_id   = "${nsxt_ns_group.vra-web.id}"
    }
  }
}
