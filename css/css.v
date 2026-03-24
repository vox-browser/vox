// Stub module for CSS-related functions called by Document
module css

import dom

// --- Style invalidation ---

pub enum StyleInvalidationReason {
	base_url_changed
	hover_changed
	style_sheet_changed
	dom_mutation
}

pub fn invalidate_style(doc &dom.Document, reason StyleInvalidationReason) {
	// Stub: would invalidate style for the given reason
}

// --- CSS Parsing stubs ---

pub struct ParsingParams {
pub:
	document &dom.Document = unsafe { nil }
}

pub enum PropertyID {
	color
	color_scheme
	content_visibility
}

pub fn parse_css_value(context ParsingParams, text string, property PropertyID) ?&dom.StyleValue {
	return none
}

pub fn parse_media_query(context ParsingParams, text string) ?&MediaQuery {
	return none
}

@[heap]
pub struct MediaQuery {}

pub fn (mq &MediaQuery) evaluate(doc &dom.Document) bool {
	return true
}

// --- Color resolution ---

pub struct ColorResolutionContext {}

pub fn color_resolution_context_for_layout_node(node &dom.LayoutNode) ColorResolutionContext {
	return ColorResolutionContext{}
}

// --- ContentVisibility ---

pub enum ContentVisibility {
	auto_
	visible
	hidden
}

// --- RequiredInvalidationAfterStyleChange ---

pub struct RequiredInvalidationAfterStyleChange {
pub mut:
	relayout             bool
	rebuild_layout_tree  bool
	rebuild_stacking_context_tree bool
}

pub fn (r RequiredInvalidationAfterStyleChange) is_none() bool {
	return !r.relayout && !r.rebuild_layout_tree && !r.rebuild_stacking_context_tree
}

// --- StyleComputer user agent source ---

pub fn user_agent_style_sheet_source(url string) ?string {
	return none
}
