#Container URLs in AWS
variable "payments-service-image-url" {
	description = "URL for Payments Sevice container image"
	type = string
	default = "450890513155.dkr.ecr.us-east-1.amazonaws.com/sale_app:payments-service"
}