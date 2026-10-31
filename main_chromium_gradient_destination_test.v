module main

import layout
import painting

fn test_gradient_paint_bounds_trim_obscured_edges_without_rebasing_the_tile() {
	command := layout.PaintCommand{
		gradient_background_layer: true
		image_data:                &layout.PaintImageData{
			background_image_destination: layout.LayoutRect{32, 32, 99, 38}
		}
	}
	tile := painting.Rect{31, 31, 101, 40}
	path := native_gradient_clip_path(command, tile)
	stride := layout.compatibility_clip_path_segment_stride
	assert path.len == stride * 5
	assert [path[1], path[2], path[stride + 1], path[stride + 2], path[2 * stride + 1],
		path[2 * stride + 2]] == [f32(32), 32, 131, 32, 131, 70]
}
