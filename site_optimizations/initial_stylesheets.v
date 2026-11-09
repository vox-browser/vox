module main

import dom
import os

const github_primer_stylesheet_url = 'https://github.githubassets.com/assets/primer-react-css.7123e0f1ca4d1d27.module.css'
const github_primer_layer_order = '@layer primer-react;@layer primer.components.IssueLabel;'
const github_primer_brand_stylesheet_url = 'https://github.githubassets.com/assets/primer-react-brand-css.6485cac7edcdca27.module.css'
const github_primer_brand_layer_order = '@layer primer-brand;'
const disable_github_initial_stylesheet_dedup = os.getenv('VOX_DISABLE_GITHUB_INITIAL_STYLESHEET_DEDUP') != ''
const disable_github_brand_stylesheet_dedup = os.getenv('VOX_DISABLE_GITHUB_BRAND_STYLESHEET_DEDUP') != ''
const github_initial_stylesheet_diagnostics = os.getenv('VOX_GITHUB_INITIAL_STYLESHEET_DIAGNOSTICS') != ''

// Run during initial document setup, before stylesheet preload.
// The last identical sheet dominates the earlier copies; the marker preserves
// their first layer declarations, including important-layer precedence.
fn prepare_site_document_stylesheets(document &dom.Document) int {
	if disable_github_initial_stylesheet_dedup || !document.is_scripting_enabled_by_embedder()
		|| !site_batches_image_completion_layout(document.url.serialize()) {
		return 0
	}
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	mut removed := prepare_site_stylesheet_copies(document, github_primer_stylesheet_url,
		github_primer_layer_order)
	if !disable_github_brand_stylesheet_dedup {
		removed += prepare_site_stylesheet_copies(document, github_primer_brand_stylesheet_url,
			github_primer_brand_layer_order)
	}
	if github_initial_stylesheet_diagnostics && removed > 0 {
		eprintln('Vox site optimization: removed ${removed} duplicate initial GitHub stylesheets')
	}
	return removed
}

// Only the reviewed, content-addressed assets above are eligible. In
// particular, the Brand asset has one named layer and no imports or anonymous
// layers. Each family needs its own marker at its original first position.
fn prepare_site_stylesheet_copies(document &dom.Document, stylesheet_url string,
	layer_order string) int {
	mut copies := []&dom.Element{}
	mut pending := [document.as_node()]
	for pending.len > 0 {
		node := pending.pop()
		if element := node.as_element() {
			if element.is_html_element() && element.local_name() == 'link'
				&& element.get_attribute_value('rel').to_lower() == 'stylesheet'
				&& element.get_attribute_value('href') == stylesheet_url
				&& element.get_attribute_value('media').trim_space().to_lower() in ['', 'all']
				&& element.get_attribute_value('title') == ''
				&& !element.has_attribute('disabled') && !element.has_attribute('integrity')
				&& !element.has_attribute('nonce') && !element.has_attribute('id')
				&& !element.has_attribute('onload') && !element.has_attribute('onerror') {
				copies << element
			}
		}
		// GitHub emits component entry sheets beside body-mounted React roots.
		// Traverse the ordinary DOM in tree order, excluding inert template and
		// shadow contents, before creating the replacement layer marker.
		for index := node.children.len - 1; index >= 0; index-- {
			pending << node.children[index]
		}
	}
	if copies.len < 2 { return 0 }
	// The same URL is not an equivalent request when credentials or referrer
	// policy differ. Keep all owners in that case, including a working earlier
	// sheet when a differently fetched last copy could fail.
	for copy in copies[1..] {
		if copy.has_attribute('crossorigin') != copies[0].has_attribute('crossorigin')
			|| copy.get_attribute_value('crossorigin') != copies[0].get_attribute_value('crossorigin')
			|| copy.get_attribute_value('referrerpolicy') != copies[0].get_attribute_value('referrerpolicy') {
			return 0
		}
	}
	mut marker := document.create_element('style') or { return 0 }
	marker.as_node().set_text_content(layer_order) or { return 0 }
	mut parent := copies[0].as_node().parent() or { return 0 }
	parent.pre_insert(marker.as_node(), copies[0].as_node()) or { return 0 }
	base := marker.style_element_base() or { return 0 }
	if base.sheet() == unsafe { nil } {
		marker.as_node().remove(false)
		return 0
	}
	for copy in copies[..copies.len - 1] {
		copy.as_node().remove(false)
	}
	return copies.len - 1
}
