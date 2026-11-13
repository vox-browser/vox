module main

import layout
import math
import painting

fn test_replaced_image_gpu_clip_keeps_paths_masks_and_transformed_ancestors_native() {
	identity := [f64(1), 0, 0, 1, 0, 0]!
	radii := layout.BoxRadii{top_left: layout.CornerRadius{4, 4}}
	mut clips := [layout.PaintClip{corner_radii: radii, transform: identity},
		layout.PaintClip{is_path: true, corner_radii: radii, transform: identity},
		layout.PaintClip{is_svg_mask: true, corner_radii: radii, transform: identity},
		layout.PaintClip{is_svg_content_mask: true, corner_radii: radii, transform: identity},
		layout.PaintClip{corner_radii: radii, transform: [f64(1), 0, 0, 1, 0, 10]!}]
	command := layout.PaintCommand{
		kind: 'draw_replaced_image'
		has_clip: true
		transform: identity
		image_paintable: &painting.ImagePaintable{}
		clip_list: &layout.PaintClipList{items: clips}
	}
	assert replaced_image_gpu_ancestor_clip_index(&command) == 0
	video := layout.PaintCommand{...command, kind: 'draw_video',
		video_paintable: &painting.VideoPaintable{}}
	assert replaced_image_gpu_ancestor_clip_index(&video) == 0
	// The last eligible rounded clip moves to the image; all earlier entries
	// remain in their original order on the native context.
	clips << layout.PaintClip{corner_radii: radii, transform: identity}
	last := layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: clips}}
	assert replaced_image_gpu_ancestor_clip_index(&last) == 5
	video_last := layout.PaintCommand{...video, clip_list: last.clip_list}
	assert replaced_image_gpu_ancestor_clip_index(&video_last) == 5
}

fn test_video_gpu_clip_preserves_own_corners_and_ancestor_geometry() {
	clip := layout.PaintClip{
		rect: layout.LayoutRect{10, 20, 80, 50}
		corner_radii: layout.BoxRadii{top_left: layout.CornerRadius{7, 9}}
	}
	mut command := layout.PaintCommand{
		kind: 'draw_video'
		has_clip: true
		video_paintable: &painting.VideoPaintable{}
		clip_list: &layout.PaintClipList{items: [clip]}
	}
	index := replaced_image_gpu_ancestor_clip_index(&command)
	assert index == 0
	own_rect := painting.IntRect{11, 21, 78, 48}
	radii := painting.CornerRadii{
		top_left: painting.CornerRadius{3, 4}
	}
	assert replaced_image_gpu_clip_data(&command, own_rect, radii, index) ==
		[f32(10), 20, 80, 50, 7, 9, 0, 0, 0, 0, 0, 0]!
	command.video_paintable = &painting.VideoPaintable{
		border_radii: painting.BorderRadiiData{top_left: painting.BorderRadiusData{3, 4}}
	}
	assert replaced_image_gpu_ancestor_clip_index(&command) == -1
	assert replaced_image_gpu_clip_data(&command, own_rect, radii, -1) ==
		[f32(11), 21, 78, 48, 3, 4, 0, 0, 0, 0, 0, 0]!
}

fn test_replaced_image_gpu_clip_preserves_own_radii_and_rectangular_ancestors() {
	clip := layout.PaintClip{corner_radii: layout.BoxRadii{top_left: layout.CornerRadius{4, 4}}}
	command := layout.PaintCommand{
		kind: 'draw_replaced_image'
		has_clip: true
		image_paintable: &painting.ImagePaintable{border_radii: painting.BorderRadiiData{
			top_left: painting.BorderRadiusData{4, 4}
		}}
		clip_list: &layout.PaintClipList{items: [clip]}
	}
	assert replaced_image_gpu_ancestor_clip_index(&command) == -1
	no_rounding := layout.PaintCommand{...command,
		image_paintable: &painting.ImagePaintable{}
		clip_list: &layout.PaintClipList{items: [layout.PaintClip{}]}
	}
	assert replaced_image_gpu_ancestor_clip_index(&no_rounding) == -1
	missing := layout.PaintCommand{...no_rounding, clip_list: unsafe { nil }}
	assert replaced_image_gpu_ancestor_clip_index(&missing) == -1
	not_an_image := layout.PaintCommand{...command, kind: 'draw_video'}
	assert replaced_image_gpu_ancestor_clip_index(&not_an_image) == -1
}

