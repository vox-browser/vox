module main

import layout
import painting
import math
import os

// Scroll raster content damage.
//
// The viewport raster ring already keeps the previous frame's document pixels
// and repaints only the strip a scroll exposes. That reuse was limited to
// frames whose paint content revision had not changed, so any frame with a
// new video frame or a script style mutation repainted the whole viewport.
//
// Chromium's compositor keeps scrolling cheap in the same situation because
// unchanged content is never re-rasterized: only the layers whose content
// changed are redrawn. This module provides the single-surface equivalent. Each
// frame records a content identity per paint command; the next frame diffs the
// two multisets and repaints the exposed strip plus the ink of commands that
// appeared or disappeared. Commands are identified by content, not by index,
// because the viewport-only recording reselects entries as the window moves.

const scroll_raster_damage_diagnostics = os.getenv('VOX_SCROLL_RASTER_DAMAGE_DIAGNOSTICS') != ''

// Advances once per key frame so canvas commands never match a retained key.
__global scroll_raster_canvas_nonce u64
// Last paint revision whose command kinds were printed under diagnostics.
__global scroll_raster_dumped_revision u64
// Same-binary control: reuse only across an unchanged content revision.
const disable_scroll_raster_content_damage = os.getenv('VOX_DISABLE_SCROLL_RASTER_CONTENT_DAMAGE') != ''
// Keep an extra CSS-pixel fringe beyond the native raster guards, including
// fractional transforms and antialiased edges at either backing density.
const scroll_raster_damage_fringe = 3.0
// CSS pixels around a leaf's ink that a clip must miss before the leaf counts
// as painting nothing; at least one device pixel at any supported density.
const scroll_raster_clipped_ink_guard = 2.0
// Same-binary control: a leaf clipped away entirely keeps its whole clip as ink.
const disable_minimal_clipped_ink = os.getenv('VOX_DISABLE_MINIMAL_CLIPPED_SCROLL_INK') != ''
// Same-binary control: a viewport-filling solid keys its complete geometry.
const disable_viewport_fill_extent_reuse = os.getenv('VOX_DISABLE_VIEWPORT_FILL_EXTENT_REUSE') != ''
// Fixed and sticky content counts as changed on every scrolled frame; the
// area cap below bounds its repaint cost.
const scroll_raster_max_changed_commands = 256
const scroll_raster_max_damage_fraction = 0.5
// Match the bounded native damage list, after merging overlapping ink.
const scroll_raster_max_damage_rects = 48
const disable_coalesced_scroll_damage = os.getenv('VOX_DISABLE_COALESCED_SCROLL_DAMAGE') != ''
// Stationary identity is pixel-correct, but the live paired cohort regressed.
const disable_stationary_filter_reuse = os.getenv('VOX_ENABLE_STATIONARY_FILTER_REUSE') != '1'
	|| os.getenv('VOX_DISABLE_STATIONARY_FILTER_REUSE') != ''

// One command's retained identity. The hash covers every pixel-affecting field
// after removing the viewport scroll translation, so the same content at a
// different scroll offset hashes equally. Ink is viewport space at the frame's
// own scroll offset; a group begin carries the extent of its whole group.
struct ScrollRasterCommandKey {
mut:
	hash      u64
	kind      string
	has_ink   bool
	ink       layout.LayoutRect
	group_end int = -1
	// Trailing viewport scrollbars are replayed separately after caching.
	skip_diff bool
	// A top-level video with nothing painted above it, in a layer that draws
	// immediately: a new frame can be composited over its retained backdrop.
	video_backdrop bool
	// Diagnostics only: document geometry and per-component hashes, so an
	// unmatched key can report which component churned between frames.
	doc_x     f64
	doc_y     f64
	parts     [8]u64
}

const scroll_raster_key_part_names = ['geometry', 'paint', 'text', 'shape', 'payload', 'transform',
	'clips', 'layers']!

struct ScrollRasterKeyFrame {
mut:
	valid    bool
	document u64
	paint_generation u64
	scroll   f64
	width    f64
	height   f64
	keys     []ScrollRasterCommandKey
}

struct ScrollRasterDiffStats {
mut:
	changed  int
	rects    int
	fallback string
	// Videos whose only change is their frame, kept out of the returned rects.
	restores []ScrollRasterVideoRestore
}

// A changed video frame composited over the pixels retained beneath it: only
// the video and later commands repaint `rect` (viewport space). `document` is
// the same rectangle before clamping to the viewport, in document space.
struct ScrollRasterVideoRestore {
	index    int
	rect     layout.LayoutRect
	document layout.LayoutRect
}

@[inline]
fn srk_mix(h u64, v u64) u64 {
	return (h ^ v) * u64(0x100000001b3)
}

// Quantize to 1/1024 CSS pixel so float noise from recomposed transforms does
// not read as a content change; smaller differences are invisible.
@[inline]
fn srk_f64(h u64, v f64) u64 {
	if math.is_nan(v) { return srk_mix(h, u64(0xfffffffffffffff1)) }
	if math.is_inf(v, 0) { return srk_mix(h, if v > 0 { u64(0xfffffffffffffff2) } else { u64(0xfffffffffffffff3) }) }
	return srk_mix(h, math.f64_bits(math.round(v * 1024.0)))
}

@[inline]
fn srk_int(h u64, v int) u64 {
	return srk_mix(h, u64(v) + 0x9e3779b97f4a7c15)
}

@[inline]
fn srk_bool(h u64, v bool) u64 {
	return srk_mix(h, if v { u64(0x51) } else { u64(0x52) })
}

@[inline]
fn srk_ptr(h u64, p voidptr) u64 {
	return srk_mix(h, u64(p) + 0x7f4a7c159e3779b9)
}

fn srk_str(h u64, s string) u64 {
	mut x := srk_mix(h, u64(s.len) + 0x100)
	for index in 0 .. s.len {
		x = srk_mix(x, u64(s[index]))
	}
	return x
}

fn srk_rect(h u64, r layout.LayoutRect) u64 {
	mut x := srk_f64(h, r.x)
	x = srk_f64(x, r.y)
	x = srk_f64(x, r.width)
	return srk_f64(x, r.height)
}

fn srk_radii(h u64, radii layout.BoxRadii) u64 {
	mut x := srk_f64(h, radii.top_left.x)
	x = srk_f64(x, radii.top_left.y)
	x = srk_f64(x, radii.top_right.x)
	x = srk_f64(x, radii.top_right.y)
	x = srk_f64(x, radii.bottom_right.x)
	x = srk_f64(x, radii.bottom_right.y)
	x = srk_f64(x, radii.bottom_left.x)
	return srk_f64(x, radii.bottom_left.y)
}

