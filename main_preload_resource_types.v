module main

import css
import dom

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
