module dom

// All layout mirrors use the same bridge functions. Keep those functions in
// one immutable table; the opaque handle remains specific to each node.
pub struct LayoutNodeCallbacks {
pub:
	generated_content_text_callback fn (voidptr) ?string = unsafe { nil }
	first_letter_owner_callback fn (voidptr) ?&Element = unsafe { nil }
	find_matching_text_callback            fn (voidptr, string, CaseSensitivity) []&Range = unsafe { nil }
	inline_word_range_callback             fn (voidptr, int) ?&Range = unsafe { nil }
	apply_style_callback                   LayoutApplyStyleCallback                       = unsafe { nil }
	apply_animated_style_callback          LayoutApplyAnimatedStyleCallback               = unsafe { nil }
	apply_color_style_callback             LayoutApplyColorStyleCallback                  = unsafe { nil }
	clear_image_observers_callback         fn (voidptr)                             = unsafe { nil }
	set_needs_layout_update_callback       LayoutSetNeedsLayoutUpdateCallback       = unsafe { nil }
	invalidate_text_for_rendering_callback LayoutInvalidateTextForRenderingCallback = unsafe { nil }
	refresh_empty_text_fragment_callback   fn (voidptr) bool                        = unsafe { nil }
	anchor_size_value_callback fn (voidptr, string) ?string = unsafe { nil }
	view_transition_properties_callback    fn (voidptr) map[string]string           = unsafe { nil }
}

// Text and anonymous nodes usually have no used edges. A populated record is
// an immutable snapshot, independent of later mutations to the source state.
pub struct LayoutBoxModel {
pub:
	percentage_basis ?f64
	margin_left    f64
	margin_right   f64
	margin_top     f64
	margin_bottom  f64
	border_left    f64
	border_right   f64
	border_top     f64
	border_bottom  f64
	padding_left   f64
	padding_right  f64
	padding_top    f64
	padding_bottom f64
	inset_left     f64
	inset_right    f64
	inset_top      f64
	inset_bottom   f64
}

__global (
	empty_layout_node_callbacks = LayoutNodeCallbacks{}
	empty_layout_box_model      = LayoutBoxModel{}
)

pub fn (node &LayoutNode) bridge_callbacks() &LayoutNodeCallbacks {
	if node.callbacks_ == unsafe { nil } { return &empty_layout_node_callbacks }
	return node.callbacks_
}

// Layout joins the rendered text on either side of ordinary inline elements.
// A missing result keeps the embedder's single-node word selection policy.
// A successful query returns a temporary live Range. The caller finalizes it
// after consuming its boundary points.
pub fn (node &LayoutNode) inline_word_range(offset int) ?&Range {
	callback := node.bridge_callbacks().inline_word_range_callback
	if node.layout_handle == unsafe { nil } || callback == unsafe { nil } { return none }
	return callback(node.layout_handle, offset)
}

pub fn (node &LayoutNode) box_model() &LayoutBoxModel {
	if node.box_model_ == unsafe { nil } { return &empty_layout_box_model }
	return node.box_model_
}

pub fn (mut node LayoutNode) set_box_model(model LayoutBoxModel) {
	if model == LayoutBoxModel{} {
		node.box_model_ = unsafe { nil }
		return
	}
	if node.box_model_ != unsafe { nil } && *node.box_model_ == model { return }
	node.box_model_ = &LayoutBoxModel{ ...model }
}

// A split text box records its first-letter owner in layout, which may be
// across a slot or display:contents boundary from the DOM parent.
pub fn (node &LayoutNode) first_letter_owner() ?&Element {
	callback := node.bridge_callbacks().first_letter_owner_callback
	if callback == unsafe { nil } { return none }
	return callback(node.layout_handle)
}