// A transform with the viewport scroll translation removed. All-zero means
// identity, so normalize before compensating the y translation.
// Gradient snapshots are rebuilt by every recording, so their pointers change
// each frame; their resolved geometry and stops identify the painted pixels.
fn srk_gradient(h u64, gradient &layout.LinearGradient) u64 {
	mut x := srk_str(h, gradient.kind)
	for value in [gradient.x1, gradient.y1, gradient.x2, gradient.y2, gradient.center_x,
		gradient.center_y, gradient.radius_x, gradient.radius_y, gradient.start_degrees]! {
		x = srk_f64(x, value)
	}
	x = srk_bool(x, gradient.radial)
	if angle := gradient.css_angle_degrees { x = srk_f64(x, angle) }
	if geometry := gradient.css_radial_geometry {
		for value in [geometry.width, geometry.height, geometry.center_x, geometry.center_y,
			geometry.radius_x, geometry.radius_y]! {
			x = srk_f64(x, f64(value))
		}
	}
	x = srk_bool(x, gradient.interpolation_method != none)
	x = srk_int(x, gradient.stops.len)
	for stop in gradient.stops {
		x = srk_int(x, int(stop.color.r))
		x = srk_int(x, int(stop.color.g))
		x = srk_int(x, int(stop.color.b))
		x = srk_int(x, int(stop.color.a))
		x = srk_f64(x, stop.offset)
	}
	return x
}

// Recording rebuilds these immutable payloads, so pointer identity churns on
// every scrolled frame; hash the fields that select the painted pixels.
fn srk_svg_path(h u64, data &layout.PaintSVGPathData) u64 {
	if data == unsafe { nil } { return srk_bool(h, false) }
	mut x := srk_str(srk_bool(h, true), data.path)
	x = srk_int(x, data.path_data.len)
	x = srk_int(x, data.path_polygons.len)
	for value in data.path_transform {
		x = srk_f64(x, value)
	}
	if gradient := data.svg_gradient_data { x = srk_ptr(x, voidptr(gradient)) }
	if data.svg_solid_color_data != unsafe { nil } {
		solid := data.svg_solid_color_data
		x = srk_str(x, solid.fill_serialized)
		x = srk_str(x, solid.stroke_serialized)
		x = srk_bool(x, solid.has_fill)
		x = srk_bool(x, solid.has_stroke)
		x = srk_f64(x, solid.fill_alpha)
		for color in [solid.fill, solid.stroke]! {
			x = srk_int(x, int(color.r))
			x = srk_int(x, int(color.g))
			x = srk_int(x, int(color.b))
			x = srk_int(x, int(color.a))
		}
	}
	if pattern := data.fill_pattern { x = srk_ptr(x, voidptr(pattern)) }
	if pattern := data.stroke_pattern { x = srk_ptr(x, voidptr(pattern)) }
	x = srk_int(x, data.stroke_dasharray.len)
	for value in data.stroke_dasharray {
		x = srk_f64(x, value)
	}
	x = srk_f64(x, data.stroke_dashoffset)
	x = srk_bool(x, data.non_scaling_stroke)
	x = srk_bool(x, data.stroke_first)
	x = srk_bool(x, data.fill_even_odd)
	x = srk_int(x, data.stroke_linecap)
	x = srk_int(x, data.stroke_linejoin)
	x = srk_f64(x, data.stroke_miterlimit)
	x = srk_f64(x, data.fill_opacity)
	return srk_f64(x, data.stroke_opacity)
}

fn srk_image_data(h u64, data &layout.PaintImageData) u64 {
	if data == unsafe { nil } { return srk_bool(h, false) }
	mut x := srk_str(srk_bool(h, true), data.image_url)
	x = srk_mix(x, u64(data.image_element_id))
	if document := data.background_svg_document { x = srk_ptr(x, voidptr(document)) }
	if resource := data.background_static_svg_resource { x = srk_ptr(x, voidptr(resource)) }
	x = srk_int(x, int(data.background_svg_color_scheme))
	for value in [data.image_intrinsic_width, data.image_intrinsic_height, data.image_clip_x,
		data.image_clip_y, data.image_clip_width, data.image_clip_height]! {
		x = srk_f64(x, value)
	}
	for text in [data.image_repeat_x, data.image_repeat_y, data.image_size, data.image_position_x,
		data.image_position_y, data.image_attachment]! {
		x = srk_str(x, text)
	}
	x = srk_int(x, int(data.image_rendering))
	x = srk_radii(x, data.image_clip_radii)
	if destination := data.background_image_destination { x = srk_rect(x, destination) }
	if layer := data.background_layer_data { x = srk_background_layer(x, layer) }
	return srk_int(x, int(data.background_blend_mode))
}

// Background layer snapshots are also rebuilt per recording; hash the
// resolved layer and the length-resolution inputs that shape its tiles.
fn srk_background_layer(h u64, data &layout.PaintBackgroundLayerData) u64 {
	// The layer's image, position, size, repeat and attachment strings are
	// already hashed from the owning image payload; add the resolution inputs.
	layer := data.layer
	mut x := srk_int(h, int(layer.attachment))
	x = srk_int(x, int(layer.blend_mode))
	x = srk_int(x, int(layer.clip))
	x = srk_int(x, int(layer.origin))
	x = srk_int(x, int(layer.repeat_x))
	x = srk_int(x, int(layer.repeat_y))
	x = srk_int(x, int(layer.size_type))
	context := data.resolution_context
	x = srk_bool(x, context.use_chromium_geometry)
	x = srk_f64(x, context.absolute_length_scale)
	rect := context.viewport_rect
	for value in [rect.x, rect.y, rect.width, rect.height]! {
		x = srk_f64(x, value.to_double())
	}
	for metrics in [context.font_metrics, context.root_font_metrics]! {
		x = srk_f64(x, metrics.font_size.to_double())
		x = srk_f64(x, metrics.x_height.to_double())
		x = srk_f64(x, metrics.cap_height.to_double())
		x = srk_f64(x, metrics.zero_advance.to_double())
	}
	x = srk_f64(x, data.layout_coordinate_scale)
	return srk_bool(x, data.gradient_pattern)
}

// Replaced-image paintables are rebuilt per recording; the decoded bitmap
// pointer identifies the pixels and these fields identify their placement.
fn srk_image_paintable(h u64, paintable &painting.ImagePaintable) u64 {
	rect := paintable.image_rect
	mut x := srk_f64(h, rect.x)
	x = srk_f64(x, rect.y)
	x = srk_f64(x, rect.width)
	x = srk_f64(x, rect.height)
	radii := paintable.border_radii
	for corner in [radii.top_left, radii.top_right, radii.bottom_right, radii.bottom_left]! {
		x = srk_f64(x, corner.horizontal)
		x = srk_f64(x, corner.vertical)
	}
	widths := paintable.border_widths
	for value in [widths.top, widths.right, widths.bottom, widths.left]! {
		x = srk_f64(x, value)
	}
	x = srk_int(x, int(paintable.object_fit))
	x = srk_str(x, paintable.object_position.offset_x.to_string())
	x = srk_str(x, paintable.object_position.offset_y.to_string())
	x = srk_int(x, int(paintable.image_rendering))
	x = srk_bool(x, paintable.is_svg_image)
	x = srk_f64(x, paintable.broken_image_fallback_scale)
	x = srk_bool(x, paintable.broken_image_fallback_rtl)
	x = srk_bool(x, paintable.intrinsic_size != none)
	viewport := paintable.resolution_context.viewport_rect
	for value in [viewport.x, viewport.y, viewport.width, viewport.height]! {
		x = srk_f64(x, value.to_double())
	}
	return x
}

