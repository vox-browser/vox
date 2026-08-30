// HTML document-facing constants and integration helpers. Algorithms live in
// source-named files in this module.
module html

import dom
import math

pub fn url_matches_about_blank(url dom.URL) bool {
	return url.value == 'about:blank'
}

pub fn url_matches_about_srcdoc(url dom.URL) bool {
	return url.value == 'about:srcdoc'
}

// --- Event names ---
pub const event_load = 'load'
pub const event_unload = 'unload'
pub const event_pagehide = 'pagehide'
pub const event_readystatechange = 'readystatechange'
pub const event_visibilitychange = 'visibilitychange'
pub const event_error = 'error'
pub const event_enter = 'enter'
pub const event_exit = 'exit'
pub const event_cuechange = 'cuechange'
pub const event_change = 'change'
pub const event_addtrack = 'addtrack'
pub const event_removetrack = 'removetrack'

// --- Tag names ---
pub const tag_html = 'html'
pub const tag_head = 'head'
pub const tag_body = 'body'
pub const tag_div = 'div'
pub const tag_title = 'title'

// --- Attribute names ---
pub const attr_text = 'text'
pub const attr_link = 'link'
pub const attr_vlink = 'vlink'
pub const attr_alink = 'alink'
pub const attr_bgcolor = 'bgcolor'
pub const attr_href = 'href'
pub const attr_target = 'target'
pub const attr_content = 'content'
pub const attr_name = 'name'
pub const attr_media = 'media'

// --- Namespace ---
pub const namespace_html = 'http://www.w3.org/1999/xhtml'

// --- DocumentReadyState (HTML version) ---
pub enum DocumentReadyState {
	loading
	interactive
	complete
}

pub fn idl_enum_to_string(value dom.NavigationType) string {
	return match value {
		.push { 'push' }
		.replace { 'replace' }
		.reload { 'reload' }
		.traverse { 'traverse' }
	}
}

// https://drafts.csswg.org/cssom-view/#normalize-non-finite-values
pub fn normalize_non_finite_values(value f64) f64 {
	return if math.is_inf(value, 0) || math.is_nan(value) { 0.0 } else { value }
}

pub fn normalize_optional_non_finite_values(value ?f64) f64 {
	return normalize_non_finite_values(value or { 0.0 })
}

// --- VisibilityState (HTML version) ---
pub enum VisibilityState {
	visible
	hidden
}

pub fn is_html_frame_set_element(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.namespace_uri() or { '' } == namespace_html && element.local_name() == 'frameset'
}
