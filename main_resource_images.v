module main

import loader

// The native shell owns network I/O. Publish completed SVG resources to the
// translated loader so layout can consume their bytes without starting I/O.
fn publish_browser_svg_resource(resource PreloadedResource) bool {
	address := resource.url.all_before('#')
	if !address.starts_with('https://') && !address.starts_with('http://') { return false }
	if !address.all_before('?').to_lower().ends_with('.svg') { return false }
	if !loader.is_initialized() { loader.initialize() }
	mut resource_loader := loader.ResourceLoader.the()
	if resource.error != '' || resource.body == '' {
		resource_loader.register_network_response(address, loader.NetworkResponse{
			error_message: if resource.error != '' { resource.error } else { 'Empty SVG response' }
		})
		return false
	}
	resource_loader.register_network_response(address, loader.NetworkResponse{
		data: resource.body.bytes()
	})
	return true
}