// Layout rebuilds a nested viewport's paintable record with equal values
// whenever its box is rebuilt; its fields, not its address, identify the
// nested clip and placement.
fn srk_nested_viewport(h u64, paintable &painting.NavigableContainerViewportPaintable) u64 {
	mut x := srk_f64(h, paintable.viewport_rect.x)
	x = srk_f64(x, paintable.viewport_rect.y)
	x = srk_f64(x, paintable.viewport_rect.width)
	x = srk_f64(x, paintable.viewport_rect.height)
	if rect := paintable.nested_rect {
		x = srk_f64(srk_f64(srk_f64(srk_f64(srk_bool(x, true), rect.x), rect.y), rect.width), rect.height)
	} else {
		x = srk_bool(x, false)
	}
	if size := paintable.nested_layout_size {
		x = srk_f64(srk_f64(srk_bool(x, true), size.width), size.height)
	} else {
		x = srk_bool(x, false)
	}
	radii := paintable.border_radii
	for radius in [radii.top_left, radii.top_right, radii.bottom_right, radii.bottom_left] {
		x = srk_f64(srk_f64(x, radius.horizontal), radius.vertical)
	}
	widths := paintable.border_widths
	for value in [widths.top, widths.right, widths.bottom, widths.left] {
		x = srk_f64(x, value)
	}
	return x
}

fn srk_local_border(h u64, data &layout.PaintLocalBorderData) u64 {
	if data == unsafe { nil } { return srk_bool(h, false) }
	mut x := srk_bool(srk_bool(h, true), data.has_local_geometry)
	x = srk_f64(x, data.origin_x)
	x = srk_f64(x, data.origin_y)
	x = srk_int(x, data.transform_context_index)
	t := data.initial_transform
	for value in [t.a, t.b, t.c, t.d, t.e, t.f]! {
		x = srk_f64(x, value)
	}
	for value in data.corner_shapes {
		x = srk_f64(x, value)
	}
	return srk_rect(x, data.shape_border_rect)
}

fn srk_transform(h u64, transform [6]f64, scroll f64) u64 {
	matrix := layout.scroll_raster_normalized_transform(transform)
	mut x := h
	for index in 0 .. 5 {
		x = srk_f64(x, matrix[index])
	}
	return srk_f64(x, matrix[5] + scroll)
}

// Identity of one paint command's pixels at a given viewport scroll offset.
// Immutable payload snapshots shared across phase caches hash by pointer;
// payloads that a re-recording rebuilds with equal contents hash by value.
fn scroll_raster_command_hash(command &layout.PaintCommand, scroll f64) u64 {
	return scroll_raster_command_hash_ex(command, scroll, false)
}

// `translation_free` ignores the command's own translation: a uniform fill
// covering the whole viewport paints the same pixels wherever it is placed.
// Its extent beyond the viewport is invisible too, so a document-height
// change does not damage the viewport through the root background.
// Clips keep the real scroll so a viewport-anchored clip stays identified.
fn scroll_raster_command_hash_ex(command &layout.PaintCommand, scroll f64, translation_free bool) u64 {
	mut h := srk_str(u64(0xcbf29ce484222325), command.kind)
	// Group ends write nothing and carry no geometry of their own; their
	// identity-valued transform must not make them churn with the scroll.
	if command.kind.starts_with('end_') { return h }
	// Canvas pixels change in place without a new bitmap or revision, so a
	// canvas never matches the retained frame and is repainted every frame.
	if command.kind == 'draw_canvas' { h = srk_mix(h, scroll_raster_canvas_nonce) }
	if translation_free && !disable_viewport_fill_extent_reuse {
		// Keep these keys apart from any ordinary key with equal fields.
		h = srk_str(h, 'viewport-filling')
	} else {
		h = srk_f64(h, command.x)
		h = srk_f64(h, command.y)
		h = srk_f64(h, command.width)
		h = srk_f64(h, command.height)
	}
	h = srk_str(h, command.color)
	if command.srgb_color_data != unsafe { nil } {
		for component in command.srgb_color_data.components {
			h = srk_f64(h, component)
		}
	}
	h = srk_int(h, int(command.force_dark_role))
	h = srk_bool(h, command.force_dark_role_set)
	if backdrop := command.force_dark_backdrop {
		h = srk_int(h, int(backdrop.r))
		h = srk_int(h, int(backdrop.g))
		h = srk_int(h, int(backdrop.b))
		h = srk_int(h, int(backdrop.a))
	}
	h = srk_bool(h, command.apply_force_dark_to_image)
	h = srk_bool(h, command.line_box_debug)
	h = srk_bool(h, command.antialiased_rect)
	h = srk_bool(h, command.is_caret)
	h = srk_bool(h, command.disable_antialias)
	h = srk_bool(h, command.underlays_next)
	h = srk_str(h, command.text)
	h = srk_f64(h, command.font_size)
	h = srk_bool(h, command.bold)
	h = srk_bool(h, command.italic)
	h = srk_bool(h, command.mono)
	h = srk_bool(h, command.rtl)
	if run := command.glyph_run {
		h = srk_ptr(h, voidptr(run))
	}
	h = srk_f64(h, command.glyph_translation_x)
	h = srk_f64(h, command.glyph_translation_y)
	h = srk_int(h, int(command.glyph_orientation))
	h = srk_int(h, int(command.font_smoothing))
	h = srk_f64(h, command.opacity)
	h = srk_f64(h, command.group_opacity)
	h = srk_f64(h, command.radius)
	h = srk_local_border(h, command.local_border_data)
	h = srk_ptr(h, voidptr(command.checkbox_theme_data))
	h = srk_int(h, command.clip_outs.len)
	for value in command.clip_outs {
		h = srk_f64(h, value)
	}
	h = srk_radii(h, command.corner_radii)
	h = srk_f64(h, command.blur)
	h = srk_f64(h, command.shadow_offset_x)
	h = srk_f64(h, command.shadow_offset_y)
	h = srk_f64(h, command.shadow_spread)
	h = srk_bool(h, command.outer_shadow)
	if command.box_shadow_data != unsafe { nil } {
		data := command.box_shadow_data
		h = srk_rect(h, data.content_rect)
		h = srk_radii(h, data.content_radii)
		h = srk_radii(h, data.clip_radii)
		h = srk_rect(h, data.inner_rect)
		h = srk_radii(h, data.inner_radii)
	}
	if gradient := command.gradient {
		h = srk_gradient(h, gradient)
	}
	h = srk_bool(h, command.gradient_background_layer)
	h = srk_svg_path(h, command.svg_data)
	if translation_free {
		matrix := layout.scroll_raster_normalized_transform(command.transform)
		for index in 0 .. 4 {
			h = srk_f64(h, matrix[index])
		}
	} else {
		h = srk_transform(h, command.transform, scroll)
	}
	h = srk_int(h, command.points.len)
	for value in command.points {
		h = srk_f64(h, value)
	}
	h = srk_str(h, command.stroke_color)
	h = srk_f64(h, command.stroke_width)
	h = srk_str(h, command.line_style)
	h = srk_image_data(h, command.image_data)
	if scroll_raster_background_offset_is_painted(command) {
		h = srk_f64(h, command.image_scroll_offset_x)
		h = srk_f64(h, command.image_scroll_offset_y)
	}
	if context_index := command.visual_context_index {
		h = srk_int(h, context_index)
	}
	if paintable := command.image_paintable {
		h = srk_image_paintable(h, paintable)
	}
	if bitmap := command.replaced_image_bitmap {
		h = srk_ptr(h, voidptr(bitmap))
	}
	if bitmap := command.canvas_bitmap {
		h = srk_ptr(h, voidptr(bitmap))
	}
	if paintable := command.canvas_paintable {
		h = srk_ptr(h, voidptr(paintable))
	}
	if bitmap := command.video_bitmap {
		h = srk_ptr(h, voidptr(bitmap))
	}
	if source := command.video_frame_source {
		h = srk_ptr(h, voidptr(source))
		if frame := source.current_frame() {
			// The player reuses one frame's pixel storage between decoded
			// frames, so the frame object alone cannot identify its pixels.
			h = srk_ptr(h, voidptr(frame))
			h = srk_mix(h, frame.generation)
		}
	}
	h = srk_int(h, int(command.video_representation))
	if paintable := command.video_paintable {
		h = srk_ptr(h, voidptr(paintable))
	}
	h = srk_int(h, command.nested_viewport_commands.len)
	for index in 0 .. command.nested_viewport_commands.len {
		nested := unsafe { &command.nested_viewport_commands[index] }
		h = srk_mix(h, scroll_raster_command_hash(nested, 0))
	}
	if paintable := command.nested_viewport_paintable {
		h = srk_nested_viewport(h, paintable)
	}
	h = srk_int(h, command.text_clip_runs.len)
	for run in command.text_clip_runs {
		h = srk_f64(h, run.x)
		h = srk_f64(h, run.y)
		h = srk_f64(h, run.width)
		h = srk_f64(h, run.height)
		h = srk_str(h, run.text)
		h = srk_f64(h, run.font_size)
		if glyphs := run.glyph_run {
			h = srk_ptr(h, voidptr(glyphs))
		}
	}
	// Accumulated clips are viewport space: remove the scroll translation.
	h = srk_bool(h, command.has_clip)
	if command.has_clip {
		h = srk_f64(h, command.clip_x)
		h = srk_f64(h, command.clip_y + scroll)
		h = srk_f64(h, command.clip_width)
		h = srk_f64(h, command.clip_height)
	}
	if command.clip_list != unsafe { nil } {
		h = srk_int(h, command.clip_list.items.len)
		for clip in command.clip_list.items {
			h = srk_rect(h, clip.rect)
			h = srk_radii(h, clip.corner_radii)
			h = srk_bool(h, clip.is_path)
			h = srk_bool(h, clip.is_svg_mask)
			h = srk_bool(h, clip.is_svg_content_mask)
			h = srk_int(h, clip.path_data.len)
			h = srk_bool(h, clip.path_even_odd)
			h = srk_int(h, clip.path_components.len)
			h = srk_int(h, clip.mask_operations.len)
			h = srk_mix(h, clip.cache_key)
			h = srk_mix(h, clip.scope_id)
			h = srk_bool(h, clip.mask_luminance)
			h = srk_transform(h, clip.transform, scroll)
		}
	}
	if clip := command.recording_clip {
		h = srk_rect(h, clip)
	}
	if command.visual_layer_list != unsafe { nil } {
		h = srk_int(h, command.visual_layer_list.items.len)
		for layer in command.visual_layer_list.items {
			h = srk_mix(h, layer.scope_id)
			h = srk_int(h, int(layer.kind))
			h = srk_f64(h, layer.opacity)
			h = srk_int(h, int(layer.blend_mode))
		}
	}
	if layer := command.visual_layer_data {
		h = srk_int(h, int(layer.kind))
		h = srk_mix(h, layer.scope_id)
		h = srk_f64(h, layer.opacity)
		h = srk_int(h, int(layer.blend_mode))
		if clip := layer.clip_rect {
			h = srk_f64(h, clip.x)
			h = srk_f64(h, clip.y + scroll)
			h = srk_f64(h, clip.width)
			h = srk_f64(h, clip.height)
		}
		if filter := layer.filter {
			h = srk_int(h, filter.operations.len)
			for operation in filter.operations {
				h = srk_str(h, operation.kind)
				h = srk_f64(h, operation.first)
				h = srk_f64(h, operation.second)
				h = srk_f64(h, operation.third)
				h = srk_int(h, int(operation.color.r))
				h = srk_int(h, int(operation.color.g))
				h = srk_int(h, int(operation.color.b))
				h = srk_int(h, int(operation.color.a))
				h = srk_int(h, int(operation.color_operation))
			}
			h = srk_int(h, filter.nodes.len)
		}
		h = srk_mix(h, layer.mask_clip.cache_key)
	}
	if filter := command.backdrop_filter_data {
		h = srk_ptr(h, voidptr(filter))
	}
	h = srk_bool(h, command.backdrop_source_outside_filter)
	if clip := command.mask_clip_data {
		h = srk_mix(h, clip.cache_key)
		h = srk_mix(h, clip.scope_id)
	}
	h = srk_bool(h, command.fixed_to_viewport)
	h = srk_str(h, command.scrollbar_axis)
	return h
}

