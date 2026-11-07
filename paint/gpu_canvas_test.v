module main

import css
import html
import layout
import painting

fn gpu_canvas_background_command(data &layout.PaintImageData) layout.PaintCommand {
	return layout.PaintCommand{
		kind:       'draw_background_image'
		width:      32
		height:     32
		image_data: unsafe { data }
	}
}

// A zoomed frame may draw raster background images on the GPU canvas; flag
// 1024 keeps the backgrounds the canvas leaf cannot reproduce on the CPU.
fn test_gpu_canvas_flags_background_images_the_canvas_cannot_draw() {
	raster := gpu_canvas_background_command(&layout.PaintImageData{
		image_url: 'https://www.redditstatic.com/sprite-reddit.png'
	})
	assert gpu_canvas_background_image_supported(&raster)
	assert gpu_canvas_command_flags(&raster) & 1024 == 0
	blended := gpu_canvas_background_command(&layout.PaintImageData{
		image_url:             'https://example.test/a.png'
		background_blend_mode: painting.BlendMode.multiply
	})
	assert !gpu_canvas_background_image_supported(&blended)
	assert gpu_canvas_command_flags(&blended) & 1024 != 0
	layer_blended := gpu_canvas_background_command(&layout.PaintImageData{
		image_url:             'https://example.test/a.png'
		background_layer_data: &layout.PaintBackgroundLayerData{
			layer: css.BackgroundLayerData{
				blend_mode: .screen
			}
		}
	})
	assert !gpu_canvas_background_image_supported(&layer_blended)
	mut svg := html.parse_document('<svg xmlns="http://www.w3.org/2000/svg"></svg>')
	defer { svg.finalize() }
	vector := gpu_canvas_background_command(&layout.PaintImageData{
		image_url:               'https://example.test/a.svg'
		background_svg_document: svg
	})
	assert !gpu_canvas_background_image_supported(&vector)
	assert gpu_canvas_command_flags(&vector) & 1024 != 0
	missing := gpu_canvas_background_command(unsafe { nil })
	assert !gpu_canvas_background_image_supported(&missing)
	// Other kinds never carry the flag.
	rect := layout.PaintCommand{ kind: 'fill_rect', width: 10, height: 10 }
	assert gpu_canvas_command_flags(&rect) & 1024 == 0
}
