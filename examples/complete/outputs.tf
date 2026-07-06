output "backend_pool_ids" {
  description = "The load balancer backend pool the Linux scale set joined."
  value       = module.private_lb.backend_pool_ids
}

output "unique_ids" {
  description = "Azure unique ids of the scale sets."
  value       = module.flex_vmss.unique_ids
}

output "vmss_ids" {
  description = "Map of scale set name to resource id."
  value       = module.flex_vmss.ids
}