// Cached background commands receive their scroll container's live offset on
// every replay, and the root container's offset is the viewport scroll itself.
// The tile plan reads that offset only for `background-attachment: local`;
// gradients and scroll/fixed images paint identically whatever it holds, so
// it must not make their keys churn on each scrolled frame.
fn scroll_raster_background_offset_is_painted(command &layout.PaintCommand) bool {
	if command.kind != 'draw_background_image' || command.image_data == unsafe { nil } {
		return false
	}
	return command.image_data.image_attachment.trim_space().to_lower() == 'local'
}

fn scroll_raster_inflate(rect layout.LayoutRect, amount f64) layout.LayoutRect {
	return layout.LayoutRect{rect.x - amount, rect.y - amount, rect.width + amount * 2,
		rect.height + amount * 2}
}

fn scroll_raster_rect_valid(rect layout.LayoutRect) bool {
	for value in [rect.x, rect.y, rect.width, rect.height]! {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	return rect.width > 0 && rect.height > 0
}

// Content identities and viewport-space ink for one recorded frame. Group
// begins receive their group's complete extent; trailing viewport scrollbars
// are replayed outside the ring and excluded from the diff, while a nested
// scroller's bar is ordinary content whose draw-time overlay fade joins its
// key. Unbounded leaves are marked so the diff can refuse to reuse around them.
fn scroll_raster_frame_keys(commands []layout.PaintCommand, scroll f64, scrollbar_opacity f64,
	width f64, height f64) []ScrollRasterCommandKey {
	return scroll_raster_frame_keys_with_scrollbars(commands, scroll, scrollbar_opacity, width, height, false)
}

fn scroll_raster_frame_keys_with_scrollbars(commands []layout.PaintCommand, scroll f64, scrollbar_opacity f64,
	width f64, height f64, inline_scrollbars bool) []ScrollRasterCommandKey {
	scroll_raster_canvas_nonce++
	mut keys := []ScrollRasterCommandKey{len: commands.len}
	mut begins := []int{}
	mut group_bounded := []bool{}
	mut group_has_ink := []bool{}
	mut group_ink := []layout.LayoutRect{}
	mut group_content := []u64{}
	mut group_position_dependent := []bool{}
	trailing_start := layout.scroll_raster_trailing_scrollbar_start(commands)
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		mut key := ScrollRasterCommandKey{
			hash:  scroll_raster_command_hash(command, scroll)
			kind:  command.kind
			doc_x: command.x
			doc_y: command.y
		}
		if scroll_raster_damage_diagnostics {
			key.parts = scroll_raster_command_hash_parts(command, scroll)
		}
		if scroll_raster_viewport_filling_solid(command, width, height) {
			// A uniform fill covering the whole viewport paints the same pixels
			// at every scroll offset; the exposed strip regenerates its rows.
			// Neutralize its translation whether or not the scroll is folded in.
			key.hash = scroll_raster_command_hash_ex(command, scroll, true)
		} else if scroll_raster_damage_diagnostics && command.kind == 'fill_rect'
			&& command.width >= width && command.height >= height {
			scroll_raster_report_fill_flags(command)
		}
		if command.scrollbar_axis != '' {
			if index >= trailing_start && !inline_scrollbars {
				key.skip_diff = true
				keys[index] = key
				continue
			}
			key.hash = srk_f64(key.hash, scrollbar_opacity)
		}
		if layout.scroll_raster_group_begin(command.kind) {
			position_dependent := command.kind == 'begin_css_filter_layer' && !layout.scroll_raster_filter_is_pointwise(command)
				&& !(begins.len == 0 && chromium_gradient_blur_input_supported(commands, index))
			if position_dependent && disable_stationary_filter_reuse {
				// Same-binary control for the unconditional per-frame damage.
				key.hash = srk_mix(key.hash, scroll_raster_canvas_nonce)
			}
			begins << index
			group_bounded << true
			group_has_ink << false
			group_ink << layout.LayoutRect{}
			if !disable_stationary_filter_reuse {
				group_content << u64(0xcbf29ce484222325)
				group_position_dependent << position_dependent
			}
			keys[index] = key
			continue
		}
		if begins.len > 0 && command.kind == layout.scroll_raster_group_end(commands[begins.last()].kind) {
			begin := begins.pop()
			bounded := group_bounded.pop()
			has_ink := group_has_ink.pop()
			ink := group_ink.pop()
			mut content := u64(0)
			mut position_dependent := false
			if !disable_stationary_filter_reuse {
				content = group_content.pop()
				position_dependent = group_position_dependent.pop()
			}
			begin_command := unsafe { &commands[begin] }
			if !disable_stationary_filter_reuse && begin_command.kind == 'begin_css_filter_layer'
				&& !layout.scroll_raster_filter_is_pointwise(begin_command) {
				// A stationary filter with identical ordered inputs has the same
				// raster origin and pixels. Changing any descendant damages its
				// complete inflated output, including nested groups and live media.
				keys[begin].hash = srk_mix(keys[begin].hash, content)
				if position_dependent { keys[begin].hash = srk_f64(keys[begin].hash, scroll) }
			}
			mut group := ?layout.LayoutRect(none)
			if bounded && has_ink { group = ink }
			if bounded && !has_ink {
				// A group without painted leaves writes nothing.
				group = layout.LayoutRect{0, 0, 0, 0}
			}
			match begin_command.kind {
				'begin_css_filter_layer' {
					if rect := group {
						if extent := layout.scroll_raster_filter_extent(begin_command) {
							group = if scroll_raster_rect_valid(rect) { scroll_raster_inflate(rect, extent) } else { rect }
						} else {
							group = none
						}
					}
				}
				'begin_background_text_clip' {
					// Output is confined to the text box regardless of the
					// gradient sources painted inside it.
					source := layout.PaintCommand{
						kind:      'fill_rect'
						x:         begin_command.x
						y:         begin_command.y
						width:     begin_command.width
						height:    begin_command.height
						transform: begin_command.transform
					}
					group = layout.scroll_raster_leaf_ink_bounds(&source)
				}
				else {}
			}
			if begin_command.has_clip {
				if rect := group {
					if begin_command.clip_width > 0 && begin_command.clip_height > 0 {
						group = layout.scroll_raster_rect_intersect(rect, layout.LayoutRect{begin_command.clip_x, begin_command.clip_y, begin_command.clip_width, begin_command.clip_height})
					}
				}
			}
			keys[begin].group_end = index
			if rect := group {
				keys[begin].has_ink = true
				keys[begin].ink = rect
			}
			// A group end writes nothing of its own; its begin carries the
			// group's damage. Keep it bounded so an entering group reconciles.
			key.has_ink = true
			key.ink = layout.LayoutRect{0, 0, 0, 0}
			keys[index] = key
			if begins.len > 0 {
				if !disable_stationary_filter_reuse {
					last := group_content.len - 1
					group_content[last] = srk_mix(group_content[last], srk_mix(keys[begin].hash, content))
				}
				scroll_raster_accumulate_group_ink(mut group_bounded, mut group_has_ink, mut group_ink, group)
			}
			continue
		}
		ink := scroll_raster_key_ink(command)
		if rect := ink {
			key.has_ink = true
			key.ink = rect
		}
		keys[index] = key
		if begins.len > 0 {
			if !disable_stationary_filter_reuse {
				last := group_content.len - 1
				group_content[last] = srk_mix(group_content[last], key.hash)
			}
			scroll_raster_accumulate_group_ink(mut group_bounded, mut group_has_ink, mut group_ink, ink)
		}
	}
	return keys
}

