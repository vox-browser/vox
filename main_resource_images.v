module main

import browserjs
import css
import dom
import html
import layout
import loader

// Image binding setup runs after this document's resource preload. Consume that
// pass's completed responses, including failures, instead of refetching rejected
// thumbnails or replaying redirect chains synchronously on the UI thread.
@[heap]
struct BrowserPreloadedImageFetch {
	document &dom.Document
	resource_types map[string]string
mut:
	resources map[string]PreloadedResource
}

fn run_document_script_sources_with_preloaded_images(document &dom.Document, current_url string, sources []browserjs.ScriptSource, runtime &browserjs.Runtime, resources map[string]PreloadedResource, mut messages []string) ?string {
	mut preload := new_browser_preloaded_image_fetch(document, resources)
	// Later author retries must use the normal fetch path. Release the initial
	// response snapshot as well as its failures once installation has finished.
	defer { preload.resources = map[string]PreloadedResource{} }
	return run_document_script_sources_with_image_fetch(document, current_url, sources, runtime,
		preload.callback(), mut messages)
}

fn new_browser_preloaded_image_fetch(document &dom.Document, resources map[string]PreloadedResource) &BrowserPreloadedImageFetch {
	return &BrowserPreloadedImageFetch{
		document: document
		resources: resources
		resource_types: document_preload_resource_types(document, document.base_url().serialize())
	}
}

fn browser_preloaded_image_fetch(document &dom.Document, resources map[string]PreloadedResource) browserjs.ImageRequestFetchHook {
	return new_browser_preloaded_image_fetch(document, resources).callback()
}

fn (preload &BrowserPreloadedImageFetch) callback() browserjs.ImageRequestFetchHook {
	return fn [preload] (image &dom.HTMLImageElement, model &html.HTMLImageElementModel, address dom.URL) !html.DecodedImageData {
		owner := unsafe { &dom.Element(image) }.document()
		if voidptr(owner) == voidptr(preload.document) {
			if resource := preload.resources[address.serialize()] {
				if (preload.resource_types[address.serialize()] or { 'image' }) == 'image' {
					if !browser_image_request_allows_cached_bytes(image, model, address) {
						return error('Cross-origin image CORS responses are not supported by the native cache')
					}
					if resource.error != '' {
						return error(resource.error)
					}
					return browser_decoded_image_data(address, resource.body.bytes())
				}
			}
		}
		return browser_fetch_image_request(image, model, address)
	}
}

fn browser_image_resource_is_svg(address dom.URL) bool {
	return address.basename().to_lower().ends_with('.svg')
		|| (address.scheme() == 'data'
			&& address.serialize().all_before(',').to_lower().starts_with('data:image/svg+xml'))
}

fn browser_decode_svg_image(address dom.URL, bytes []u8) !html.DecodedImageData {
	mut document := dom.Document.create(address)
	document.set_document_type(.xml)
	document.set_content_type('image/svg+xml')
	document.set_is_svg_image_document(true)
	html.parse_xml_document_source(document, bytes.bytestr()) or {
		document.finalize()
		return err
	}
	root := document.document_element() or {
		document.finalize()
		return error('SVG image has no document element')
	}
	if root.local_name() != 'svg' || (root.namespace_uri() or { '' }) != 'http://www.w3.org/2000/svg' {
		document.finalize()
		return error('SVG image has no SVG root')
	}
	metrics := layout.svg_background_natural_size(document)
	width := if value := metrics.width { ?f64(value.to_double()) } else { none }
	height := if value := metrics.height { ?f64(value.to_double()) } else { none }
	ratio := if value := metrics.aspect_ratio { ?f64(value.to_double()) } else { none }
	decoded := html.SVGDecodedImageData.create(document, width, height, ratio)
	decoded.set_is_cors_cross_origin(address.scheme() in ['http', 'https'])
	return decoded
}

// Static pages still need real HTML image requests. Installing the JavaScript
// ImageHost must not be a prerequisite for decoding and displaying an <img>.
fn install_static_browser_image_fetch_hooks(document &dom.Document, deferred map[string]bool) {
	for element in css.query_selector_all(document.as_node(), 'img') {
		if !element.is_html_element() { continue }
		image := unsafe { &dom.HTMLImageElement(element) }
		mut model := html.html_image_element_model_for_dom_element(image)
		model.set_fetch_hook(fn [image, model] (address dom.URL) !html.DecodedImageData {
			return browser_fetch_image_request(image, model, address)
		})
		address := resolve_document_reference(element.get_attribute_value('src'), document.base_url().serialize())
		if address !in deferred && (element.has_attribute('src') || element.has_attribute('srcset')) {
			model.update_the_image_data(false, false)
		}
	}
}

fn complete_static_browser_image_requests(document &dom.Document, completed map[string]bool) {
	for element in css.query_selector_all(document.as_node(), 'img[src]') {
		if !element.is_html_element() { continue }
		address := resolve_document_reference(element.get_attribute_value('src'), document.base_url().serialize())
		if address !in completed { continue }
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		model.update_the_image_data(false, false)
	}
}

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
