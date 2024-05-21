variable "acrSku" {
  type        = string
}

variable "location" {
    type = string
    default = "usgovvirginia"
}

variable "name" {
  type      = string
  default   = ""
}

variable "resourceGroupName" {
    type = string
    default = ""
}

variable "isGovCloudDeployment" {
    type = bool
    default = false
}

variable "useExistingAcr" {
    type = bool
    default = false
}

variable "acrName" {
    type = string
    default = ""
}

variable "acrResourceGroup" {
  type = string
  default = ""
}