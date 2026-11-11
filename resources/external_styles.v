module main

import adblock
import browsernet
import css
import dom
import html
import os
import platform
import url

fn load_browser_imported_style_sheet(document &dom.Document, address string) ?css.ImportedStyleSheetSource {
	if document.is_svg_image_document() && dom.URL{value: address}.scheme() != 'data' { return none }
	resource := fetch_browser_resource(address, document.base_url().serialize(),
		document.url.serialize(), 'stylesheet') or { return none }
	mut content_type := ''
	for header in resource.response_headers {
		if header.name.to_lower() == 'content-type' { content_type = header.value }
	}
	return css.ImportedStyleSheetSource{
		css_text:     resource.body
		response_url: resource.final_url
		content_type: content_type
		// This adapter does not retain the redirect chain's Fetch tainting.
		// Keep the quirks-mode MIME exemption disabled rather than inferring
		// CORS-same-origin from the last URL of a potentially opaque response.
		cors_same_origin: false
	}
}

// Resolve the CSSOM preferred style sheet set before fetching resources:
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

fn link_is_style_preload(link &dom.Element) bool {
	return 'preload' in link_relations(link)
		&& link.get_attribute_value('as').to_lower() == 'style'
		&& link.get_attribute_value('type').split(';')[0].trim_space().to_lower() in ['', 'text/css']
}

fn link_stylesheet_applies(link &dom.Element, preferred_set_name string) bool {
	if link.document().is_svg_image_document() {
		address := dom.dom_url_parse(link.get_attribute_value('href'), link.document().base_url(), 'UTF-8') or { return false }
		if address.scheme() != 'data' { return false }
	}
	relations := link_relations(link)
	if 'stylesheet' !in relations || link.has_attribute('disabled') {
		return false
	}
	if !html.is_supported_style_sheet_type_attribute(link.get_attribute_ns(none, 'type')) {
		return false
	}
	title := link.get_attribute_value('title')
	if title == '' {
		return 'alternate' !in relations
	}
	return title == preferred_set_name
}

fn install_external_styles(document &dom.Document, base_url string, preloaded map[string]PreloadedResource) []string {
	return install_external_styles_with_existing_policy(document, base_url, preloaded, false)
}

// Keep CSSOM mutations made by an earlier parser-time script when another
// script or the completed document needs its stylesheets installed.
fn install_parser_external_styles(document &dom.Document, base_url string, preloaded map[string]PreloadedResource) []string {
	return install_external_styles_with_existing_policy(document, base_url, preloaded, true)
}