// A leaf's viewport-space ink within its conservative clip rectangle. Large
// decorations inside an `overflow: hidden` box (vlang.io's rotated orbit and
// its 60px shadow) otherwise touch every exposed strip. The rectangle bounds
// the transformed clip list in the same space, as for group keys.
fn scroll_raster_key_ink(command &layout.PaintCommand) ?layout.LayoutRect {
	ink := layout.scroll_raster_leaf_ink_bounds(command)?
	if !command.has_clip || !(command.clip_width > 0) || !(command.clip_height > 0)
		|| !scroll_raster_rect_valid(ink) {
		return ink
	}
	clip := layout.LayoutRect{command.clip_x, command.clip_y, command.clip_width, command.clip_height}
	if !scroll_raster_rect_valid(clip) { return ink }
	clipped := layout.scroll_raster_rect_intersect(ink, clip)
	if clipped.width > 0 && clipped.height > 0 { return clipped }
	if disable_minimal_clipped_ink { return clip }
	// Ink beside the clip paints nothing, unless a device pixel straddles a
	// sub-pixel gap between them; keep that sliver of the clip.
	guarded := layout.scroll_raster_rect_intersect(scroll_raster_inflate(ink,
		scroll_raster_clipped_ink_guard), clip)
	if guarded.width > 0 && guarded.height > 0 { return guarded }
	// Nothing is visible, so any bounded rectangle inside the clip is
	// conservative. Use the smallest one, nearest the ink: vlang.io's
	// overflowing demo text enters and leaves the recorded interest area while
	// clipped away, and the whole clip made that damage its entire card.
	width := math.min(clip.width, 1.0)
	height := math.min(clip.height, 1.0)
	return layout.LayoutRect{math.min(math.max(ink.x, clip.x), clip.x + clip.width - width),
		math.min(math.max(ink.y, clip.y), clip.y + clip.height - height), width, height}
}

