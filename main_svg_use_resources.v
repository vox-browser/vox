module main

import dom
import html

@[heap]
struct BrowserSVGUseResources {
	owner &dom.Document
	resources map[string]PreloadedResource
mut:
	documents map[string]&dom.Document
}

fn install_browser_svg_use_resources(document &dom.Document, resources map[string]PreloadedResource) {
	mut owner := &BrowserSVGUseResources{owner: document, resources: resources}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_svg_use_resource_hook(dom.DocumentSVGUseResourceHook{
		target: owner
		resolve: browser_resolve_svg_use_document
	})
}

fn browser_resolve_svg_use_document(target voidptr, address dom.URL) ?&dom.Document {
	mut owner := unsafe { &BrowserSVGUseResources(target) }
	if address.scheme() !in ['http', 'https']
		|| !address.origin().is_same_origin(owner.owner.origin()) { return none }
	key := address.serialize().all_before('#')
	if document := owner.documents[key] { return document }
	resource := owner.resources[key] or { return none }
	if resource.error != '' || resource.body == '' { return none }
	final_url := if resource.final_url != '' { resource.final_url } else { key }
	final_address := dom.dom_url_parse(final_url, owner.owner.url, 'UTF-8') or { return none }
	if !final_address.origin().is_same_origin(owner.owner.origin()) { return none }
	decoded := browser_decode_svg_image(dom.URL{value: key}, resource.body.bytes()) or { return none }
	if decoded is html.SVGDecodedImageData {
		owner.documents[key] = decoded.svg_document
		return decoded.svg_document
	}
	return none
}
