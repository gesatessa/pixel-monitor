locals {
  prefix = "${var.project_name}-${terraform.workspace}"

  # it's a map of maps, 
  # where the key is "private_1", "private_2", etc., and the value is a map with "cidr" and "az"
  private_subnets = {
    for i, cidr in var.private_subnet_cidrs :
    "private_${i + 1}" => {
      cidr = cidr
      az   = data.aws_availability_zones.available.names[i]
    }
  }

}
