variable "environment" {
  description = "Environment name (homol, prod) — used in tags and resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones where private subnets will be created"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs of private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidr" {
  description = "CIDR of the public subnet, used only for the NAT Gateway"
  type        = string
  default     = "10.0.0.0/24"
}

variable "enable_nat" {
  description = "Enable the NAT Gateway (and the Internet Gateway it requires). Keep it false outside of study sessions to avoid costs."
  type        = bool
  default     = false
}