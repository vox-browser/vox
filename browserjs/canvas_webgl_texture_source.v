// Translate WebGLRenderingContextBase::read_texture_image_source's DOM variants
// at the compact host boundary. The native GL module retains all upload logic.
module browserjs

import dom
import html
import webgl
import x.json2

fn wg_bitmap_source(bitmap &dom.Bitmap_, color_space dom.DecodedImageColorSpace) webgl.WebGLBitmap {
	return webgl.WebGLBitmap{
		width:       bitmap.width
		height:      bitmap.height
		pitch:       bitmap.pitch
		layout:      int(bitmap.format)
		alpha_type:  int(bitmap.alpha_type)
		color_space: int(color_space)
		pixels:      bitmap.data.clone()
	}
}

fn (host &CanvasWebGLHost) texture_source(value json2.Any) !webgl.WebGLTextureImageSource {
	descriptor := wg_object(value)!
	if source_key := descriptor['source'] {
		element := host.elements[wg_string(source_key)] or { return error('TypeError: unknown TexImageSource element') }
		match element.local_name() {
			'canvas' {
				bitmap := html.html_canvas_element_get_bitmap_from_surface(unsafe { &dom.HTMLCanvasElement(element) }) or { return webgl.WebGLTextureImageSource{ kind: .canvas } }
				return webgl.WebGLTextureImageSource{ kind: .canvas, frame: wg_bitmap_source(bitmap, .srgb) }
			}
			'img' {
				image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
				frame := image.current_image_frame() or { return webgl.WebGLTextureImageSource{ kind: .image_element } }
				return webgl.WebGLTextureImageSource{ kind: .image_element, frame: wg_bitmap_source(frame.bitmap(), frame.color_space()) }
			}
			'video' {
				video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
				frame := video.current_decoded_image_frame() or { return webgl.WebGLTextureImageSource{ kind: .video } }
				return webgl.WebGLTextureImageSource{ kind: .video, frame: wg_bitmap_source(frame.bitmap(), frame.color_space()) }
			}
			else { return error('TypeError: expected a TexImageSource element') }
		}
	}
	if wg_string(descriptor['kind'] or { json2.Any('') }) != 'image_data' {
		return error('TypeError: expected a TexImageSource')
	}
	bytes := wg_array(descriptor['data'] or { json2.Any([]json2.Any{}) }).map(u8(wg_u32(it)))
	width := wg_u32(descriptor['width'] or { json2.Any(0) })
	height := wg_u32(descriptor['height'] or { json2.Any(0) })
	settings := html.ImageDataSettings{ color_space: if wg_string(descriptor['colorSpace'] or { json2.Any('srgb') }) == 'display-p3' {
		.display_p3
	} else {
		.srgb
	} }
	// ImageData.bitmap() fails after an independent backing-storage detachment.
	image := html.ImageData.create_with_data(bytes, width, height, settings) or { return webgl.WebGLTextureImageSource{ kind: .image_data, bitmap_error: true } }
	bitmap := image.bitmap()
	return webgl.WebGLTextureImageSource{
		kind:  .image_data
		frame: webgl.WebGLBitmap{
			width:       int(bitmap.width)
			height:      int(bitmap.height)
			alpha_type:  1
			pixels:      bitmap.data
			// ImageData uses DecodedImageFrame's default sRGB constructor upstream.
			color_space: 0
		}
	}
}
