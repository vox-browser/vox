module main

import dom
import os

const github_primer_stylesheet_url = 'https://github.githubassets.com/assets/primer-react-css.7123e0f1ca4d1d27.module.css'
const github_primer_layer_order = '@layer primer-react;@layer primer.components.IssueLabel;'
const disable_github_initial_stylesheet_dedup = os.getenv('VOX_DISABLE_GITHUB_INITIAL_STYLESHEET_DEDUP') != ''
const github_initial_stylesheet_diagnostics = os.getenv('VOX_GITHUB_INITIAL_STYLESHEET_DIAGNOSTICS') != ''

// Run before the real document's stylesheet preload and script bootstrap.
// The last identical sheet dominates the earlier copies; the marker preserves
// their first layer declarations, including important-layer precedence.
fn prepare_site_document_stylesheets(document &dom.Document) int {
	if disable_github_initial_stylesheet_dedup || !document.as_node().is_scripting_enabled()
		|| !site_batches_image_completion_layout(document.url.serialize()) {
		return 0
	}
	head := document.head() or { return 0 }
	mut copies := []&dom.Element{}
	mut current := head.as_node().first_child()
	for current != none {
		node := current or { break }
		if element := node.as_element() {
			if element.is_html_element() && element.local_name() == 'link'
				&& element.get_attribute_value('rel').to_lower() == 'stylesheet'
				&& element.get_attribute_value('href') == github_primer_stylesheet_url
				&& element.get_attribute_value('media').trim_space().to_lower() in ['', 'all']
				&& element.get_attribute_value('title') == ''
				&& !element.has_attribute('disabled') && !element.has_attribute('integrity')
				&& !element.has_attribute('nonce') && !element.has_attribute('id')
				&& !element.has_attribute('onload') && !element.has_attribute('onerror') {
				copies << element
			}
		}
		current = node.next_sibling()
	}
	if copies.len < 2 { return 0 }
	mut marker := document.create_element('style') or { return 0 }
	marker.as_node().set_text_content(github_primer_layer_order) or { return 0 }
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
	if github_initial_stylesheet_diagnostics {
		eprintln('Vox site optimization: removed ${copies.len - 1} duplicate initial GitHub stylesheets')
	}
	return copies.len - 1
}
