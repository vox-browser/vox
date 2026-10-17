module main

import adblock
import browsernet
import css
import dom
import os
import url

// Remote link stylesheets are inlined as <style> elements, which have no
// alternate flag. Resolve the CSSOM preferred style sheet set here instead:
// its name is the title of the first enabled, non-alternate titled sheet in
// tree order. A titled stylesheet, alternate or not, applies only when its
// title names that set; untitled alternates never apply.
fn preferred_style_sheet_set_name(root &dom.Node) string {
	for element in css.query_selector_all(root, 'link[rel][href], style') {
		title := element.get_attribute_value('title')
		if title == '' {
			continue
		}
		if element.local_name() == 'style' {
			return title
		}
		relations := link_relations(element)
		if 'stylesheet' in relations && 'alternate' !in relations
			&& !element.has_attribute('disabled') {
			return title
		}
	}
	return ''
}

fn link_relations(link &dom.Element) []string {
	return link.get_attribute_value('rel').to_lower().fields()
}

fn link_stylesheet_applies(link &dom.Element, preferred_set_name string) bool {
	relations := link_relations(link)
	if 'stylesheet' !in relations || link.has_attribute('disabled') {
		return false
	}
	title := link.get_attribute_value('title')
	if title == '' {
		return 'alternate' !in relations
	}
	return title == preferred_set_name
}

fn install_external_styles(document &dom.Document, base_url string, preloaded map[string]PreloadedResource) []string {
	root := unsafe { &dom.Node(document) }
	mut messages := []string{}
	preferred_set_name := preferred_style_sheet_set_name(root)
	for link in css.query_selector_all(root, 'link[rel][href]') {
		if !link_stylesheet_applies(link, preferred_set_name) {
			continue
		}
		href := link.get_attribute_value('href')
		resolved_url := resolve_document_reference(href, base_url)
		_ := browsernet.filter(adblock.Request{url: resolved_url, source_url: document.url.serialize(), request_type: 'stylesheet'}) or {
			messages << 'Stylesheet ${href}: ${err.msg()}'
			continue
		}
		if resolved_url.starts_with('file://') {
			path := url.percent_decode(resolved_url['file://'.len..]).bytestr()
			if path != '' && os.is_file(path) {
				// The CSS bridge reads local link stylesheets itself and retains their URL.
				continue
			}
		}
		stylesheet := if resource := preloaded[resolved_url] {
			filtered_resource := filter_preloaded_resource(resource, document.url.serialize(), 'stylesheet') or {
				messages << 'Stylesheet ${href}: ${err.msg()}'
				continue
			}
			filtered_resource.body
		} else {
			fetch_text_resource_for_request(href, base_url, document.url.serialize(), 'stylesheet') or {
				messages << 'Stylesheet ${href}: ${err.msg()}'
				continue
			}
		}
		mut style := document.create_element('style') or { continue }
		style.set_attribute_value('data-libweb-v-source-url', resolved_url)
		style.set_attribute_value('media', link.get_attribute_value('media'))
		mut style_node := unsafe { &dom.Node(style) }
		style_node.set_text_content(stylesheet) or { continue }
		// Cascade order follows tree order, so the inlined sheet takes its link's
		// place ahead of later <style> elements and links.
		link_node := link.as_node()
		mut parent := link_node.parent_node() or { continue }
		parent.pre_insert(style.as_node(), link_node.next_sibling()) or { continue }
	}
	return messages
}
