provider "azurerm" {
  features{}
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

variable "subscription_id" {
    description = "Enter Subscription ID"
    default = "dbe857d8-f7ea-4c79-bb59-b4e5bc080426"
}

variable "location" {
  type = string
  default = "uksouth"
}

variable "client_id" {
    description = "Enter Client ID"
    default = "02128d0d-13e7-4f4d-a0d5-1988496424c1"
}

variable "client_secret" {
    description = "Enter Client Secret"
    default = "bch8Q~W2-CCbBTL65QKuuiHniHcUO2lB1jU6YcK2"
}

variable "tenant_id" {
    description = "Enter Tenant ID"
    default = "0b3fc178-b730-4e8b-9843-e81259237b77"
}

variable "environment" {
  type = string
  default = "sbox0"
}

variable "bank" {
  type = string
  default = "pol"
}

locals {
  prefix = "${var.bank}-${var.environment}"
  prefix_no_dash = "${var.bank}${var.environment}"
  group_prefix = title("${var.bank} ${var.environment}")
  terraform_last_run_date = formatdate("DD-MM-YYYY", timestamp())
  // right most parameter takes precendence

}



locals {
    automation_accounts = [
        {
            account_name                = "${local.prefix}-sql-automation"
            identity_type               = "SystemAssigned"
            user_assigned_identity_ids  = []
            modules = [
                {
                    module_name = "sqlserver"
                    module_uri  = "https://psg-prod-eastus.azureedge.net/packages/sqlserver.21.1.18256.nupkg"
                }                       
            ]
        }

    ]
    modules = flatten([
        for key ,value in local.automation_accounts : [
            for index , val in value.modules : {
                account_name                = value.account_name
                identity_type               = value.identity_type
                user_assigned_identity_ids  = value.user_assigned_identity_ids
                module_name                 = val.module_name
                module_uri                  = val.module_uri
            }
        ]
    ])
}

variable "automation_public_network_access_enabled" {
    type = bool
    default = true
}

resource "azurerm_resource_group" "automation" {
    name     = "${local.prefix}-automation-rg"
    location = var.location
}

resource "azurerm_automation_account" "automation" {
  for_each   = { for account in local.automation_accounts: account.account_name => account }

    name                = each.value.account_name
    location            = azurerm_resource_group.automation.location
    resource_group_name = azurerm_resource_group.automation.name

    sku_name = "Basic"

    identity {
        type            = each.value.identity_type
        identity_ids    = each.value.user_assigned_identity_ids
    }

    public_network_access_enabled = var.automation_public_network_access_enabled
}

resource "azurerm_role_assignment" "subscription_reader" {
  for_each = { for account in local.automation_accounts: account.account_name => account }
    scope              = "/subscriptions/dbe857d8-f7ea-4c79-bb59-b4e5bc080426"
    role_definition_id = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Subscription Reader Role ID
    principal_id       = azurerm_automation_account.automation[each.key].identity[0].principal_id
    depends_on = [
      azurerm_automation_account.automation
    ]
}
