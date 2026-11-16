// vtest build: macos
module main

import layout

fn test_rectangle_clip_transfer_requires_a_containing_ordinary_clip_in_paint_space() {
	clip := layout.PaintClip{rect: layout.LayoutRect{10, 0, 60, 50}}
	command := layout.PaintCommand{
		kind: 'fill_rect'
		x: 10
		y: 10
		width: 20.9375
		height: 3
		antialiased_rect: true
		has_clip: true
		clip_list: &layout.PaintClipList{items: [clip]}
	}
	assert chromium_rectangle_clip_index(&command) == 0
	plain := layout.PaintCommand{...command, antialiased_rect: false}
	assert chromium_rectangle_clip_index_with_thin_rectangles(&plain, false) == -1
	assert chromium_rectangle_clip_index_with_thin_rectangles(&plain, true) == 0
	integer := layout.PaintCommand{...plain, width: 20}
	assert chromium_rectangle_clip_index_with_thin_rectangles(&integer, true) == -1
	nested := layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: [
		layout.PaintClip{rect: layout.LayoutRect{0, 0, 40, 13}}, clip,
	]}}
	assert chromium_rectangle_clip_contains(&nested, 0)
	assert chromium_rectangle_clip_contains(&nested, 1)
	assert chromium_rectangle_clip_bounds(&nested, 1) == [f32(10), 0, 40, 13]!
	for excluded in [
		layout.PaintClip{...clip, rect: layout.LayoutRect{11, 0, 60, 50}},
		layout.PaintClip{...clip, transform: [f64(1), 0, 0, 1, 1, 0]!},
		layout.PaintClip{...clip, is_path: true},
		layout.PaintClip{...clip, corner_radii: layout.BoxRadii{top_left: layout.CornerRadius{2, 2}}},
	] {
		candidate := layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: [excluded]}}
		assert chromium_rectangle_clip_index(&candidate) == -1
	}
}


fn test_duplicate_rectangle_clips_require_identical_finite_geometry_and_paint_space() {
	clip := layout.PaintClip{rect: layout.LayoutRect{150, 1499, 127, 42},
		transform: [f64(0.5), 0, 0, 0.5, 0, 0]!}
	other := layout.PaintClip{...clip, rect: layout.LayoutRect{0, 0, 2048, 4096}}
	command := layout.PaintCommand{kind: 'draw_text', clip_list: &layout.PaintClipList{items: [clip, other, clip]}}
	assert !chromium_duplicate_rectangle_clip(&command, 0)
	assert !chromium_duplicate_rectangle_clip(&command, 1)
	assert chromium_duplicate_rectangle_clip(&command, 2)
	for distinct in [
		layout.PaintClip{...clip, rect: layout.LayoutRect{150, 1499, 128, 42}},
		layout.PaintClip{...clip, transform: [f64(0.5), 0, 0, 0.5, 1, 0]!},
		layout.PaintClip{...clip, corner_radii: layout.BoxRadii{top_left: layout.CornerRadius{1, 1}}},
		layout.PaintClip{...clip, is_path: true},
		layout.PaintClip{...clip, is_svg_mask: true},
		layout.PaintClip{...clip, is_svg_content_mask: true},
		layout.PaintClip{...clip, rect: layout.LayoutRect{150, 1499, 0, 42}},
	] {
		paired := layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: [clip, distinct]}}
		assert !chromium_duplicate_rectangle_clip(&paired, 1)
	}
}
