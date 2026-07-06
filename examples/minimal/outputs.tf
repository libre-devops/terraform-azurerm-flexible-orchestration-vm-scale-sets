output "image_catalog_keys" {
  description = "Catalog keys accepted by source_image_simple."
  value       = module.flex_vmss.image_catalog_keys
}

output "vmss_ids" {
  description = "Map of scale set name to resource id."
  value       = module.flex_vmss.ids
}
