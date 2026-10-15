module main

import css
import dom
import html
import layout
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

// Background image dimensions affect painting, while replaced and generated
// images can change intrinsic layout. Keep the committed geometry only when
// none of the completed resources participates in that second role.
fn browser_svg_source_changed(document &dom.Document, source string, changed map[string]bool) bool {
	if source == '' { return false }
	address := document.encoding_parse_and_serialize_url(source) or { return false }
	return address.all_before('#') in changed
}

fn browser_svg_dom_resource_needs_layout(node &dom.Node, changed map[string]bool) bool {
	element := node.as_element() or { return false }
	document := node.document()
	if element.is_html_element() {
		name := element.local_name()
		if name in ['img', 'input', 'source'] {
			if browser_svg_source_changed(document, element.get_attribute_value('src'), changed) {
				return true
			}
			// Include unselected candidates conservatively, without treating an
			// unrelated PNG srcset as a dependency on a CSS SVG sprite.
			for candidate in html.parse_a_srcset_attribute(element.get_attribute_value('srcset')).sources {
				if browser_svg_source_changed(document, candidate.url, changed) { return true }
			}
		}
		return name == 'object'
			&& browser_svg_source_changed(document, element.get_attribute_value('data'), changed)
	}
	// SVG image/use resources may have no ImageBox while loading or broken.
	href := if element.has_attribute('href') {
		element.get_attribute_value('href')
	} else {
		element.get_attribute_ns('http://www.w3.org/1999/xlink', 'href') or { '' }
	}
	return browser_svg_source_changed(document, href, changed)
}

fn browser_svg_layout_resource_needs_layout(node &layout.Node, changed map[string]bool) bool {
	if image := node.as_image_box() {
		if browser_svg_source_changed(node.document(), image.source(), changed) { return true }
	}
	if styled := node.as_node_with_style() {
		if image := styled.list_style_image() {
			match image {
				css.ImageStyleValue {
					if browser_svg_source_changed(node.document(), image.url_.url(), changed) { return true }
				}
				css.ImageSetStyleValue {
					for option in image.options_ {
						if option.image is css.ImageStyleValue {
							if browser_svg_source_changed(node.document(), option.image.url_.url(), changed) { return true }
						}
					}
				}
				else {}
			}
		}
	}
	for child in node.children() {
		if browser_svg_layout_resource_needs_layout(child, changed) { return true }
	}
	return false
}

fn browser_svg_resources_need_layout(document &dom.Document, changed map[string]bool) bool {
	result := layout.document_layout_result(document) or { return true }
	if result.root == unsafe { nil } { return true }
	// Inspect DOM owners too: pending images and object fallback content need
	// not yet have a replaced layout box. Include author and UA shadow trees.
	if document.as_node().for_each_shadow_including_inclusive_descendant(fn [changed] (node &dom.Node) dom.TraversalDecision {
		return if browser_svg_dom_resource_needs_layout(node, changed) { .@break } else { .@continue }
	}) == .@break { return true }
	return browser_svg_layout_resource_needs_layout(result.root, changed)
}