// The root canvas background is recorded anchored to the viewport origin with
// an identity transform and the document's height. Its pixels are identical at
// every scroll offset, so it must not be damaged by the scroll-compensated
// transform key; fixed content keeps that churn and the damage it produces.
fn scroll_raster_viewport_filling_solid(command &layout.PaintCommand, width f64, height f64) bool {
	if command.kind != 'fill_rect' || command.radius != 0 || command.blur != 0
		|| command.outer_shadow || command.clip_outs.len > 0 || command.points.len > 0
		|| command.text_clip_runs.len > 0 || command.box_shadow_data != unsafe { nil } {
		return false
	}
	if command.recording_clip != none || command.visual_layer_data != none { return false }
	// Device-pixel layouts record the fill under a pure scale; a uniform fill
	// stays translation invariant under any axis-aligned scale, but a rotated
	// or sheared fill paints antialiased edges that depend on its position.
	matrix := layout.scroll_raster_normalized_transform(command.transform)
	if matrix[1] != 0 || matrix[2] != 0 { return false }
	ink := layout.scroll_raster_leaf_ink_bounds(command) or { return false }
	return ink.x <= 0 && ink.y <= 0 && ink.x + ink.width >= width && ink.y + ink.height >= height
}

fn scroll_raster_accumulate_group_ink(mut bounded []bool, mut has_ink []bool, mut inks []layout.LayoutRect, ink ?layout.LayoutRect) {
	last := bounded.len - 1
	rect := ink or {
		bounded[last] = false
		return
	}
	if rect.width <= 0 || rect.height <= 0 { return }
	if has_ink[last] {
		inks[last] = layout.scroll_raster_rect_union(inks[last], rect) or { rect }
	} else {
		inks[last] = rect
		has_ink[last] = true
	}
}

// Damage rectangles, in current viewport space, covering every command whose
// content differs from the previous frame. none means the frames cannot be
// reconciled and the viewport needs complete replay.
fn scroll_raster_content_damage(previous &ScrollRasterKeyFrame, current []ScrollRasterCommandKey,
	document u64, scroll f64, width f64, height f64, mut stats ScrollRasterDiffStats) ?[]layout.LayoutRect {
	if !previous.valid || previous.document != document || previous.width != width
		|| previous.height != height {
		stats.fallback = 'no-previous-frame'
		return none
	}
	delta := scroll - previous.scroll
	if math.is_nan(delta) || math.is_inf(delta, 0) {
		stats.fallback = 'invalid-scroll'
		return none
	}
	mut positions := map[u64][]int{}
	for index, key in previous.keys {
		if key.skip_diff { continue }
		positions[key.hash] << index
	}
	mut cursors := map[u64]int{}
	mut added := []int{}
	mut changed := 0
	mut last_matched := -1
	mut order_changed := false
	for current_index, key in current {
		if key.skip_diff { continue }
		if indices := positions[key.hash] {
			cursor := cursors[key.hash]
			if cursor < indices.len {
				matched := indices[cursor]
				cursors[key.hash] = cursor + 1
				if matched < last_matched { order_changed = true }
				if matched > last_matched { last_matched = matched }
				continue
			}
		}
		changed++
		if scroll_raster_damage_diagnostics && changed <= 6 {
			scroll_raster_report_unmatched(previous, key, delta)
		}
		if !key.has_ink {
			stats.fallback = 'unbounded-new-${key.kind}'
			return none
		}
		added << current_index
	}
	mut removed := []int{}
	for hash, indices in positions {
		cursor := cursors[hash]
		for index in cursor .. indices.len {
			key := previous.keys[indices[index]]
			changed++
			if !key.has_ink {
				stats.fallback = 'unbounded-old-${key.kind}'
				return none
			}
			removed << indices[index]
		}
	}
	// A video that only advanced its frame left and entered the same ink.
	mut paired := []bool{len: previous.keys.len}
	mut video_frames := []int{}
	for current_index in added {
		key := current[current_index]
		if !key.video_backdrop { continue }
		for old_index in removed {
			old := previous.keys[old_index]
			if paired[old_index] || old.kind != 'draw_video'
				|| !scroll_raster_same_rect(old.ink, key.ink, delta) { continue }
			paired[old_index] = true
			video_frames << current_index
			break
		}
	}
	mut rects := []layout.LayoutRect{}
	for current_index in added {
		if current_index !in video_frames { rects << current[current_index].ink }
	}
	for old_index in removed {
		if paired[old_index] { continue }
		key := previous.keys[old_index]
		rects << layout.LayoutRect{key.ink.x, key.ink.y - delta, key.ink.width, key.ink.height}
	}
	stats.changed = changed
	if order_changed {
		stats.fallback = 'paint-order-changed'
		return none
	}
	if disable_coalesced_scroll_damage && changed > scroll_raster_max_changed_commands {
		stats.fallback = 'too-many-changes'
		return none
	}
	viewport := layout.LayoutRect{0, 0, width, height}
	mut clamped := []layout.LayoutRect{}
	mut area := 0.0
	for rect in rects {
		if !scroll_raster_rect_valid(rect) { continue }
		fringed := scroll_raster_inflate(rect, scroll_raster_damage_fringe)
		visible := layout.scroll_raster_rect_intersect(fringed, viewport)
		if visible.width <= 0 || visible.height <= 0 { continue }
		snapped := scroll_raster_snap_rect(visible)
		area += snapped.width * snapped.height
		clamped << snapped
	}
	mut restores := []ScrollRasterVideoRestore{}
	for current_index in video_frames {
		ink := current[current_index].ink
		if !scroll_raster_rect_valid(ink) { continue }
		fringed := scroll_raster_inflate(ink, scroll_raster_damage_fringe)
		visible := layout.scroll_raster_rect_intersect(fringed, viewport)
		if visible.width <= 0 || visible.height <= 0 { continue }
		snapped := scroll_raster_snap_rect(visible)
		whole := scroll_raster_snap_rect(fringed)
		area += snapped.width * snapped.height
		restores << ScrollRasterVideoRestore{
			index:    current_index
			rect:     snapped
			document: layout.LayoutRect{whole.x, whole.y + scroll, whole.width, whole.height}
		}
	}
	if disable_coalesced_scroll_damage && area > scroll_raster_max_damage_fraction * width * height {
		if scroll_raster_damage_diagnostics {
			eprintln('VOX_SCROLL_RASTER_AREA legacy=true area=${area} limit=${scroll_raster_max_damage_fraction * width * height} rects=${clamped} restores=${restores.len}')
		}
		stats.fallback = 'damage-too-large'
		return none
	}
	// Other damage beneath a video would be overwritten by its old backdrop.
	for restore in restores {
		mut overlaps := clamped.any(scroll_raster_rects_overlap(it, restore.rect))
		for other in restores {
			if other.index != restore.index && scroll_raster_rects_overlap(other.rect, restore.rect) {
				overlaps = true
			}
		}
		if overlaps {
			clamped << restore.rect
		} else {
			stats.restores << restore
		}
	}
	if !disable_coalesced_scroll_damage {
		for {
			clamped = scroll_raster_coalesce_damage(clamped) or {
				stats.fallback = 'too-many-damage-rects'
				return none
			}
			// A conservative bounding join can newly touch a video's saved
			// backdrop. Convert that restore to ordinary damage, then merge
			// again until no remaining restore intersects the published ink.
			mut untouched := []ScrollRasterVideoRestore{}
			for restore in stats.restores {
				if clamped.any(scroll_raster_rects_overlap(it, restore.rect)) {
					clamped << restore.rect
				} else {
					untouched << restore
				}
			}
			if untouched.len == stats.restores.len { break }
			stats.restores = untouched
		}
		if clamped.len + stats.restores.len > scroll_raster_max_damage_rects {
			stats.fallback = 'too-many-damage-rects'
			return none
		}
		// Changed command count and summed per-command ink do not describe
		// repaint work: old/new ink, shadows and group extents often cover the
		// same pixels. Bound the conservative rectangles actually published.
		area = 0
		for rect in clamped { area += rect.width * rect.height }
		for restore in stats.restores { area += restore.rect.width * restore.rect.height }
		if area > scroll_raster_max_damage_fraction * width * height {
			if scroll_raster_damage_diagnostics {
				eprintln('VOX_SCROLL_RASTER_AREA legacy=false area=${area} limit=${scroll_raster_max_damage_fraction * width * height} rects=${clamped} restores=${stats.restores.len}')
			}
			stats.fallback = 'damage-too-large'
			return none
		}
	}
	stats.rects = clamped.len
	return clamped
}

