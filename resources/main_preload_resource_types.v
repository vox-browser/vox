module main

import css
import dom

// SVG image/filter resources can feed a mask or paint server before an HTML
// image model exists. Keep those bytes in the static document's preload barrier,
// including a URL shared by an ordinary <img>.
fn document_svg_image_preload_urls(document &dom.Document, base_url string) map[string]bool {
	return document_svg_element_preload_urls(document, base_url, ['image', 'feImage', 'use'])
}

fn document_initial_svg_preload_urls(document &dom.Document, base_url string) map[string]bool {
	return if document.as_node().is_scripting_enabled() {
		document_svg_element_preload_urls(document, base_url, ['use'])
	} else { document_svg_image_preload_urls(document, base_url) }
}

fn document_svg_element_preload_urls(document &dom.Document, base_url string, tags []string) map[string]bool {
	mut urls := map[string]bool{}
	mut images := []&dom.Element{}
	for tag in tags { images << css.query_selector_all(document.as_node(), tag) }
	for image in images {
		if image.is_html_element() { continue }
		source := if image.has_attribute('href') {
			image.get_attribute_value('href').trim_space()
		} else {
			image.get_attribute_value('xlink:href').trim_space()
		}
		if source != '' {
			address := resolve_document_reference(source, base_url)
			urls[if image.local_name() == 'use' { address.all_before('#') } else { address }] = true
		}
	}
	return urls
}

// Keep classification local to this preload pass: a resource can occur in
// several element roles, and later DOM or scripting-policy changes need a new
// index. Stylesheets retain priority over scripts, with images as the fallback.
fn document_preload_resource_types(document &dom.Document, base_url string) map[string]string {
	root := unsafe { &dom.Node(document) }
	mut types := map[string]string{}
	for element in css.query_selector_all(root, 'link[rel][href]') {
		if element.get_attribute_value('rel').to_lower().split(' ').any(it == 'stylesheet')
			|| link_is_style_preload(element) {
			types[resolve_document_reference(element.get_attribute_value('href'), base_url)] = 'stylesheet'
		}
	}
	if browser_document_can_load_scripts(document) {
		for element in css.query_selector_all(root, 'script[src]') {
			resource_url := resolve_document_reference(element.get_attribute_value('src'), base_url)
			if resource_url !in types { types[resource_url] = 'script' }
		}
	}
	return types
}
