terraform {
  required_providers {
    snowflake = {
      source  = "chanzuckerberg/snowflake"
      version = "0.22.0"
    }
  }
  cloud {
    organization = "example-org-3e9810"

    workspaces {
      name = "snowflake-automation"
    }
  }
}

provider "snowflake" {
  alias    = "sys_admin"
  role     = "SYSADMIN"
  username = var.SNOWFLAKE_USER
  password = var.SNOWFLAKE_PASSWORD
  region   = var.SNOWFLAKE_REGION
  account  = var.SNOWFLAKE_ACCOUNT
}

resource "snowflake_database" "db" {
  provider = snowflake.sys_admin
  name     = "TF_DEMO"
}

provider "snowflake" {
  alias    = "security_admin"
  role     = "SECURITYADMIN"
  username = var.SNOWFLAKE_USER
  password = var.SNOWFLAKE_PASSWORD
  region   = var.SNOWFLAKE_REGION
  account  = var.SNOWFLAKE_ACCOUNT
}


resource "snowflake_role" "role" {
  provider = snowflake.security_admin
  name     = "TF_DEMO_SVC_ROLE"
}


resource "snowflake_database_grant" "grant" {
  provider          = snowflake.security_admin
  database_name     = snowflake_database.db.name
  privilege         = "USAGE"
  roles             = [snowflake_role.role.name]
  with_grant_option = false
}


resource "snowflake_schema" "schema" {
  provider   = snowflake.sys_admin
  database   = snowflake_database.db.name
  name       = "TF_DEMO"
  is_managed = false
}


resource "snowflake_schema_grant" "grant" {
  provider          = snowflake.security_admin
  database_name     = snowflake_database.db.name
  schema_name       = snowflake_schema.schema.name
  privilege         = "USAGE"
  roles             = [snowflake_role.role.name]
  with_grant_option = false
}


resource "snowflake_warehouse_grant" "grant" {
  provider          = snowflake.security_admin
  warehouse_name    = snowflake_warehouse.warehouse.name
  privilege         = "USAGE"
  roles             = [snowflake_role.role.name]
  with_grant_option = false
}


resource "tls_private_key" "svc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}


resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = "tf_demo_user"
  default_warehouse = snowflake_warehouse.warehouse.name
  default_role      = snowflake_role.role.name
  default_namespace = "${snowflake_database.db.name}.${snowflake_schema.schema.name}"
  rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}


resource "snowflake_role_grants" "grants" {
  provider  = snowflake.security_admin
  role_name = snowflake_role.role.name
  users     = [snowflake_user.user.name]
}

resource "snowflake_warehouse" "warehouse" {
  provider       = snowflake.sys_admin
  name           = "TF_DEMO"
  warehouse_size = "small"

  auto_suspend = 60
}