fn install_external_styles_with_existing_policy(document &dom.Document, base_url string, preloaded map[string]PreloadedResource, preserve_existing bool) []string {
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	root := unsafe { &dom.Node(document) }
	mut messages := []string{}
	preferred_set_name := preferred_style_sheet_set_name(root)
	for link in css.query_selector_all(root, 'link[rel][href]') {
		if !link_stylesheet_applies(link, preferred_set_name) {
			continue
		}
		if preserve_existing && unsafe { &dom.HTMLLinkElement(link) }.linked_style_sheet_ != unsafe { nil } {
			continue
		}
		href := link.get_attribute_value('href')
		resolved_url := resolve_document_reference(href, base_url)
		_ := browsernet.filter(adblock.Request{ url: resolved_url, source_url: document.url.serialize(), request_type: 'stylesheet' }) or {
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
		resource := if resource := preloaded[resolved_url] {
			filtered_resource := filter_preloaded_resource(resource, document.url.serialize(), 'stylesheet') or {
				messages << 'Stylesheet ${href}: ${err.msg()}'
				continue
			}
			filtered_resource
		} else {
			fetch_browser_resource(resolved_url, '', document.url.serialize(), 'stylesheet') or {
				messages << 'Stylesheet ${href}: ${err.msg()}'
				continue
			}
		}
		complete_browser_link_stylesheet(link, resource)
	}
	return messages
}

// Install the actual link-owned CSSOM sheet before dispatching its completion
// event. An adjacent synthetic <style> cannot supply LinkStyle.sheet or retain
// CSSOM edits on the link, and makes late load listeners wait forever. Report
// whether the owned sheet changed, including removal after a failed replacement.
fn complete_browser_link_stylesheet(link &dom.Element, resource PreloadedResource) bool {
	mut allocations := link.document().enter_native_storage()
	defer { allocations.finish() }
	native_link := unsafe { &dom.HTMLLinkElement(link) }
	previous_sheet := native_link.linked_style_sheet_
	mut content_type := ''
	for header in resource.response_headers {
		if header.name.to_lower() == 'content-type' { content_type = header.value }
	}
	address := if resource.final_url == '' { resource.url } else { resource.final_url }
	mut model := html.html_link_element_model_for_dom_element(native_link)
	model.set_external_stylesheet_fetcher(true)
	html.html_link_element_process_stylesheet_resource(native_link,
		resource.error == '', html.LinkResourceResponse{
			content_type: content_type
			body:         resource.body.bytes()
			original_url: dom.URL{ value: resource.url }
			url:          dom.URL{ value: address }
			// The browser adapter does not establish a CORS response. Opaque
			// sheets may style the page, but their rules must remain private.
			origin_clean: resource.error == '' && dom.URL{ value: address }.origin().is_same_origin(link.document().origin())
		})
	return previous_sheet != native_link.linked_style_sheet_
}

// Scripts can insert stylesheet links after the initial resources; 4chan's
// catalog links its theme this way. After the DOM tree changes, request each
// new remote one in the background. The CSS bridge installs it, in the link's
// tree position, once its text arrives. A sheet the disk cache holds is
// installed at once, so the document is not laid out and painted without it
// first. Returns whether an owned sheet was installed, removed, or replaced.
fn (mut app BrowserApp) request_script_inserted_stylesheets() bool {
	if app.state == .retired || app.document == unsafe { nil } {
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
		if !resolved_url.starts_with('http://') && !resolved_url.starts_with('https://') {
			continue
		}
		identity := link.as_node().unique_id()
		native_link := unsafe { &dom.HTMLLinkElement(link) }
		model := html.html_link_element_model_for_dom_element(native_link)
		if app.script_stylesheet_links[identity] == resolved_url && !model.is_stylesheet_loading() { continue }
		app.script_stylesheet_links[identity] = resolved_url
		if native_link.linked_style_sheet_from_resource_ && !model.is_stylesheet_loading() {
			continue
		}
		if resource := app.script_stylesheet_responses[resolved_url] {
			if complete_browser_link_stylesheet(link, resource) { installed = true }
			continue
		}
		// The navigation already requested the parser's sheets. One that
		// failed is not requested again when the page is installed. Complete
		// every link owner before deduplicating new transport requests.
		if resource := app.navigation_preloaded_resources[resolved_url] {
			app.script_stylesheet_requests[resolved_url] = true
			if complete_browser_link_stylesheet(link, resource) { installed = true }
			continue
		}
		if resolved_url in app.script_stylesheet_requests { continue }
		app.script_stylesheet_requests[resolved_url] = true
		if cached := disk_cached_browser_resource(resolved_url, source_url, 'stylesheet') {
			if app.install_script_inserted_stylesheet(cached) {
				installed = true
			}
			continue
		}
		persistent := platform.enter_persistent()
		owned_url := resolved_url.clone()
		owned_source := source_url.clone()
		app.background_resource_pending[owned_url] = true
		app.background_resource_jobs++
		scope := app.resource_request_scope()
		scope.retain()
		spawn fetch_stylesheet_in_background_with_scope(owned_url, owned_source, app.background_resource_results, scope)
		platform.leave_persistent(persistent)
	}
	return installed
}

fn fetch_stylesheet_in_background(resource_url string, source_url string, results chan PreloadedResource) {
	fetch_resource_in_background(resource_url, source_url, 'stylesheet', results)
	$if macos {
		C.native_wake_browser()
	}
}

fn fetch_stylesheet_in_background_with_scope(resource_url string, source_url string, results chan PreloadedResource, scope &browsernet.RequestScope) {
	fetch_resource_in_background_with_scope(resource_url, source_url, 'stylesheet', results, scope)
	$if macos { C.native_wake_browser() }
}

// Publish a completed stylesheet request to the CSS bridge. Returns whether the
// document's styles changed.
fn (mut app BrowserApp) install_script_inserted_stylesheet(resource PreloadedResource) bool {
	if resource.request_type != 'stylesheet' || resource.url !in app.script_stylesheet_requests
		|| app.document == unsafe { nil } {
		return false
	}
	mut allocations := app.document.enter_native_storage()
	defer { allocations.finish() }
	filtered := filter_preloaded_resource(resource, app.document.url.serialize(), 'stylesheet') or {
		app.js_messages << 'Stylesheet ${resource.url}: ${err.msg()}'
		PreloadedResource{ ...resource, body: '', error: err.msg() }
	}
	retained := PreloadedResource{
		...filtered
		url:              filtered.url.clone()
		body:             filtered.body.clone()
		error:            filtered.error.clone()
		final_url:        filtered.final_url.clone()
		source_url:       filtered.source_url.clone()
		request_type:     filtered.request_type.clone()
		response_headers: filtered.response_headers.map(adblock.ResponseHeader{ name: it.name.clone(), value: it.value.clone() })
	}
	app.script_stylesheet_responses[resource.url.clone()] = retained
	if retained.error == '' {
		mut content_type := ''
		for header in retained.response_headers {
			if header.name.to_lower() == 'content-type' { content_type = header.value }
		}
		css.set_remote_link_style_sheet_response(resource.url, css.ImportedStyleSheetSource{
			css_text: retained.body
			response_url: if retained.final_url == '' { retained.url } else { retained.final_url }
			content_type: content_type
		})
	}
	mut installed := false
	for link in css.query_selector_all(app.document.as_node(), 'link[rel][href]') {
		if !link_stylesheet_applies(link, preferred_style_sheet_set_name(app.document.as_node())) {
			continue
		}
		resolved := css.link_style_sheet_url(link.get_attribute_value('href'), app.document.base_url().serialize()) or { continue }
		if resolved != resource.url { continue }
		if complete_browser_link_stylesheet(link, retained) { installed = true }
		app.script_stylesheet_links[link.as_node().unique_id()] = resolved
	}
	return installed
}
