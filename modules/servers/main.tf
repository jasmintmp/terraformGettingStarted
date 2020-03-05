# MODULE
# This .tf configuration is wrapped up as a Module 'message' in external .tf
# With input/output parameters - required, unless it has default.
variable "server_name" {
  description = "Name of serverr - input"
}

variable "server_created" {
  description   = "When created - input"
  default = 1979
}

output "server_outputs" {
  description = "This is my modules output:"
  #multiline string EOT 
  value = <<EOT
  This is output_var from module: 
  Name: ${var.server_name} ; Age  ${2020 - var.server_created}
  EOT
}