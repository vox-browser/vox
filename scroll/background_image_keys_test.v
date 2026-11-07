module main

import dom
import layout
import painting

fn background_image_key_commands(url string) []layout.PaintCommand {
	return [
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{
			kind:       'draw_background_image'
			x:          0
			y:          0
			width:      400
			height:     160
			image_data: &layout.PaintImageData{
				image_url:         url
				image_clip_width:  400
				image_clip_height: 160
			}
		},
		layout.PaintCommand{ kind: 'end_css_effect_layer' },
		layout.PaintCommand{ kind: 'fill_rect', x: 0, y: 200, width: 400, height: 20, color: 'red' },
	]
}

fn background_image_keys(app &BrowserApp) []ScrollRasterCommandKey {
	mut keys := scroll_raster_frame_keys(app.paint_commands, 0, 1, 1024, 768)
	app.mark_background_image_keys(mut keys)
	return keys
}

// A background image is drawn from the resource cache at replay time, so its
// command does not change when the response arrives. The retained scroll
// raster must still repaint the rows it kept from before the arrival.
fn test_scroll_raster_background_image_arrival_damages_retained_pixels() {
	url := 'https://b.thumbs.redditmedia.com/banner.png'
	mut app := BrowserApp{
		paint_commands: background_image_key_commands(url)
	}
	pending := background_image_keys(&app)
	// The same resource state keeps the same identity.
	assert background_image_keys(&app).map(it.hash) == pending.map(it.hash)
	app.resource_cache[url] = PreloadedResource{ url: url, body: 'png bytes', request_type: 'image' }
	arrived := background_image_keys(&app)
	assert arrived[1].hash != pending[1].hash
	// The enclosing group carries the change; unrelated commands do not.
	assert arrived[0].hash != pending[0].hash
	assert arrived[2].hash == pending[2].hash
	assert arrived[3].hash == pending[3].hash
	previous := ScrollRasterKeyFrame{ valid: true, document: 7, width: 1024, height: 768, keys: pending }
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, arrived, 7, 0, 1024, 768, mut stats) or {
		panic('an arrival must reconcile: ${stats.fallback}')
	}
	assert rects.len > 0
	mut covered := false
	for rect in rects {
		if rect.x <= 0 && rect.y <= 0 && rect.x + rect.width >= 400 && rect.y + rect.height >= 160 {
			covered = true
		}
	}
	assert covered
	// A failed response and a longer (completed) body are distinct states.
	app.resource_cache[url] = PreloadedResource{ url: url, body: 'png bytes and the rest', request_type: 'image' }
	assert background_image_keys(&app)[1].hash != arrived[1].hash
	app.resource_cache[url] = PreloadedResource{ url: url, error: 'blocked', request_type: 'image' }
	assert background_image_keys(&app)[1].hash != arrived[1].hash
}

// Data and local images decode synchronously; the resource cache does not
// describe them.
fn test_scroll_raster_inline_background_images_ignore_the_resource_cache() {
	url := 'data:image/png;base64,AAAA'
	mut app := BrowserApp{
		paint_commands: background_image_key_commands(url)
	}
	before := background_image_keys(&app)
	app.resource_cache[url] = PreloadedResource{ url: url, error: 'unrelated' }
	assert background_image_keys(&app).map(it.hash) == before.map(it.hash)
}

// 2ch.su's catalog: a lazy thumbnail laid out while its request was still
// pending records a replaced image without request pixels. Replay resolves it
// by URL, so its response must damage the retained scroll raster as well; a
// command carrying its own pixels does not depend on the resource cache.
fn test_scroll_raster_url_replaced_image_arrival_damages_retained_pixels() {
	url := 'http://127.0.0.1:8732/news/thumb/19958927/17939890069890404825s.jpg'
	replaced := layout.PaintCommand{
		kind:       'draw_replaced_image'
		x:          420
		y:          14
		width:      184
		height:     220
		image_data: &layout.PaintImageData{
			image_url:         url
			image_clip_width:  184
			image_clip_height: 220
		}
		image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{420, 14, 184, 220}
		}
	}
	mut app := BrowserApp{
		paint_commands: [replaced]
	}
	pending := background_image_keys(&app)
	assert background_image_keys(&app).map(it.hash) == pending.map(it.hash)
	app.resource_cache[url] = PreloadedResource{ url: url, body: 'jpeg bytes', request_type: 'image' }
	arrived := background_image_keys(&app)
	assert arrived[0].hash != pending[0].hash
	previous := ScrollRasterKeyFrame{ valid: true, document: 7, width: 1024, height: 768, keys: pending }
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, arrived, 7, 0, 1024, 768, mut stats) or {
		panic('an arrival must reconcile: ${stats.fallback}')
	}
	mut covered := false
	for rect in rects {
		if rect.x <= 420 && rect.y <= 14 && rect.x + rect.width >= 604 && rect.y + rect.height >= 234 {
			covered = true
		}
	}
	assert covered
	// Retained request pixels paint without the resource cache.
	pixels := [u8(255)].repeat(4)
	mut with_pixels := app.paint_commands.clone()
	with_pixels[0].replaced_image_bitmap = &dom.Bitmap_{ width: 1, height: 1, pitch: 4, data: pixels }
	app.paint_commands = with_pixels
	app.resource_cache.delete(url)
	before := background_image_keys(&app)
	app.resource_cache[url] = PreloadedResource{ url: url, body: 'jpeg bytes', request_type: 'image' }
	assert background_image_keys(&app).map(it.hash) == before.map(it.hash)
}