// Each join conservatively covers both inputs. Restart after a join because
// its bounding rectangle can meet an earlier rectangle. The final rectangles
// are disjoint, so their summed area is an upper bound on actual damage, and
// neither duplicate old/new ink nor a parent group's ink is charged twice.
fn scroll_raster_coalesce_damage(rects []layout.LayoutRect) ?[]layout.LayoutRect {
	mut merged := []layout.LayoutRect{}
	for rect in rects {
		mut bounds := rect
		mut index := 0
		for index < merged.len {
			other := merged[index]
			if bounds.x <= other.x + other.width && other.x <= bounds.x + bounds.width
				&& bounds.y <= other.y + other.height && other.y <= bounds.y + bounds.height {
				left := math.min(bounds.x, other.x)
				top := math.min(bounds.y, other.y)
				right := math.max(bounds.x + bounds.width, other.x + other.width)
				bottom := math.max(bounds.y + bounds.height, other.y + other.height)
				bounds = layout.LayoutRect{left, top, right - left, bottom - top}
				merged.delete(index)
				index = 0
			} else {
				index++
			}
		}
		merged << bounds
		// Declining early may miss a later rectangle that would join these,
		// but prevents a large disjoint display list from quadratic work.
		if merged.len > scroll_raster_max_damage_rects { return none }
	}
	return merged
}

// Snap outward to whole CSS pixels so device clips stay conservative.
fn scroll_raster_snap_rect(rect layout.LayoutRect) layout.LayoutRect {
	left := math.floor(rect.x)
	top := math.floor(rect.y)
	right := math.ceil(rect.x + rect.width)
	bottom := math.ceil(rect.y + rect.height)
	return layout.LayoutRect{left, top, right - left, bottom - top}
}

fn scroll_raster_rects_overlap(a layout.LayoutRect, b layout.LayoutRect) bool {
	return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height
		&& b.y < a.y + a.height
}

// The retained ink, translated by the scroll since that frame, is this ink.
fn scroll_raster_same_rect(old layout.LayoutRect, current layout.LayoutRect, delta f64) bool {
	return math.abs(old.x - current.x) < 0.000001
		&& math.abs(old.y - delta - current.y) < 0.000001
		&& math.abs(old.width - current.width) < 0.000001
		&& math.abs(old.height - current.height) < 0.000001
}

// Whether viewport-space ink, with the native raster fringe, touches any
// damage rectangle. Empty ink cannot prove that a command writes nothing.
fn scroll_raster_ink_touches(ink layout.LayoutRect, region []layout.LayoutRect) bool {
	if !scroll_raster_rect_valid(ink) { return true }
	fringed := scroll_raster_inflate(ink, scroll_raster_damage_fringe)
	for rect in region {
		if rect.width <= 0 || rect.height <= 0 { continue }
		if fringed.x < rect.x + rect.width && fringed.x + fringed.width > rect.x
			&& fringed.y < rect.y + rect.height && fringed.y + fringed.height > rect.y {
			return true
		}
	}
	return false
}

// Per-command replay decisions for a reused frame. A group whose complete
// extent misses the damage is skipped with both boundaries; a filter layer
// that mixes neighboring pixels replays all of its contents once it touches
// the damage; every other group replays only the leaves inside the damage.
fn plan_scroll_raster_skips(commands []layout.PaintCommand, keys []ScrollRasterCommandKey,
	region []layout.LayoutRect, unoptimized bool) []bool {
	return plan_scroll_raster_skips_with_restores(commands, keys, region, []ScrollRasterVideoRestore{},
		unoptimized)
}

// A restored video rectangle already holds every pixel painted beneath the
// video, so only the video and later commands can touch it.
fn scroll_raster_restore_touches(ink layout.LayoutRect, last int, restores []ScrollRasterVideoRestore) bool {
	for restore in restores {
		if last >= restore.index && scroll_raster_ink_touches(ink, [restore.rect]) { return true }
	}
	return false
}

fn plan_scroll_raster_skips_with_restores(commands []layout.PaintCommand, keys []ScrollRasterCommandKey,
	region []layout.LayoutRect, restores []ScrollRasterVideoRestore, unoptimized bool) []bool {
	mut skip := []bool{len: commands.len}
	if keys.len != commands.len { return skip }
	mut index := 0
	for index < commands.len {
		command := unsafe { &commands[index] }
		key := keys[index]
		if layout.scroll_raster_group_begin(command.kind) && key.group_end > index {
			if key.has_ink && !scroll_raster_ink_touches(key.ink, region)
				&& !scroll_raster_restore_touches(key.ink, key.group_end, restores) {
				for inner in index .. key.group_end + 1 {
					skip[inner] = true
				}
				index = key.group_end + 1
				continue
			}
			if command.kind == 'begin_css_filter_layer' && !layout.scroll_raster_filter_is_pointwise(command) {
				index = key.group_end + 1
				continue
			}
			index++
			continue
		}
		if layout.scroll_raster_group_end(command.kind) != '' || command.kind.starts_with('end_')
			|| command.kind.starts_with('begin_') {
			index++
			continue
		}
		// Checkbox and button fills can defer their pixels to the following
		// border draw. Decide both operations together so culling can never
		// pair an underlay with a later box: skip the pair only when neither
		// touches the damage, otherwise replay both.
		if command.underlays_next && command.scrollbar_axis == '' && index + 1 < commands.len {
			next := unsafe { &commands[index + 1] }
			next_key := keys[index + 1]
			if !next.underlays_next && next.scrollbar_axis == '' && !next.kind.starts_with('begin_')
				&& !next.kind.starts_with('end_') {
				touched := !key.has_ink || !next_key.has_ink
					|| scroll_raster_ink_touches(key.ink, region)
					|| scroll_raster_ink_touches(next_key.ink, region)
					|| scroll_raster_restore_touches(key.ink, index, restores)
					|| scroll_raster_restore_touches(next_key.ink, index + 1, restores)
				if !touched {
					skip[index] = true
					skip[index + 1] = true
				}
				index += 2
				continue
			}
		}
		if command.underlays_next || command.kind == 'stroke_rounded_rect' || command.scrollbar_axis != '' {
			index++
			continue
		}
		if unoptimized && command.kind in ['draw_replaced_image', 'draw_background_image'] {
			index++
			continue
		}
		if key.has_ink && !scroll_raster_ink_touches(key.ink, region)
			&& !scroll_raster_restore_touches(key.ink, index, restores) {
			skip[index] = true
		}
		index++
	}
	return skip
}

