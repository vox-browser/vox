module main

import dom
import layout
import css

// Bounded, read-only snapshots of the committed layout tree, including control
// shadow boxes. Coordinates and font sizes use the tree's layout units.
struct CaptureAuditLayoutBudget {
mut:
	remaining int = 32
}

struct CaptureAuditLayout {
	parent             int = -1
	tag                string
	id                 string
	anonymous          bool
	text               bool
	scale              f64
	font_size          f64
	line_height        f64
	width              f64
	height             f64
	x                  f64
	y                  f64
	css_width          string
	css_height         string
	css_min_width      string
	css_min_height     string
	flex_grow          f32
	flex_shrink        f32
	namespace          string
	element_css_width  string
	element_css_height string
}

fn (app &BrowserApp) capture_audit_layout(element &dom.Element, depth int) []CaptureAuditLayout {
	if depth == 0 { return []CaptureAuditLayout{} }
	bridge := element.as_node().layout_node() or { return []CaptureAuditLayout{} }
	if bridge.layout_handle == unsafe { nil } { return []CaptureAuditLayout{} }
	result := layout.document_layout_result(app.document) or { return []CaptureAuditLayout{} }
	node := unsafe { &layout.Node(bridge.layout_handle) }
	mut budget := CaptureAuditLayoutBudget{}
	mut nodes := []CaptureAuditLayout{}
	capture_audit_layout_node(node, result, depth, -1, mut budget, mut nodes)
	return nodes
}

fn capture_audit_layout_node(node &layout.Node, result &layout.DocumentLayoutResult, depth int,
	parent int, mut budget CaptureAuditLayoutBudget, mut nodes []CaptureAuditLayout) {
	budget.remaining--
	mut tag := ''
	mut id := ''
	mut namespace := ''
	mut element_css_width := ''
	mut element_css_height := ''
	if dom_node := node.dom_node() {
		if element := dom_node.as_element() {
			tag = element.local_name()
			id = element.get_attribute_value('id')
			namespace = element.namespace_uri() or { '' }
			if computed := css.computed_properties_for_element(element) {
				element_css_width = if value := computed.property(.width, .no) {
					value.css_text
				} else {
					''
				}
				element_css_height = if value := computed.property(.height, .no) {
					value.css_text
				} else {
					''
				}
			}
		}
	}
	mut width := 0.0
	mut height := 0.0
	mut x := 0.0
	mut y := 0.0
	if styled := node.as_node_with_style() {
		if used := result.used_values_for(styled) {
			width = used.content_width().to_double()
			height = used.content_height().to_double()
			x = used.offset.x().to_double()
			y = used.offset.y().to_double()
		}
	}
	style := node.computed_values()
	index := nodes.len
	nodes << CaptureAuditLayout{
		parent:             parent
		tag:                tag
		id:                 id
		anonymous:          node.is_anonymous()
		text:               node.is_text_node()
		scale:              style.layout_coordinate_scale()
		font_size:          style.resolved_font_size_px()
		line_height:        style.line_height().to_double()
		width:              width
		height:             height
		x:                  x
		y:                  y
		css_width:          style.width().to_string()
		css_height:         style.height().to_string()
		css_min_width:      style.min_width().to_string()
		css_min_height:     style.min_height().to_string()
		flex_grow:          style.flex_grow()
		flex_shrink:        style.flex_shrink()
		namespace:          namespace
		element_css_width:  element_css_width
		element_css_height: element_css_height
	}
	if depth > 1 {
		for child in node.children() {
			if budget.remaining <= 0 { break }
			capture_audit_layout_node(child, result, depth - 1, index, mut budget, mut nodes)
		}
	}
}
