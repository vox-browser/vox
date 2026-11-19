module main

import css
import layout
import math
import os
import painting
import platform

const portable_web_font_scroll_reuse = os.getenv('VOX_WEB_FONT_SCROLL_REUSE') == '1'
const portable_web_font_scroll_glyphs = 128
const portable_web_font_scroll_path_bytes = 512

struct PortableWebFontScrollKey {
	document    u64
	revision    u64
	size_px     painting.IntSize
	transform   [2]f32
	translation [2]f32
	scale       f32
	size        f32
	face_index  int
	smoothing   css.FontSmoothing
	color       css.Color
	opacity     f64
}

struct PortableWebFontScrollInput {
	key       PortableWebFontScrollKey
	bounds    painting.IntRect
	font_path string
	glyphs    []u16
	positions []f64
}

struct PortableWebFontScrollEntry {
mut:
	valid           bool
	scroll_y        f64
	key             PortableWebFontScrollKey
	path_length     int
	glyph_count     int
	font_path       [portable_web_font_scroll_path_bytes]u8
	glyphs          [portable_web_font_scroll_glyphs]u16
	positions       [portable_web_font_scroll_glyphs * 2]f64
}

struct PortableWebFontScrollTextures {
mut:
	entries [portable_web_font_texture_slots]PortableWebFontScrollEntry
}

fn (app &BrowserApp) portable_web_font_scroll_input(command &layout.PaintCommand,
	viewport painting.IntRect) ?PortableWebFontScrollInput {
	if app.document == unsafe { nil } || command.recording_clip != none {
		return none
	}
	matrix := normalized_paint_transform(command.transform)
	if matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1 { return none }
	if command.clip_list != unsafe { nil } && command.clip_list.items.len != 0 { return none }
	scale := f64(app.ctx.scale)
	left := int(math.floor((command.x + matrix[4]) * scale))
	top := int(math.floor((command.y + matrix[5]) * scale))
	right := int(math.ceil((command.x + command.width + matrix[4]) * scale))
	bottom := int(math.ceil((command.y + command.height + matrix[5]) * scale))
	if left < viewport.x || top < viewport.y || right > viewport.right()
		|| bottom > viewport.bottom() || left >= right || top >= bottom {
		return none
	}
	run := command.glyph_run?
	if run.face() != .document { return none }
	glyphs := run.glyph_indices()
	positions := run.glyph_positions()
	if glyphs.len == 0 || glyphs.len > portable_web_font_scroll_glyphs
		|| positions.len != glyphs.len * 2 { return none }
	font := run.font()
	font_path := font.font_path()?
	if font_path != font.source_path || font_path.len > portable_web_font_scroll_path_bytes {
		return none
	}
	return PortableWebFontScrollInput{
		key: PortableWebFontScrollKey{
			document: u64(app.document.unique_id().value())
			revision: app.document.paint_content_revision()
			size_px: painting.IntSize{right - left, bottom - top}
			// Integral screen translations leave the raster-local matrix
			// unchanged. Fractional motion must match its exact f32 phase.
			transform: [f32(matrix[4] * scale - f64(left)),
				f32(matrix[5] * scale - f64(top))]!
			translation: [f32(command.glyph_translation_x), f32(command.glyph_translation_y)]!
			scale: app.ctx.scale
			size: font.point_size
			face_index: font.face_index()
			smoothing: command.font_smoothing
			color: css.parse_color_string(command.color)?
			opacity: command.opacity
		}
		bounds: painting.IntRect{left, top, right - left, bottom - top}
		font_path: font_path
		glyphs: glyphs
		positions: positions
	}
}

fn (entry &PortableWebFontScrollEntry) matches(input &PortableWebFontScrollInput) bool {
	return entry.valid && entry.key == input.key && entry.path_length == input.font_path.len
		&& entry.glyph_count == input.glyphs.len && unsafe {
		vmemcmp(&entry.font_path[0], input.font_path.str, entry.path_length) == 0
			&& vmemcmp(&entry.glyphs[0], input.glyphs.data, entry.glyph_count * int(sizeof(u16))) == 0
			&& vmemcmp(&entry.positions[0], input.positions.data, input.positions.len * int(sizeof(f64))) == 0
	}
}

fn (mut app BrowserApp) restore_portable_web_font_scroll_texture(index int,
	input &PortableWebFontScrollInput) bool {
	if app.portable_web_font_scroll_textures == unsafe { nil }
		|| index >= app.portable_raster_images.len
		|| app.portable_web_font_textures[index].key.generation == 0 {
		return false
	}
	mut entries := app.portable_web_font_scroll_textures
	limit := math.min(app.portable_raster_images.len, portable_web_font_texture_slots)
	for slot in index .. limit {
		if !entries.entries[slot].matches(input) { continue }
		if slot != index {
			// Both slots belong to web fonts and neither was drawn this frame.
			app.portable_raster_images[index], app.portable_raster_images[slot] =
				app.portable_raster_images[slot], app.portable_raster_images[index]
			app.portable_web_font_textures[index], app.portable_web_font_textures[slot] =
				app.portable_web_font_textures[slot], app.portable_web_font_textures[index]
			entries.entries[index], entries.entries[slot] = entries.entries[slot], entries.entries[index]
		}
		entries.entries[index].scroll_y = app.scroll_y
		return true
	}
	return false
}

fn (mut app BrowserApp) preserve_displaced_web_font_texture(index int) {
	mut cache := app.portable_web_font_scroll_textures
	tail := app.portable_raster_images.len
	if cache == unsafe { nil } || index >= tail || tail >= portable_web_font_texture_slots {
		return
	}
	mut entry := &cache.entries[index]
	if !entry.valid || app.document == unsafe { nil } || entry.scroll_y <= app.scroll_y
		|| entry.key.document != u64(app.document.unique_id().value())
		|| entry.key.revision != app.document.paint_content_revision() {
		return
	}
	// When scrolling up, an entering row can overwrite a texture before an
	// old visible row gets to look it up. Move it to the unused end of the
	// slot array. Frame retirement releases it if no later draw takes it.
	persistent := platform.enter_persistent()
	app.portable_raster_images << app.portable_raster_images[index]
	platform.leave_persistent(persistent)
	app.portable_raster_images[index] = PortableRasterImage{image_id: -1}
	app.portable_web_font_textures[tail] = app.portable_web_font_textures[index]
	app.portable_web_font_textures[index] = PortableWebFontTexture{}
	cache.entries[tail] = *entry
	entry.valid = false
}

fn (mut app BrowserApp) remember_portable_web_font_scroll_texture(index int,
	input &PortableWebFontScrollInput) {
	if app.portable_web_font_scroll_textures == unsafe { nil } {
		persistent := platform.enter_persistent()
		app.portable_web_font_scroll_textures = &PortableWebFontScrollTextures{}
		platform.leave_persistent(persistent)
	}
	mut entry := &app.portable_web_font_scroll_textures.entries[index]
	entry.valid = true
	entry.scroll_y = app.scroll_y
	entry.key = input.key
	entry.path_length = input.font_path.len
	entry.glyph_count = input.glyphs.len
	unsafe {
		vmemcpy(&entry.font_path[0], input.font_path.str, entry.path_length)
		vmemcpy(&entry.glyphs[0], input.glyphs.data, entry.glyph_count * int(sizeof(u16)))
		vmemcpy(&entry.positions[0], input.positions.data, input.positions.len * int(sizeof(f64)))
	}
}