fn scroll_raster_strip_region(delta f64, width f64, height f64) []layout.LayoutRect {
	if delta == 0 || math.is_nan(delta) || math.is_inf(delta, 0) { return []layout.LayoutRect{} }
	strip := math.min(height, math.abs(delta))
	if delta > 0 {
		return [layout.LayoutRect{0, height - strip, width, strip}]
	}
	return [layout.LayoutRect{0, 0, width, strip}]
}

fn scroll_raster_flatten_rects(rects []layout.LayoutRect) []f64 {
	mut flat := []f64{cap: rects.len * 4}
	for rect in rects {
		flat << rect.x
		flat << rect.y
		flat << rect.width
		flat << rect.height
	}
	return flat
}

// Diagnostics: name the key components that differ between an unmatched
// current key and the previous key with the same kind and document position.
// Why a viewport-sized fill was not treated as translation invariant.
fn scroll_raster_report_fill_flags(command &layout.PaintCommand) {
	matrix := layout.scroll_raster_normalized_transform(command.transform)
	ink := layout.scroll_raster_leaf_ink_bounds(command) or { layout.LayoutRect{} }
	eprintln('VOX_SCROLL_RASTER_FILL kind=${command.kind} rect=${command.x},${command.y},${command.width},${command.height} ink=${ink.x},${ink.y},${ink.width},${ink.height} radius=${command.radius} blur=${command.blur} outer=${command.outer_shadow} has_clip=${command.has_clip} clip_outs=${command.clip_outs.len} points=${command.points.len} text_clips=${command.text_clip_runs.len} shadow=${command.box_shadow_data != unsafe { nil }} recording_clip=${command.recording_clip != none} layer=${command.visual_layer_data != none} layers=${if command.visual_layer_list != unsafe { nil } { command.visual_layer_list.items.len } else { -1 }} fixed=${command.fixed_to_viewport} matrix=${matrix}')
}

fn scroll_raster_report_unmatched(previous &ScrollRasterKeyFrame, key ScrollRasterCommandKey, delta f64) {
	mut nearest := -1
	for index, candidate in previous.keys {
		if candidate.kind == key.kind && candidate.doc_x == key.doc_x && candidate.doc_y == key.doc_y {
			nearest = index
			break
		}
	}
	if nearest < 0 {
		eprintln('VOX_SCROLL_RASTER_UNMATCHED kind=${key.kind} doc=${key.doc_x},${key.doc_y} ink=${key.ink.x},${key.ink.y},${key.ink.width},${key.ink.height} previous=none')
		return
	}
	mut differing := []string{}
	for part in 0 .. 8 {
		if previous.keys[nearest].parts[part] != key.parts[part] { differing << scroll_raster_key_part_names[part] }
	}
	eprintln('VOX_SCROLL_RASTER_UNMATCHED kind=${key.kind} doc=${key.doc_x},${key.doc_y} ink=${key.ink.x},${key.ink.y},${key.ink.width},${key.ink.height} delta=${delta} differs=${differing.join(',')}')
}

// Component hashes mirroring scroll_raster_command_hash's field groups.
fn scroll_raster_command_hash_parts(command &layout.PaintCommand, scroll f64) [8]u64 {
	mut parts := [8]u64{}
	seed := u64(0xcbf29ce484222325)
	mut h := srk_str(seed, command.kind)
	h = srk_f64(h, command.x)
	h = srk_f64(h, command.y)
	h = srk_f64(h, command.width)
	h = srk_f64(h, command.height)
	parts[0] = h
	h = srk_str(seed, command.color)
	if command.srgb_color_data != unsafe { nil } {
		for component in command.srgb_color_data.components { h = srk_f64(h, component) }
	}
	h = srk_f64(h, command.opacity)
	h = srk_f64(h, command.group_opacity)
	h = srk_bool(h, command.antialiased_rect)
	h = srk_bool(h, command.underlays_next)
	h = srk_int(h, int(command.force_dark_role))
	parts[1] = h
	h = srk_str(seed, command.text)
	if run := command.glyph_run { h = srk_ptr(h, voidptr(run)) }
	h = srk_f64(h, command.glyph_translation_x)
	h = srk_f64(h, command.glyph_translation_y)
	h = srk_f64(h, command.font_size)
	parts[2] = h
	h = srk_f64(seed, command.radius)
	h = srk_radii(h, command.corner_radii)
	h = srk_f64(h, command.blur)
	h = srk_f64(h, command.shadow_offset_x)
	h = srk_f64(h, command.shadow_offset_y)
	h = srk_f64(h, command.shadow_spread)
	if command.box_shadow_data != unsafe { nil } {
		h = srk_rect(h, command.box_shadow_data.content_rect)
		h = srk_rect(h, command.box_shadow_data.inner_rect)
	}
	h = srk_int(h, command.points.len)
	for value in command.points { h = srk_f64(h, value) }
	h = srk_str(h, command.stroke_color)
	h = srk_f64(h, command.stroke_width)
	parts[3] = h
	h = seed
	if gradient := command.gradient { h = srk_gradient(h, gradient) }
	h = srk_svg_path(h, command.svg_data)
	h = srk_image_data(h, command.image_data)
	if scroll_raster_background_offset_is_painted(command) {
		h = srk_f64(h, command.image_scroll_offset_x)
		h = srk_f64(h, command.image_scroll_offset_y)
	}
	if paintable := command.image_paintable { h = srk_image_paintable(h, paintable) }
	if bitmap := command.replaced_image_bitmap { h = srk_ptr(h, voidptr(bitmap)) }
	h = srk_local_border(h, command.local_border_data)
	h = srk_ptr(h, voidptr(command.checkbox_theme_data))
	if source := command.video_frame_source {
		h = srk_ptr(h, voidptr(source))
		if frame := source.current_frame() { h = srk_mix(srk_ptr(h, voidptr(frame)), frame.generation) }
	}
	parts[4] = h
	parts[5] = srk_transform(seed, command.transform, scroll)
	h = srk_bool(seed, command.has_clip)
	if command.has_clip {
		h = srk_f64(h, command.clip_x)
		h = srk_f64(h, command.clip_y + scroll)
		h = srk_f64(h, command.clip_width)
		h = srk_f64(h, command.clip_height)
	}
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			h = srk_rect(h, clip.rect)
			h = srk_mix(h, clip.cache_key)
			h = srk_transform(h, clip.transform, scroll)
		}
	}
	if clip := command.recording_clip { h = srk_rect(h, clip) }
	parts[6] = h
	h = seed
	if command.visual_layer_list != unsafe { nil } {
		for layer in command.visual_layer_list.items { h = srk_mix(srk_f64(h, layer.opacity), layer.scope_id) }
	}
	if layer := command.visual_layer_data {
		h = srk_mix(h, layer.scope_id)
		h = srk_f64(h, layer.opacity)
		if clip := layer.clip_rect { h = srk_f64(srk_f64(h, clip.x), clip.y + scroll) }
	}
	if context_index := command.visual_context_index { h = srk_int(h, context_index) }
	parts[7] = h
	return parts
}
