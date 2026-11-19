module main

import gg
import layout
import os
import painting

// The Windows release uses -gc none. Keep the per-draw raster path
// opt-in until its working set is measured in a Windows process.
const portable_web_font_enabled = $if windows {
	os.getenv('VOX_PORTABLE_WEB_FONTS') == '1'
} $else {
	true
}

const portable_web_font_texture_slots = 16
const disable_portable_web_font_texture_cache = os.getenv('VOX_DISABLE_WEB_FONT_TEXTURE_CACHE') == '1'
const portable_web_font_texture_diagnostics = os.getenv('VOX_WEB_FONT_TEXTURE_DIAGNOSTICS') == '1'

struct PortableWebFontTextureKey {
	generation u64
	command    u64
	viewport   painting.IntRect
	scale      f32
}

struct PortableWebFontTexture {
	key PortableWebFontTextureKey
	x   f32
	y   f32
}

fn (app &BrowserApp) portable_web_font_texture_key(source &layout.PaintCommand,
	viewport painting.IntRect) PortableWebFontTextureKey {
	if disable_portable_web_font_texture_cache || app.paint_generation == 0
		|| app.portable_raster_image_index >= portable_web_font_texture_slots
		|| app.draw_command_depth != 1 || app.page_zoom != 1 || source.scrollbar_axis != '' {
		return PortableWebFontTextureKey{}
	}
	// Only adopted root commands are immutable for the lifetime of a
	// recording. Zoom and nested replay can pass projected working copies.
	address := u64(voidptr(source))
	base := u64(app.paint_commands.data)
	if address < base || address - base >= u64(app.paint_commands.len) * sizeof(layout.PaintCommand) {
		return PortableWebFontTextureKey{}
	}
	return PortableWebFontTextureKey{app.paint_generation, address, viewport, app.ctx.scale}
}

fn (mut app BrowserApp) draw_portable_web_font(source &layout.PaintCommand, command &layout.PaintCommand,
	page_x f32, page_y f32, scroll_y f64) bool {
	scale := f64(app.ctx.scale)
	// The existing glyph renderer works in document pixels. Move the
	// viewport back to that coordinate space before rounding to texels.
	viewport := portable_pixel_bounds(app.portable_device_viewport(page_y).translated(
		painting.Point{-f64(page_x) * scale, (scroll_y - f64(page_y)) * scale}))
	index := app.portable_raster_image_index
	key := app.portable_web_font_texture_key(source, viewport)
	if key.generation != 0 && index < app.portable_raster_images.len {
		entry := app.portable_web_font_textures[index]
		if entry.key == key {
			app.draw_cached_portable_web_font(index, page_x, page_y, scroll_y)
			if portable_web_font_texture_diagnostics {
				eprintln('VOX_WEB_FONT_TEXTURE cache=hit recording=${key.generation}')
			}
			return true
		}
	}
	scroll_input := if portable_web_font_scroll_reuse && key.generation != 0 {
		app.portable_web_font_scroll_input(command, viewport)
	} else {
		none
	}
	if input := scroll_input {
		if app.restore_portable_web_font_scroll_texture(index, &input) {
			app.portable_web_font_textures[index] = PortableWebFontTexture{key,
				f32(f64(input.bounds.x) / scale), f32(f64(input.bounds.y) / scale)}
			app.draw_cached_portable_web_font(index, page_x, page_y, scroll_y)
			if portable_web_font_texture_diagnostics {
				eprintln('VOX_WEB_FONT_SCROLL cache=hit recording=${key.generation}')
			}
			return true
		}
	}
	bitmap := layout.rasterize_portable_text(*command, scale, viewport) or { return false }
	if bitmap.width > 0 && bitmap.height > 0 {
		if portable_web_font_scroll_reuse && key.generation != 0 {
			app.preserve_displaced_web_font_texture(index)
		}
		app.draw_portable_raster_image(bitmap.x + page_x, bitmap.y + page_y - f32(scroll_y),
			bitmap.width, bitmap.height, bitmap.pixels)
		if key.generation != 0 {
			app.portable_web_font_textures[index] = PortableWebFontTexture{key, bitmap.x, bitmap.y}
			if input := scroll_input {
				bounds := input.bounds
				if bitmap.width == bounds.width && bitmap.height == bounds.height
					&& bitmap.x == f32(f64(bounds.x) / scale) && bitmap.y == f32(f64(bounds.y) / scale) {
					app.remember_portable_web_font_scroll_texture(index, &input)
				}
			}
			if portable_web_font_texture_diagnostics {
				eprintln('VOX_WEB_FONT_TEXTURE cache=miss recording=${key.generation}')
			}
		}
	}
	return true
}

fn (mut app BrowserApp) draw_cached_portable_web_font(index int, page_x f32,
	page_y f32, scroll_y f64) {
	image := app.portable_raster_images[index]
	entry := app.portable_web_font_textures[index]
	app.portable_raster_image_index++
	app.ctx.draw_image_with_config(img_id: image.image_id,
		img_rect: gg.Rect{entry.x + page_x, entry.y + page_y - f32(scroll_y),
		f32(image.width) / app.ctx.scale, f32(image.height) / app.ctx.scale},
		color: gg.white)
}