fn test_replaced_image_transfers_an_integer_overflow_crop_to_the_gpu() {
	clip := layout.PaintClip{rect: layout.LayoutRect{4, 229, 242, 242}}
	command := layout.PaintCommand{
		kind: 'draw_replaced_image'
		has_clip: true
		image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{4, -12.90625, 484, 484}
		}
		clip_list: &layout.PaintClipList{items: [clip]}
	}
	assert replaced_image_gpu_ancestor_clip_index(&command) == 0
	assert replaced_image_gpu_clip_data(&command, painting.IntRect{4, -13, 484, 484},
		painting.CornerRadii{}, 0) == [f32(4), 229, 242, 242, 0, 0, 0, 0, 0, 0, 0, 0]!
	identical := layout.PaintCommand{...command,
		clip_list: &layout.PaintClipList{items: [layout.PaintClip{rect: layout.LayoutRect{4, -13, 484, 484}}]}}
	assert replaced_image_gpu_ancestor_clip_index(&identical) == 0
	for rect in [layout.LayoutRect{0, -100, 1000, 1000},
		layout.LayoutRect{4, 229.09375, 242, 242}, layout.LayoutRect{4, 229, 242.5, 242},
		layout.LayoutRect{4, 229, 0, 242}, layout.LayoutRect{800, 229, 242, 242},
		layout.LayoutRect{0, 229, 242, 242}, layout.LayoutRect{4, 229, math.inf(1), 242}] {
		other := layout.PaintCommand{...command,
			clip_list: &layout.PaintClipList{items: [layout.PaintClip{rect: rect}]}}
		assert replaced_image_gpu_ancestor_clip_index(&other) == -1
	}
	vector := layout.PaintCommand{...command,
		image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{4, -12.90625, 484, 484}
			is_svg_image: true
		}}
	assert replaced_image_gpu_ancestor_clip_index(&vector) == -1
	video := layout.PaintCommand{...command, kind: 'draw_video',
		video_paintable: &painting.VideoPaintable{}}
	assert replaced_image_gpu_ancestor_clip_index(&video) == -1
	inner := layout.PaintClip{rect: layout.LayoutRect{20, 240, 100, 100}}
	nested := layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: [clip, inner]}}
	assert replaced_image_gpu_ancestor_clip_index(&nested) == 1
	// Rounded clipping keeps its existing priority, even outside the rectangle.
	rounded := layout.PaintClip{rect: layout.LayoutRect{0, 0, 800, 800},
		corner_radii: layout.BoxRadii{top_left: layout.CornerRadius{4, 4}}}
	for clips in [[rounded, clip], [clip, rounded]] {
		combined := layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: clips}}
		index := replaced_image_gpu_ancestor_clip_index(&combined)
		assert clips[index].corner_radii.top_left.x == 4
	}
}

fn test_replaced_image_gpu_clip_keeps_fractional_radii_after_border_insets() {
	radius := painting.BorderRadiusData{4.5, 10}
	outer := painting.BorderRadiiData{radius, radius, radius, radius}
	insets := painting.PixelBox{ top: 0.25, right: 0.5, bottom: 0.75, left: 1.25 }
	image := layout.PaintCommand{
		kind:            'draw_replaced_image'
		image_paintable: &painting.ImagePaintable{ border_radii: outer, border_widths: insets }
	}
	video := layout.PaintCommand{
		kind:            'draw_video'
		video_paintable: &painting.VideoPaintable{ border_radii: outer, border_widths: insets }
	}
	for command in [image, video] {
		assert replaced_image_gpu_clip_data(&command, painting.IntRect{16, 16, 9, 20},
			painting.CornerRadii{}, -1) == [f32(16), 16, 9, 20, 3.25, 9.75, 4, 9.75, 4, 9.25, 3.25,
			9.25]!
	}
	// Without an inset, the half-pixel horizontal radius remains an ellipse.
	plain := layout.PaintCommand{
		...image
		image_paintable: &painting.ImagePaintable{ border_radii: outer }
	}
	assert replaced_image_gpu_clip_data(&plain, painting.IntRect{16, 16, 9, 20},
		painting.CornerRadii{}, -1) == [f32(16), 16, 9, 20, 4.5, 10, 4.5, 10, 4.5, 10, 4.5, 10]!
}
