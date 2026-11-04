module layout

import css
import dom
import os

// Only the native viewport recording path enables this projection. Layout and
// DOM paintable geometry remain complete. Any scroll, geometry query, paint
// style update, or full-document recording restores the ordinary transport.
fn viewport_paint_interest(document &dom.Document) LayoutRect {
	viewport := document.layout_viewport_rect()
	return LayoutRect{viewport.x - viewport.width, viewport.y - viewport.height,
		viewport.width * 3, viewport.height * 3}
}

fn paint_interest_can_omit(node &Node, state &LayoutState, interest LayoutRect) bool {
	owner := state.block_paint_owners_[u64(voidptr(node))] or { return false }
	if owner.inputs.len == 0 || voidptr(owner.inputs[0].node) != voidptr(node) { return false }
	computed := node.computed_values()
	// Hidden overflow clips to the padding box, inside the border box below.
	// Clip margins, scrollbars and escaping positioned descendants are excluded.
	if computed.overflow_x() != .hidden || computed.overflow_y() != .hidden
		|| computed.box_shadow().len != 0 || computed.outline_style() != .none_ {
		return false
	}
	styled := node.as_node_with_style() or { return false }
	used := state.try_get(styled) or { return false }
	position := paint_cumulative_offset(node, state, used)
	geometry := ordinary_paint_geometry(used)
	border := LayoutRect{position.x().to_double() - geometry.padding.left - geometry.border.left,
		position.y().to_double() - geometry.padding.top - geometry.border.top,
		used.border_box_width().to_double(), used.border_box_height().to_double()}
	if !retained_paint_rect_can_translate(border, 0, 0) { return false }
	if border.x < interest.x + interest.width && border.x + border.width > interest.x
		&& border.y < interest.y + interest.height && border.y + border.height > interest.y {
		return false
	}
	// Retained independent-flow inputs exclude positioned/replaced/SVG and
	// generated content. Also keep offscreen snap targets and transformed CSSOM
	// geometry represented in the ordinary transport.
	for input in owner.inputs {
		style := input.node.computed_values()
		if !computed_transform_is_none(style) || style.perspective() != none
			|| style.scroll_snap_align() != css.ScrollSnapAlignData{}
			|| style.background_layers().len != 0 || style.mask() != none
			|| style.mask_image() != none || style.clip_path() != none { return false }
	}
	mut ancestor := ?&Node(node)
	for ancestor != none {
		current := ancestor or { break }
		style := current.computed_values()
		if current.is_svg_box() || style.position() in [.fixed, .sticky]
			|| style.has_animated_properties() || !computed_transform_is_none(style)
			|| style.perspective() != none || style.filter().has_filters()
			|| style.backdrop_filter().has_filters() { return false }
		if voidptr(current) != voidptr(node) && !current.is_viewport()
			&& (style.overflow_x() in [.hidden, .auto_, .scroll]
				|| style.overflow_y() in [.hidden, .auto_, .scroll]) { return false }
		ancestor = current.parent()
	}
	return true
}

fn fill_omitted_paint_box(node &Node, state &LayoutState, mut output BlockBox) {
	styled := node.as_node_with_style() or { output = BlockBox{}; return }
	used := state.try_get(styled) or { output = BlockBox{}; return }
	position := paint_cumulative_offset(node, state, used)
	geometry := ordinary_paint_geometry(used)
	owner := node.dom_node() or { output = BlockBox{}; return }
	element := owner.as_element() or { output = BlockBox{}; return }
	output = BlockBox{
		tag_name: element.local_name()
		x: position.x().to_double()
		y: position.y().to_double()
		width: geometry.width
		height: geometry.height
		margin: geometry.margin
		border: geometry.border
		padding: geometry.padding
		node_id: i64(owner.unique_id())
		layout_handle: voidptr(node)
		visible: false
		pointer_events_enabled: false
	}
}

// Same-binary control: every paint style update restores the full transport.
const disable_projection_style_updates = os.getenv('VOX_DISABLE_PROJECTION_STYLE_UPDATES') != ''

// A paint style update can apply to the viewport projection when every
// updated box is retained and meets the paint interest: an omitted subtree's
// root lies entirely outside it and its descendants are absent. vlang.io
// updates a progress bar's transform every frame, and restoring the complete
// transport for it rebuilt the whole document's renderer snapshot.
fn paint_style_updates_fit_projection(mut result DocumentLayoutResult) bool {
	if !result.paint_projection_incomplete || result.paint_style_update_requires_full_refresh
		|| disable_projection_style_updates || result.paint_style_update_handles.len() == 0 {
		return false
	}
	interest := result.paint_projection_interest or { return false }
	for handle in result.paint_style_update_handles.items {
		box := result.retained_box_for_layout(voidptr(handle)) or { return false }
		if !(box.x < interest.x + interest.width && box.x + box.width > interest.x
			&& box.y < interest.y + interest.height && box.y + box.height > interest.y) {
			return false
		}
	}
	return true
}

fn restore_complete_paint_projection(mut result DocumentLayoutResult) bool {
	if !result.paint_projection_incomplete { return false }
	if paint_refresh_diagnostics { eprintln('VOX_PAINT_REFRESH reason=restore-projection') }
	result.paint_projection_interest = none
	result.paint_projection_incomplete = false
	viewport := result.document.viewport_rect()
	refresh_document_paint_tree(result.document, mut result, viewport.width, viewport.height)
	viewport_refresh_scroll_state(voidptr(&result))
	return true
}
