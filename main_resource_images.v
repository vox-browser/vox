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

fn new_browser_preloaded_image_fetch(document &dom.Document, resources map[string]PreloadedResource) &BrowserPreloadedImageFetch {
	return &BrowserPreloadedImageFetch{
		document: document
		resources: resources
		resource_types: document_preload_resource_types(document, document.base_url().serialize())
	}
}

$if test {
	fn browser_preloaded_image_fetch(document &dom.Document, resources map[string]PreloadedResource) browserjs.ImageRequestFetchHook {
		return new_browser_preloaded_image_fetch(document, resources).callback()
	}
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

// Each image's request goes through the model it is made for, so the hook is a
// plain function rather than a closure that would keep its image alive.
fn browser_image_model_fetch(model &html.HTMLImageElementModel, address dom.URL) !html.DecodedImageData {
	image := model.image_element() or { return error('Image request has no element') }
	return browser_fetch_image_request(image, model, address)
}

// Static pages still need real HTML image requests. Installing the JavaScript
// ImageHost must not be a prerequisite for decoding and displaying an <img>.
fn install_static_browser_image_fetch_hooks(document &dom.Document, deferred map[string]bool) {
	install_static_browser_image_fetch_hooks_with_loader(document, deferred, none)
}

fn install_static_browser_image_fetch_hooks_with_loader(document &dom.Document,
	deferred map[string]bool, image_loader ?&BrowserImageRequestLoader) {
	for element in css.query_selector_all(document.as_node(), 'img') {
		if !element.is_html_element() { continue }
		image := unsafe { &dom.HTMLImageElement(element) }
		mut model := html.html_image_element_model_for_dom_element(image)
		if owner := image_loader {
			if browser_image_has_lazy_loading_policy(image) {
				model.set_model_async_fetch_hook(owner.lazy_static_callback())
			} else {
				model.set_model_fetch_hook(browser_image_model_fetch)
			}
		} else {
			model.set_model_fetch_hook(browser_image_model_fetch)
		}
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

// An HTML image request owns its decoded SVG independently of the shell's
// resource cache. Loading that URL again for a favicon or CSS background does
// not replace the image's document or change its intrinsic size. Only skip the
// dependency when the committed image box actually uses that decoded document;
// generated content and images still waiting for bytes keep their invalidation.
fn browser_svg_image_owns_decoded_document(node &layout.Node) bool {
	image := node.as_image_box() or { return false }
	isolated := image.svg_image_document() or { return false }
	dom_node := node.dom_node() or { return false }
	if !dom_node.is_html_image_element() { return false }
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(dom_node) })
	decoded := model.decoded_image_data() or { return false }
	return if decoded is html.SVGDecodedImageData {
		voidptr(isolated) == voidptr(decoded.svg_document)
	} else { false }
}

fn browser_svg_dom_resource_needs_layout(node &dom.Node, changed map[string]bool) bool {
	element := node.as_element() or { return false }
	document := node.document()
	if element.is_html_element() {
		name := element.local_name()
		if name == 'img' {
			if placeholder := node.unsafe_layout_node() {
				handle := placeholder.real_layout_handle()
				if handle != unsafe { nil }
					&& browser_svg_image_owns_decoded_document(unsafe { &layout.Node(handle) }) {
					return false
				}
			}
		}
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
		if browser_svg_source_changed(node.document(), image.source(), changed)
			&& !browser_svg_image_owns_decoded_document(node) { return true }
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
	if document.as_node().visit_shadow_including_inclusive_descendants(fn [changed] (node &dom.Node) dom.TraversalDecision {
		return if browser_svg_dom_resource_needs_layout(node, changed) { .@break } else { .@continue }
	}) == .@break { return true }
	return browser_svg_layout_resource_needs_layout(result.root, changed)
}
