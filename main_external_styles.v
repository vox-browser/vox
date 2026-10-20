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
	for element in css.query_selector_all(root, 'link[rel][href][title], style[title]') {
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
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
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

// Scripts can insert stylesheet links after the initial resources; 4chan's
// catalog links its theme this way. After the DOM tree changes, request each
// new remote one in the background. The CSS bridge installs it, in the link's
// tree position, once its text arrives. A sheet the disk cache holds is
// installed at once, so the document is not laid out and painted without it
// first. Returns whether any sheet was installed.
fn (mut app BrowserApp) request_script_inserted_stylesheets() bool {
	if app.document == unsafe { nil } {
		return false
	}
	version := app.document.dom_tree_version()
	if version == app.script_stylesheet_scan_version {
		return false
	}
	app.script_stylesheet_scan_version = version
	root := unsafe { &dom.Node(app.document) }
	base_url := app.document.base_url().to_string()
	source_url := app.document.url.serialize()
	preferred_set_name := preferred_style_sheet_set_name(root)
	mut installed := false
	for link in css.query_selector_all(root, 'link[rel][href]') {
		if !link_stylesheet_applies(link, preferred_set_name) {
			continue
		}
		resolved_url := css.link_style_sheet_url(link.get_attribute_value('href'), base_url) or {
			continue
		}
		if (!resolved_url.starts_with('http://') && !resolved_url.starts_with('https://'))
			|| resolved_url in app.script_stylesheet_requests
			|| css.has_remote_link_style_sheet(resolved_url) || link_stylesheet_is_inlined(link, resolved_url) {
			continue
		}
		app.script_stylesheet_requests[resolved_url] = true
		// The navigation already requested the parser's sheets. One that
		// failed is not requested again when the page is installed.
		if resolved_url in app.navigation_preloaded_resources {
			continue
		}
		if cached := disk_cached_browser_resource(resolved_url, source_url, 'stylesheet') {
			if app.install_script_inserted_stylesheet(cached) {
				installed = true
			}
			continue
		}
		spawn fetch_stylesheet_in_background(resolved_url, source_url, app.background_resource_results)
	}
	return installed
}

// A parsed link's remote stylesheet is inlined as the <style> after it.
fn link_stylesheet_is_inlined(link &dom.Element, resolved_url string) bool {
	next := link.as_node().next_sibling() or { return false }
	style := next.as_element() or { return false }
	return style.local_name() == 'style'
		&& style.get_attribute_value('data-libweb-v-source-url') == resolved_url
}

fn fetch_stylesheet_in_background(resource_url string, source_url string, results chan PreloadedResource) {
	fetch_resource_in_background(resource_url, source_url, 'stylesheet', results)
	$if macos {
		C.native_wake_browser()
	}
}

// Publish a completed stylesheet request to the CSS bridge. Returns whether the
// document's styles changed.
fn (mut app BrowserApp) install_script_inserted_stylesheet(resource PreloadedResource) bool {
	if resource.request_type != 'stylesheet' || resource.url !in app.script_stylesheet_requests
		|| app.document == unsafe { nil } {
		return false
	}
	filtered := filter_preloaded_resource(resource, app.document.url.serialize(), 'stylesheet') or {
		app.js_messages << 'Stylesheet ${resource.url}: ${err.msg()}'
		return false
	}
	css.set_remote_link_style_sheet(resource.url, filtered.body)
	return true
}
