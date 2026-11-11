module css

import dom

fn test_overflow_clip_margin_refreshes_existing_visual_clips() {
	for property in [PropertyID.overflow_clip_margin_top, .overflow_clip_margin_right,
		.overflow_clip_margin_bottom, .overflow_clip_margin_left,
		.overflow_clip_margin_block_start, .overflow_clip_margin_block_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_inline_end] {
		invalidation := compute_property_invalidation(property,
			&dom.StyleValue{css_text: '0px'}, &dom.StyleValue{css_text: '10px'})
		assert invalidation.accumulated_visual_contexts() == .update_values
		assert invalidation.needs_repaint()
		assert invalidation.needs_relayout()
	}
	unchanged := compute_property_invalidation(.overflow_clip_margin_left,
		&dom.StyleValue{css_text: '10px'}, &dom.StyleValue{css_text: '10px'})
	assert unchanged.is_none()
}
