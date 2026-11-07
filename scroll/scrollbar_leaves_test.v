module main

import layout

// Deferred viewport scrollbars are a few rectangle leaves. Quartz draws them
// without a GPU round trip; anything else keeps the GPU batch.
fn test_scrollbar_leaves_quartz_drawable_kinds() {
	thumb := layout.PaintCommand{ kind: 'fill_rounded_rect', width: 8, height: 40, radius: 4,
		scrollbar_axis: 'vertical' }
	track := layout.PaintCommand{ kind: 'fill_rect', width: 12, height: 900, scrollbar_axis: 'vertical' }
	outline := layout.PaintCommand{ kind: 'stroke_rounded_rect', width: 8, height: 40, radius: 4,
		scrollbar_axis: 'vertical' }
	assert scrollbar_leaves_quartz_drawable([track, thumb, outline])
	assert !scrollbar_leaves_quartz_drawable([]layout.PaintCommand{})
	assert !scrollbar_leaves_quartz_drawable([thumb, layout.PaintCommand{ kind: 'draw_svg_path',
		scrollbar_axis: 'vertical' }])
	assert !scrollbar_leaves_quartz_drawable([layout.PaintCommand{ kind: 'paint_outer_box_shadow',
		scrollbar_axis: 'horizontal' }])
}
