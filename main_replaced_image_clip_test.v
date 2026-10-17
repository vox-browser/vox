module main

import layout
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
	// The last eligible rounded clip moves to the image; all earlier entries
	// remain in their original order on the native context.
	clips << layout.PaintClip{corner_radii: radii, transform: identity}
	last := layout.PaintCommand{...command, clip_list: &layout.PaintClipList{items: clips}}
	assert replaced_image_gpu_ancestor_clip_index(&last) == 5
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
