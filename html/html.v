// HTML document-facing constants and integration helpers. Algorithms live in
// source-named files in this module.
module html

import dom

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

// --- VisibilityState (HTML version) ---
pub enum VisibilityState {
	visible
	hidden
}

pub fn is_html_frame_set_element(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return element.namespace_uri() or { '' } == namespace_html && element.local_name() == 'frameset'
}
