module main

// A blocking script can leave SVG instances beyond the shell's first scan.
// Complete their resources before the parser publishes document readiness.
fn (mut host BrowserParserScriptHost) install_svg_use_resources() {
	document := host.document
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	base := document.base_url().serialize()
	uses := document_svg_element_preload_urls(document, base, ['use'])
	// Keep the ordinary discovery rules for local fragments and origin checks.
	urls := document_preload_resource_urls(document, base).filter(it in uses)
	mut cached := host.initial_resources.clone()
	for address, resource in host.svg_resources { cached[address] = resource }
	for address, resource in preload_document_resource_urls(document, base, urls, cached) {
		host.svg_resources[address] = resource
		publish_browser_svg_resource(resource)
	}
	install_browser_svg_use_resources(document, host.svg_resources.clone())
}
