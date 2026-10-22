// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import html
import painting
import platform
import math

$if gcboehm ? {
	fn C.GC_gcollect()
}

// Exact baseline record/producers, only their symbols/types are renamed.
// Baseline full canonical revision a24c790baa13da6777f37b351110af94ceb4134c.
pub struct LegacySVGPathPaintCommand {
pub mut:
	kind                      string // fill_rect/fill_rounded_rect/stroke_rounded_rect/fill_ellipse/stroke_ellipse/fill_polygon/draw_line/draw_text/draw_svg_path
	x                         f64
	y                         f64
	width                     f64
	height                    f64
	color                     string
	force_dark_role           painting.ForceDarkRole
	force_dark_role_set       bool
	force_dark_backdrop       ?painting.Color = none
	apply_force_dark_to_image bool
	line_box_debug            bool
	text                      string // for 'draw_text'
	font_size                 f64 = 16.0 // for 'draw_text'
	bold                      bool
	italic                    bool
	mono                      bool
	rtl                       bool // base paragraph direction for shaped text
	// DisplayListRecorder::DrawGlyphRun retains shaped glyph indices and
	// positions. Raw text remains only as the portable/backend compatibility
	// fallback; the native player must not shape it again during every repaint.
	glyph_run           ?&platform.GlyphRun = none
	glyph_translation_x f64
	glyph_translation_y f64
	glyph_orientation   painting.Orientation
	font_smoothing      css.FontSmoothing
	opacity             f64 = 1.0 // the box's cumulative opacity (this box × its ancestors')
	// Product of the retained CSS effect layers surrounding this command. The
	// native player divides it out of `opacity`, because those layers composite
	// the complete subtree atomically. Portable backends keep the historical
	// flattened-alpha fallback until they gain offscreen effect surfaces.
	group_opacity f64 = 1.0
	radius        f64 // corner radius for a rounded 'fill_rect' (0 = square)
	// Retained used corner radii for `fill_rounded_rect`. This mirrors Painting's
	// FillRoundedRect command instead of discarding elliptical/per-corner radii into vertices.
	corner_radii    BoxRadii
	blur            f64 // Gaussian blur radius for a 'fill_rect' (0 = hard edges), used by box-shadow
	shadow_offset_x f64
	shadow_offset_y f64
	shadow_spread   f64
	outer_shadow    bool // clip the shadow source out of the original border box
	// Ordinary commands need no box-shadow geometry. Shadow commands retain
	// one immutable source-space snapshot across phase caches and replays.
	box_shadow_data &PaintBoxShadowData = unsafe { nil }
	// Only gradient commands retain a resolved background image. Share its
	// immutable snapshot across cached phases instead of embedding it in every
	// text, border and image command.
	gradient                  ?&LinearGradient = none
	gradient_background_layer bool
	// `draw_svg_path` payload.
	path      string
	path_data []f32
	// Cumulative CSS/SVG affine transform in `matrix(a,b,c,d,e,f)` order. All-zero means identity.
	transform            [6]f64
	path_transform       [6]f64
	points               []f64
	path_polygons        [][]f64
	stroke_color         string
	svg_gradient_data    ?&PaintSVGGradientData          = none
	svg_solid_color_data &PaintSVGSolidColorData         = unsafe { nil }
	fill_pattern         ?&painting.SVGPatternPaintStyle = none
	stroke_pattern       ?&painting.SVGPatternPaintStyle = none
	stroke_width         f64
	stroke_dasharray     []f64
	stroke_dashoffset    f64
	non_scaling_stroke   bool
	stroke_first         bool
	fill_even_odd        bool
	stroke_linecap       int
	stroke_linejoin      int
	stroke_miterlimit    f64    = 4.0
	line_style           string = 'solid'
	fill_opacity         f64    = 1.0
	stroke_opacity       f64    = 1.0
	// Immutable background and replaced-image parameters are retained only by
	// commands which use them, and shared through phase caches and replay.
	image_data            &PaintImageData = unsafe { nil }
	image_scroll_offset_x f64
	image_scroll_offset_y f64
	// BackgroundPainting temporarily switches only fixed layers to the visual
	// context which compensates every ancestor scroll frame.
	visual_context_index ?int = none
	// Allocate immutable replaced-content snapshots only for commands which
	// use them. Most commands are text or borders and need no media payload.
	// Background images continue through BackgroundPainting.
	image_paintable       ?&painting.ImagePaintable = none
	replaced_image_bitmap ?&dom.Bitmap_             = none
	// CanvasPaintable publishes its current RGBA surface as external content.
	canvas_bitmap    ?&dom.Bitmap_              = none
	canvas_paintable ?&painting.CanvasPaintable = none
	// VideoPaintable retains the representation switch separately from the
	// optional poster/current-frame bitmap.
	video_bitmap         ?&dom.Bitmap_               = none
	video_frame_source   ?&painting.VideoFrameSource = none
	video_representation painting.VideoRepresentation
	video_paintable      ?&painting.VideoPaintable = none
	// NavigableContainerViewportPaintable retains the hosted document's
	// display list as a nested command stream rather than rasterizing it.
	nested_viewport_commands  []LegacySVGPathPaintCommand
	nested_viewport_paintable ?&painting.NavigableContainerViewportPaintable = none
	// Synthetic balanced controls around the complete background color/layer
	// group. The begin command owns the inclusive-subtree glyph runs.
	text_clip_runs []PaintTextClipRun
	// Display-list replay retains every accumulated clip node in source order.
	// The scalar rectangle is their conservative intersection for fast reject
	// and the non-native scissor fallback; native rasterization consumes the
	// shared clip list so rounded and nested clips preserve their exact shapes.
	has_clip    bool
	clip_x      f64
	clip_y      f64
	clip_width  f64
	clip_height f64
	clip_list   &PaintClipList = unsafe { nil }
	// A DisplayListRecorder clip local to this command's paint phase. Unlike an
	// accumulated visual-context clip, it does not apply to other phases or
	// descendants (FieldSetPaintable uses this for its background and top edge).
	recording_clip ?LayoutRect = none
	// Effects and SVG masks are group operations. Retain their ancestor order so
	// replay can emit balanced layer boundaries around the complete subtree.
	visual_layer_list &PaintVisualLayerList = unsafe { nil }
	visual_layer_data ?&PaintVisualLayer    = none
	// ApplyBackdropFilter samples the already-painted destination. If this box
	// also has `filter`, that sample comes from outside its newly-opened filter
	// layer while the filtered backdrop is painted into the layer with the box.
	backdrop_filter_data           ?&painting.GfxFilter = none
	backdrop_source_outside_filter bool
	// Nested viewport replay can override the mask geometry while sharing the
	// immutable layer snapshot retained by the original recording.
	mask_clip_data ?&PaintClip = none
	// Fixed commands inherit the root visual context rather than the viewport
	// scroll frame. Retain that classification for native/debug consumers.
	fixed_to_viewport bool
	// PaintScrollBar is moved by the live snapshot in DisplayListPlayer rather
	// than forcing its retained overlay phase to be regenerated.
	scrollbar_axis                   string
	scrollbar_thumb_travel_ratio     f64
	scrollbar_recorded_scroll_offset f64
mut:
	paint_box_index int
	paint_phase     CompatibilityPaintPhase
}

fn svg_payload_legacy(command PaintCommand) LegacySVGPathPaintCommand {
	data := command.svg()
	return LegacySVGPathPaintCommand{
		kind:                             command.kind
		x:                                command.x
		y:                                command.y
		width:                            command.width
		height:                           command.height
		color:                            command.color
		force_dark_role:                  command.force_dark_role
		force_dark_role_set:              command.force_dark_role_set
		force_dark_backdrop:              command.force_dark_backdrop
		apply_force_dark_to_image:        command.apply_force_dark_to_image
		line_box_debug:                   command.line_box_debug
		text:                             command.text
		font_size:                        command.font_size
		bold:                             command.bold
		italic:                           command.italic
		mono:                             command.mono
		rtl:                              command.rtl
		glyph_run:                        command.glyph_run
		glyph_translation_x:              command.glyph_translation_x
		glyph_translation_y:              command.glyph_translation_y
		glyph_orientation:                command.glyph_orientation
		font_smoothing:                   command.font_smoothing
		opacity:                          command.opacity
		group_opacity:                    command.group_opacity
		radius:                           command.radius
		corner_radii:                     command.corner_radii
		blur:                             command.blur
		shadow_offset_x:                  command.shadow_offset_x
		shadow_offset_y:                  command.shadow_offset_y
		shadow_spread:                    command.shadow_spread
		outer_shadow:                     command.outer_shadow
		box_shadow_data:                  command.box_shadow_data
		gradient:                         command.gradient
		gradient_background_layer:        command.gradient_background_layer
		path:                             data.path
		path_data:                        data.path_data
		transform:                        command.transform
		path_transform:                   data.path_transform
		points:                           command.points
		path_polygons:                    data.path_polygons
		stroke_color:                     command.stroke_color
		svg_gradient_data:                data.svg_gradient_data
		svg_solid_color_data:             data.svg_solid_color_data
		fill_pattern:                     data.fill_pattern
		stroke_pattern:                   data.stroke_pattern
		stroke_width:                     command.stroke_width
		stroke_dasharray:                 data.stroke_dasharray
		stroke_dashoffset:                data.stroke_dashoffset
		non_scaling_stroke:               data.non_scaling_stroke
		stroke_first:                     data.stroke_first
		fill_even_odd:                    data.fill_even_odd
		stroke_linecap:                   data.stroke_linecap
		stroke_linejoin:                  data.stroke_linejoin
		stroke_miterlimit:                data.stroke_miterlimit
		line_style:                       command.line_style
		fill_opacity:                     data.fill_opacity
		stroke_opacity:                   data.stroke_opacity
		image_data:                       command.image_data
		image_scroll_offset_x:            command.image_scroll_offset_x
		image_scroll_offset_y:            command.image_scroll_offset_y
		visual_context_index:             command.visual_context_index
		image_paintable:                  command.image_paintable
		replaced_image_bitmap:            command.replaced_image_bitmap
		canvas_bitmap:                    command.canvas_bitmap
		canvas_paintable:                 command.canvas_paintable
		video_bitmap:                     command.video_bitmap
		video_frame_source:               command.video_frame_source
		video_representation:             command.video_representation
		video_paintable:                  command.video_paintable
		nested_viewport_commands:         command.nested_viewport_commands.map(svg_payload_legacy(it))
		nested_viewport_paintable:        command.nested_viewport_paintable
		text_clip_runs:                   command.text_clip_runs
		has_clip:                         command.has_clip
		clip_x:                           command.clip_x
		clip_y:                           command.clip_y
		clip_width:                       command.clip_width
		clip_height:                      command.clip_height
		clip_list:                        command.clip_list
		recording_clip:                   command.recording_clip
		visual_layer_list:                command.visual_layer_list
		visual_layer_data:                command.visual_layer_data
		backdrop_filter_data:             command.backdrop_filter_data
		backdrop_source_outside_filter:   command.backdrop_source_outside_filter
		mask_clip_data:                   command.mask_clip_data
		fixed_to_viewport:                command.fixed_to_viewport
		scrollbar_axis:                   command.scrollbar_axis
		scrollbar_thumb_travel_ratio:     command.scrollbar_thumb_travel_ratio
		scrollbar_recorded_scroll_offset: command.scrollbar_recorded_scroll_offset
		paint_box_index:                  command.paint_box_index
		paint_phase:                      command.paint_phase
	}
}

fn svg_payload_legacy_append_painting_display_command(mut commands []LegacySVGPathPaintCommand,
	display_command painting.DisplayListCommand, opacity f64) {
	match display_command {
		painting.DrawRect {
			commands << LegacySVGPathPaintCommand{
				kind:         'stroke_rounded_rect'
				x:            display_command.rect.x
				y:            display_command.rect.y
				width:        display_command.rect.width
				height:       display_command.rect.height
				color:        painting_color_string(display_command.color)
				opacity:      opacity
				stroke_width: 1
			}
		}
		painting.FillRect {
			commands << LegacySVGPathPaintCommand{
				kind:    'fill_rect'
				x:       display_command.rect.x
				y:       display_command.rect.y
				width:   display_command.rect.width
				height:  display_command.rect.height
				color:   painting_color_string(display_command.color)
				opacity: opacity
			}
		}
		painting.FillRoundedRect {
			commands << LegacySVGPathPaintCommand{
				kind:         'fill_rounded_rect'
				x:            display_command.rect.x
				y:            display_command.rect.y
				width:        display_command.rect.width
				height:       display_command.rect.height
				color:        painting_color_string(display_command.color)
				opacity:      opacity
				corner_radii: transport_radii_from_painting(display_command.corner_radii)
			}
		}
		painting.FillPath {
			polygons := flattened_painting_path(display_command.path)
			commands << LegacySVGPathPaintCommand{
				kind:          'draw_svg_path'
				x:             display_command.path_bounding_rect.x
				y:             display_command.path_bounding_rect.y
				width:         display_command.path_bounding_rect.width
				height:        display_command.path_bounding_rect.height
				color:         painting_color_string(display_command.color)
				opacity:       opacity * display_command.opacity
				path:          painting_path_svg(display_command.path)
				path_data:     compatibility_pack_clip_path_segments(display_command.path)
				points:        if polygons.len > 0 { polygons[0] } else { []f64{} }
				path_polygons: polygons
				fill_even_odd: display_command.winding_rule == .even_odd
			}
		}
		painting.DrawEllipse {
			commands << LegacySVGPathPaintCommand{
				kind:         'stroke_ellipse'
				x:            display_command.rect.x
				y:            display_command.rect.y
				width:        display_command.rect.width
				height:       display_command.rect.height
				color:        painting_color_string(display_command.color)
				opacity:      opacity
				stroke_width: display_command.thickness
			}
		}
		painting.FillEllipse {
			commands << LegacySVGPathPaintCommand{
				kind:    'fill_ellipse'
				x:       display_command.rect.x
				y:       display_command.rect.y
				width:   display_command.rect.width
				height:  display_command.rect.height
				color:   painting_color_string(display_command.color)
				opacity: opacity
			}
		}
		painting.DrawLine {
			commands << LegacySVGPathPaintCommand{
				kind:         'draw_line'
				x:            display_command.from.x
				y:            display_command.from.y
				width:        display_command.to.x - display_command.from.x
				height:       display_command.to.y - display_command.from.y
				color:        painting_color_string(display_command.color)
				opacity:      opacity
				points:       [f64(display_command.from.x), f64(display_command.from.y),
					f64(display_command.to.x), f64(display_command.to.y)]
				stroke_width: display_command.thickness
				line_style:   painting_line_style_string(display_command.line_style)
			}
		}
		painting.ApplyBackdropFilter {
			commands << LegacySVGPathPaintCommand{
				kind:                 'apply_backdrop_filter'
				x:                    display_command.backdrop_region.x
				y:                    display_command.backdrop_region.y
				width:                display_command.backdrop_region.width
				height:               display_command.backdrop_region.height
				corner_radii:         transport_radii_from_painting(display_command.corner_radii)
				backdrop_filter_data: retained_paint_backdrop_filter(display_command.filter)
				opacity:              opacity
			}
		}
		else {}
	}
}

fn svg_payload_legacy_append_text_decoration_draw_line(mut commands []LegacySVGPathPaintCommand, from painting.IntPoint, to painting.IntPoint, color string, thickness int, style string, opacity f64) {
	commands << LegacySVGPathPaintCommand{
		kind:         'draw_line'
		x:            from.x
		y:            from.y
		width:        to.x - from.x
		height:       to.y - from.y
		color:        color
		opacity:      opacity
		points:       [f64(from.x), f64(from.y), f64(to.x), f64(to.y)]
		stroke_width: thickness
		line_style:   style
	}
}

fn svg_payload_legacy_append_text_decoration_style(mut commands []LegacySVGPathPaintCommand, line string, start painting.IntPoint, end painting.IntPoint, color string, thickness int, style string, opacity f64) {
	mut line_start := start
	mut line_end := end
	match style {
		'double' {
			// Two parallel lines with a 1px gap, expanding away from the text.
			step := thickness + 1
			match line {
				'line-through' {
					line_start = painting.IntPoint{line_start.x, line_start.y - step / 2}
					line_end = painting.IntPoint{line_end.x, line_end.y - step / 2}
				}
				else {}
			}

			svg_payload_legacy_append_text_decoration_draw_line(mut commands, line_start, line_end,
				color, thickness, 'solid', opacity)
			second_y := if line == 'overline' { line_start.y - step } else { line_start.y + step }
			svg_payload_legacy_append_text_decoration_draw_line(mut commands, painting.IntPoint{line_start.x, second_y}, painting.IntPoint{line_end.x, second_y},
				color, thickness, 'solid', opacity)
		}
		'wavy' {
			// The wave oscillates around its center. Move that center away from the text so its near
			// peaks do not overlap the glyphs.
			wave_offset := thickness / 2 + 1
			match line {
				'underline' {
					line_start = painting.IntPoint{line_start.x, line_start.y + wave_offset}
					line_end = painting.IntPoint{line_end.x, line_end.y + wave_offset}
				}
				'overline' {
					line_start = painting.IntPoint{line_start.x, line_start.y - wave_offset}
					line_end = painting.IntPoint{line_end.x, line_end.y - wave_offset}
				}
				else {}
			}

			path := build_triangle_wave_path(line_start, line_end, f64(thickness * 3))
			if path.segments.len == 0 {
				return
			}
			mut flat_points := []f64{}
			for point in path.polygon {
				flat_points << point.x
				flat_points << point.y
			}
			commands << LegacySVGPathPaintCommand{
				kind:              'draw_svg_path'
				x:                 math.min(f64(line_start.x), f64(line_end.x))
				y:                 math.min(f64(line_start.y), f64(line_end.y)) - f64(thickness * 3)
				width:             math.abs(f64(line_end.x - line_start.x))
				height:            f64(thickness * 6)
				opacity:           opacity
				path:              painting_path_svg(path)
				path_data:         compatibility_pack_clip_path_segments(path)
				points:            flat_points
				path_polygons:     [flat_points.clone()]
				stroke_color:      color
				stroke_width:      thickness
				stroke_linecap:    1
				stroke_linejoin:   1
				stroke_miterlimit: 0
			}
		}
		else {
			svg_payload_legacy_append_text_decoration_draw_line(mut commands, line_start, line_end,
				color, thickness, style, opacity)
		}
	}
}

fn svg_payload_legacy_typed(box &BlockBox, opacity f64) LegacySVGPathPaintCommand {
	data := box.svg_path()
	return LegacySVGPathPaintCommand{
		kind:                 'draw_svg_path'
		x:                    box.x
		y:                    box.y
		width:                box.width
		height:               box.height
		color:                box.svg_data.fill_color
		svg_solid_color_data: data.svg_solid_color_data
		force_dark_role:      .svg
		force_dark_role_set:  true
		svg_gradient_data:    if gradients := data.svg_gradient_data {
			if gradients.fill_linear_gradient != none || gradients.stroke_linear_gradient != none
				|| gradients.fill_radial_gradient != none || gradients.stroke_radial_gradient != none {
				gradients
			} else {
				none
			}
		} else {
			none
		}
		fill_pattern:         data.fill_pattern
		opacity:              opacity
		path:                 data.path
		path_data:            data.path_data
		path_transform:       data.path_transform
		points:               box.svg_data.points
		fill_even_odd:        data.fill_even_odd
		stroke_color:         box.svg_data.stroke_color
		stroke_pattern:       data.stroke_pattern
		stroke_width:         box.svg_data.stroke_width
		stroke_dasharray:     data.stroke_dasharray
		stroke_dashoffset:    data.stroke_dashoffset
		non_scaling_stroke:   data.non_scaling_stroke
		stroke_first:         data.stroke_first
		stroke_linecap:       data.stroke_linecap
		stroke_linejoin:      data.stroke_linejoin
		stroke_miterlimit:    data.stroke_miterlimit
		fill_opacity:         data.fill_opacity
		stroke_opacity:       data.stroke_opacity
	}
}

fn svg_payload_legacy_force_dark_effective_role(command LegacySVGPathPaintCommand) painting.ForceDarkRole {
	if command.force_dark_role_set {
		return command.force_dark_role
	}
	return match command.paint_phase {
		.background { .background }
		.border, .table_collapsed_border, .outline { .border }
		.foreground { .foreground }
		.overlay { .none_ }
	}
}

fn svg_payload_legacy_resolve_force_dark_paint_command(mut command LegacySVGPathPaintCommand,
	mut resolver painting.ForceDarkResolver) {
	role := svg_payload_legacy_force_dark_effective_role(command)
	if command.kind in ['draw_background_image', 'draw_replaced_image', 'draw_svg_image'] {
		command.apply_force_dark_to_image = role != .none_
	}
	if role == .none_ {
		return
	}
	command.color = force_dark_resolved_color_string(command.color, role,
		command.force_dark_backdrop, mut resolver)
	command.stroke_color = force_dark_resolved_color_string(command.stroke_color, role,
		command.force_dark_backdrop, mut resolver)
	if gradient := command.gradient {
		resolved := force_dark_resolved_css_gradient(gradient, role, mut resolver)
		command.gradient = &LinearGradient{
			...resolved
		}
	}
	if data := command.svg_gradient_data {
		mut fill_linear := data.fill_linear_gradient
		mut stroke_linear := data.stroke_linear_gradient
		mut fill_radial := data.fill_radial_gradient
		mut stroke_radial := data.stroke_radial_gradient
		if gradient := fill_linear {
			fill_linear = force_dark_resolved_svg_linear_gradient(gradient, role, mut resolver)
		}
		if gradient := stroke_linear {
			stroke_linear = force_dark_resolved_svg_linear_gradient(gradient, role, mut resolver)
		}
		if gradient := fill_radial {
			fill_radial = force_dark_resolved_svg_radial_gradient(gradient, role, mut resolver)
		}
		if gradient := stroke_radial {
			stroke_radial = force_dark_resolved_svg_radial_gradient(gradient, role, mut resolver)
		}
		// Other commands and earlier recordings can share the author snapshot.
		// Publish replacement colors without modifying that snapshot or its stops.
		command.svg_gradient_data = &PaintSVGGradientData{
			fill_linear_gradient:   fill_linear
			stroke_linear_gradient: stroke_linear
			fill_radial_gradient:   fill_radial
			stroke_radial_gradient: stroke_radial
		}
	}
}

pub fn (command &LegacySVGPathPaintCommand) box_shadow() PaintBoxShadowData {
	if command.box_shadow_data != unsafe { nil } {
		return *command.box_shadow_data
	}
	return PaintBoxShadowData{}
}

pub fn (command &LegacySVGPathPaintCommand) image() PaintImageData {
	if command.image_data != unsafe { nil } {
		return *command.image_data
	}
	return PaintImageData{}
}

pub fn svg_payload_legacy_gradient_tiles(command LegacySVGPathPaintCommand) []painting.Rect {
	if !command.gradient_background_layer {
		return [painting.Rect{command.x, command.y, command.width, command.height}]
	}
	image_data := command.image()
	background_data := image_data.background_layer_data or { return []painting.Rect{} }
	resolved := painting.resolve_background_layer_without_intrinsic(painting.BackgroundLayerWithoutIntrinsicResolutionInput{
		layer:                       background_data.layer
		image_id:                    'gradient'
		background_positioning_area: painting.Rect{command.x, command.y, command.width, command.height}
		resolution_context:          background_data.resolution_context
	}) or { return []painting.Rect{} }
	return painting.background_tiles_limited(resolved, painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, painting.Rect{image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height},
		4096)
}

pub fn (command &LegacySVGPathPaintCommand) fill_linear_gradient() ?painting.SVGLinearGradientPaintStyle {
	data := command.svg_gradient_data or { return none }
	return data.fill_linear_gradient
}

pub fn (command &LegacySVGPathPaintCommand) stroke_linear_gradient() ?painting.SVGLinearGradientPaintStyle {
	data := command.svg_gradient_data or { return none }
	return data.stroke_linear_gradient
}

pub fn (command &LegacySVGPathPaintCommand) fill_radial_gradient() ?painting.SVGRadialGradientPaintStyle {
	data := command.svg_gradient_data or { return none }
	return data.fill_radial_gradient
}

pub fn (command &LegacySVGPathPaintCommand) stroke_radial_gradient() ?painting.SVGRadialGradientPaintStyle {
	data := command.svg_gradient_data or { return none }
	return data.stroke_radial_gradient
}

pub fn (b &BlockBox) svg_payload_legacy_render_svg(width f64, height f64) string {
	mut defs := []string{}
	mut body := []string{}
	for command in b.paint_commands().map(svg_payload_legacy(it)) {
		if command.kind == 'begin_background_text_clip' {
			id := 'background-text-mask${defs.len}'
			mut glyphs := ''
			for run in command.text_clip_runs {
				half_leading := (run.height - run.font_size) / 2.0
				baseline := run.y + half_leading + run.font_size * 0.8
				weight := if run.bold { ' font-weight="bold"' } else { '' }
				style := if run.italic { ' font-style="italic"' } else { '' }
				family := if run.mono { ' font-family="monospace"' } else { '' }
				text_x := if run.rtl { run.x + run.width } else { run.x }
				direction := if run.rtl { ' direction="rtl" unicode-bidi="plaintext"' } else { '' }
				glyphs += '<text x="${fmt_px(text_x)}" y="${fmt_px(baseline)}" font-size="${fmt_px(run.font_size)}" textLength="${fmt_px(run.width)}" lengthAdjust="spacingAndGlyphs"${direction}${weight}${style}${family} fill="white">${escape_xml(run.text)}</text>'
			}
			defs << '<mask id="${id}" maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse" x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}" style="mask-type:alpha">${glyphs}</mask>'
			body << '<g mask="url(#${id})">'
			continue
		}
		if command.kind == 'end_background_text_clip' {
			body << '</g>'
			continue
		}
		if command.kind == 'begin_background_blend_group' {
			body << '<g style="isolation:isolate">'
			continue
		}
		if command.kind == 'end_background_blend_group' {
			body << '</g>'
			continue
		}
		body_start := body.len
		if command.kind == 'fill_rect' {
			corner := if command.radius > 0 {
				' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"'
			} else {
				''
			}
			mut filter := ''
			if command.blur > 0 {
				id := 'blur${defs.len}'
				// The blur can bleed past the rect, so give the filter region generous margins.
				defs << '<filter id="${id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${fmt_px(command.blur / 2.0)}"/></filter>'
				filter = ' filter="url(#${id})"'
			}
			body << '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'fill_rounded_rect' {
			path := rounded_rect_svg_path(command.x, command.y, command.width, command.height,
				command.corner_radii)
			body << '<path d="${path}" fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'paint_outer_box_shadow' {
			geometry := command.box_shadow()
			margin := command.blur * 2.0
			left := math.min(command.x, geometry.content_rect.x) - margin
			top := math.min(command.y, geometry.content_rect.y) - margin
			right := math.max(command.x + command.width, geometry.content_rect.x +
				geometry.content_rect.width) + margin
			bottom := math.max(command.y + command.height, geometry.content_rect.y +
				geometry.content_rect.height) + margin
			clip_id := 'outer-shadow-clip${defs.len}'
			outside_path := rounded_rect_svg_path(left, top, right - left, bottom - top, BoxRadii{})
			content_path := rounded_rect_svg_path(geometry.content_rect.x, geometry.content_rect.y,
				geometry.content_rect.width, geometry.content_rect.height, geometry.content_radii)
			defs << '<clipPath id="${clip_id}" clipPathUnits="userSpaceOnUse"><path d="${outside_path} ${content_path}" clip-rule="evenodd"/></clipPath>'
			mut filter := ''
			if command.blur > 0 {
				filter_id := 'outer-shadow-blur${defs.len}'
				defs << '<filter id="${filter_id}" filterUnits="userSpaceOnUse" x="${fmt_px(left)}" y="${fmt_px(top)}" width="${fmt_px(right - left)}" height="${fmt_px(bottom - top)}"><feGaussianBlur stdDeviation="${fmt_px(f64(int(command.blur) / 2))}"/></filter>'
				filter = ' filter="url(#${filter_id})"'
			}
			shadow_path := rounded_rect_svg_path(command.x, command.y, command.width,
				command.height, command.corner_radii)
			body << '<path d="${shadow_path}" clip-path="url(#${clip_id})"${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'paint_inner_box_shadow' {
			geometry := command.box_shadow()
			content_path := rounded_rect_svg_path(geometry.content_rect.x, geometry.content_rect.y,
				geometry.content_rect.width, geometry.content_rect.height, geometry.content_radii)
			clip_path := rounded_rect_svg_path(geometry.content_rect.x, geometry.content_rect.y,
				geometry.content_rect.width, geometry.content_rect.height, geometry.clip_radii)
			content_clip_id := 'inner-shadow-content${defs.len}'
			defs << '<clipPath id="${content_clip_id}" clipPathUnits="userSpaceOnUse"><path d="${content_path}"/></clipPath>'
			scoped_clip_id := 'inner-shadow-scoped${defs.len}'
			defs << '<clipPath id="${scoped_clip_id}" clipPathUnits="userSpaceOnUse"><path d="${clip_path}"/></clipPath>'
			mut filter := ''
			if command.blur > 0 {
				filter_id := 'inner-shadow-blur${defs.len}'
				margin := command.blur * 2.0
				defs << '<filter id="${filter_id}" filterUnits="userSpaceOnUse" x="${fmt_px(geometry.content_rect.x - margin)}" y="${fmt_px(geometry.content_rect.y - margin)}" width="${fmt_px(geometry.content_rect.width + margin * 2.0)}" height="${fmt_px(geometry.content_rect.height + margin * 2.0)}"><feGaussianBlur stdDeviation="${fmt_px(f64(int(command.blur) / 2))}"/></filter>'
				filter = ' filter="url(#${filter_id})"'
			}
			outer_path := rounded_rect_svg_path(command.x, command.y, command.width,
				command.height, command.corner_radii)
			inner_path := if geometry.inner_rect.width > 0 && geometry.inner_rect.height > 0 {
				rounded_rect_svg_path(geometry.inner_rect.x, geometry.inner_rect.y,
					geometry.inner_rect.width, geometry.inner_rect.height, geometry.inner_radii)
			} else {
				''
			}
			body << '<g clip-path="url(#${scoped_clip_id})"><g clip-path="url(#${content_clip_id})"><path d="${outer_path} ${inner_path}" fill-rule="evenodd"${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/></g></g>'
		} else if command.kind == 'fill_inset_shadow' {
			clip_id := 'inset-clip${defs.len}'
			corner := if command.radius > 0 {
				' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"'
			} else {
				''
			}
			defs << '<clipPath id="${clip_id}"><rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}/></clipPath>'
			mut filter := ''
			if command.blur > 0 {
				filter_id := 'inset-blur${defs.len}'
				defs << '<filter id="${filter_id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${fmt_px(command.blur / 2.0)}"/></filter>'
				filter = ' filter="url(#${filter_id})"'
			}
			base := command.blur + command.shadow_spread
			left := non_negative(base - command.shadow_offset_x)
			right := non_negative(base + command.shadow_offset_x)
			top := non_negative(base - command.shadow_offset_y)
			bottom := non_negative(base + command.shadow_offset_y)
			mut pieces := ''
			if left > 0 {
				pieces += '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(left)}" height="${fmt_px(command.height)}"/>'
			}
			if right > 0 {
				pieces += '<rect x="${fmt_px(command.x + command.width - right)}" y="${fmt_px(command.y)}" width="${fmt_px(right)}" height="${fmt_px(command.height)}"/>'
			}
			if top > 0 {
				pieces += '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(top)}"/>'
			}
			if bottom > 0 {
				pieces += '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y + command.height -
					bottom)}" width="${fmt_px(command.width)}" height="${fmt_px(bottom)}"/>'
			}
			body << '<g clip-path="url(#${clip_id})"${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}">${pieces}</g>'
		} else if command.kind == 'stroke_rounded_rect' {
			if command.points.len > 0 {
				mut points := []string{}
				for index := 0; index + 1 < command.points.len; index += 2 {
					points << '${fmt_px(command.points[index])},${fmt_px(command.points[index + 1])}'
				}
				body << '<polygon points="${points.join(' ')}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"/>'
			} else {
				half_stroke := command.stroke_width / 2.0
				body << '<rect x="${fmt_px(command.x + half_stroke)}" y="${fmt_px(command.y +
					half_stroke)}" width="${fmt_px(non_negative(command.width - command.stroke_width))}" height="${fmt_px(non_negative(command.height - command.stroke_width))}" rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"/>'
			}
		} else if command.kind == 'fill_ellipse' {
			body << '<ellipse cx="${fmt_px(command.x + command.width / 2)}" cy="${fmt_px(command.y + command.height / 2)}" rx="${fmt_px(command.width / 2)}" ry="${fmt_px(command.height / 2)}" fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'stroke_ellipse' {
			body << '<ellipse cx="${fmt_px(command.x + command.width / 2)}" cy="${fmt_px(command.y + command.height / 2)}" rx="${fmt_px(command.width / 2)}" ry="${fmt_px(command.height / 2)}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"/>'
		} else if command.kind == 'fill_polygon' {
			mut points := []string{}
			for index := 0; index + 1 < command.points.len; index += 2 {
				points << '${fmt_px(command.points[index])},${fmt_px(command.points[index + 1])}'
			}
			body << '<polygon points="${points.join(' ')}" fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'draw_line' {
			linecap := if command.line_style == 'dotted' { ' stroke-linecap="round"' } else { '' }
			dasharray := match command.line_style {
				'dashed' {
					' stroke-dasharray="${fmt_px(command.stroke_width * 3)} ${fmt_px(command.stroke_width * 3)}"'
				}
				'dotted' {
					' stroke-dasharray="0 ${fmt_px(command.stroke_width * 2)}"'
				}
				else {
					''
				}
			}

			body << '<line x1="${fmt_px(command.x)}" y1="${fmt_px(command.y)}" x2="${fmt_px(command.x + command.width)}" y2="${fmt_px(command.y + command.height)}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"${linecap}${dasharray}/>'
		} else if command.kind == 'fill_gradient' {
			image_data := command.image()
			if grad := command.gradient {
				tiles := svg_payload_legacy_gradient_tiles(command)
				mut stops := ''
				resolved_stops := if grad.stops.len > 0 {
					grad.stops
				} else {
					mut fallback := []GradientStop{}
					for index, color in grad.colors {
						fallback << GradientStop{
							color:  color
							offset: if grad.colors.len > 1 {
								f64(index) / f64(grad.colors.len - 1)
							} else {
								0.0
							}
						}
					}
					fallback
				}
				for stop in css_gradient_svg_stops(grad, resolved_stops) {
					stops += '<stop offset="${fmt_px(stop.offset * 100.0)}%" stop-color="${stop.color.serialize()}" stop-opacity="${fmt_px(f64(stop.color.a) / 255.0)}"/>'
				}
				color_interpolation := css_gradient_svg_color_interpolation(grad)
				corner := if command.radius > 0 && !command.gradient_background_layer {
					' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"'
				} else {
					''
				}
				mut rounded_polygon_points := []string{}
				for index := 0; index + 1 < command.points.len; index += 2 {
					rounded_polygon_points << '${fmt_px(command.points[index])},${fmt_px(command.points[index + 1])}'
				}
				clip_shape := if command.gradient_background_layer
					&& !box_radii_are_zero(image_data.image_clip_radii) {
					'<path d="${rounded_rect_svg_path(image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height, image_data.image_clip_radii)}"/>'
				} else if command.gradient_background_layer {
					'<rect x="${fmt_px(image_data.image_clip_x)}" y="${fmt_px(image_data.image_clip_y)}" width="${fmt_px(image_data.image_clip_width)}" height="${fmt_px(image_data.image_clip_height)}"/>'
				} else if rounded_polygon_points.len > 0 {
					'<polygon points="${rounded_polygon_points.join(' ')}"/>'
				} else {
					'<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}/>'
				}
				blend := if image_data.background_blend_mode == .normal {
					''
				} else {
					' style="mix-blend-mode:${background_blend_mode_css(image_data.background_blend_mode)}"'
				}
				if grad.kind == 'conic' {
					clip_id := 'gradient-clip${defs.len}'
					defs << '<clipPath id="${clip_id}">${clip_shape}</clipPath>'
					mut wedges := ''
					for tile in tiles {
						center_x := tile.x + tile.width * grad.center_x
						center_y := tile.y + tile.height * grad.center_y
						radius := math.sqrt(tile.width * tile.width + tile.height * tile.height)
						steps := 128
						for step in 0 .. steps {
							start_fraction := f64(step) / f64(steps)
							end_fraction := f64(step + 1) / f64(steps)
							start_angle := (grad.start_degrees + start_fraction * 360.0 - 90.0) * math.pi / 180.0
							end_angle := (grad.start_degrees + end_fraction * 360.0 - 90.0) * math.pi / 180.0
							start_x := center_x + math.cos(start_angle) * radius
							start_y := center_y + math.sin(start_angle) * radius
							end_x := center_x + math.cos(end_angle) * radius
							end_y := center_y + math.sin(end_angle) * radius
							color := gradient_color_at(grad, (start_fraction + end_fraction) / 2.0)
							wedges += '<polygon points="${fmt_px(center_x)},${fmt_px(center_y)} ${fmt_px(start_x)},${fmt_px(start_y)} ${fmt_px(end_x)},${fmt_px(end_y)}" fill="${color.serialize()}" fill-opacity="${fmt_px(command.opacity * f64(color.a) / 255.0)}"/>'
						}
					}
					body << '<g clip-path="url(#${clip_id})"${blend}>${wedges}</g>'
				} else {
					id := 'grad${defs.len}'
					if grad.kind == 'radial' || grad.radial {
						transform := if grad.radius_x != grad.radius_y && grad.radius_x > 0 {
							' gradientTransform="translate(${fmt_px(grad.center_x)} ${fmt_px(grad.center_y)}) scale(1 ${fmt_px(grad.radius_y / grad.radius_x)}) translate(${fmt_px(-grad.center_x)} ${fmt_px(-grad.center_y)})"'
						} else {
							''
						}
						defs << '<radialGradient id="${id}" cx="${fmt_px(grad.center_x * 100.0)}%" cy="${fmt_px(grad.center_y * 100.0)}%" r="${fmt_px(grad.radius_x * 100.0)}%"${transform}${color_interpolation}>${stops}</radialGradient>'
					} else {
						defs << '<linearGradient id="${id}" x1="${fmt_px(grad.x1 * 100.0)}%" y1="${fmt_px(grad.y1 * 100.0)}%" x2="${fmt_px(grad.x2 * 100.0)}%" y2="${fmt_px(grad.y2 * 100.0)}%"${color_interpolation}>${stops}</linearGradient>'
					}
					if command.gradient_background_layer {
						clip_id := 'gradient-clip${defs.len}'
						defs << '<clipPath id="${clip_id}">${clip_shape}</clipPath>'
						mut tile_rects := ''
						for tile in tiles {
							tile_rects += '<rect x="${fmt_px(tile.x)}" y="${fmt_px(tile.y)}" width="${fmt_px(tile.width)}" height="${fmt_px(tile.height)}" fill="url(#${id})" fill-opacity="${fmt_px(command.opacity)}"/>'
						}
						body << '<g clip-path="url(#${clip_id})"${blend}>${tile_rects}</g>'
					} else if rounded_polygon_points.len > 0 {
						body << '<polygon points="${rounded_polygon_points.join(' ')}" fill="url(#${id})" fill-opacity="${fmt_px(command.opacity)}"/>'
					} else {
						body << '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner} fill="url(#${id})" fill-opacity="${fmt_px(command.opacity)}"/>'
					}
				}
			}
		} else if command.kind in ['draw_background_image', 'draw_replaced_image'] {
			image_data := command.image()
			clip_id := 'imageclip${defs.len}'
			clip_shape := if !box_radii_are_zero(image_data.image_clip_radii) {
				'<path d="${rounded_rect_svg_path(image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height, image_data.image_clip_radii)}"/>'
			} else {
				'<rect x="${fmt_px(image_data.image_clip_x)}" y="${fmt_px(image_data.image_clip_y)}" width="${fmt_px(image_data.image_clip_width)}" height="${fmt_px(image_data.image_clip_height)}"/>'
			}
			defs << '<clipPath id="${clip_id}">${clip_shape}</clipPath>'
			aspect := if image_data.image_size.trim_space().to_lower() == 'cover' {
				'xMidYMid slice'
			} else if image_data.image_size.trim_space().to_lower() == 'contain' {
				'xMidYMid meet'
			} else {
				'xMinYMin meet'
			}
			blend := if image_data.background_blend_mode == .normal {
				''
			} else {
				' style="mix-blend-mode:${background_blend_mode_css(image_data.background_blend_mode)}"'
			}
			body << '<image href="${escape_xml(image_data.image_url)}" x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}" preserveAspectRatio="${aspect}" clip-path="url(#${clip_id})" opacity="${fmt_px(command.opacity)}"${blend} data-background-repeat="${escape_xml(image_data.image_repeat_x)} ${escape_xml(image_data.image_repeat_y)}" data-background-position="${escape_xml(image_data.image_position_x)} ${escape_xml(image_data.image_position_y)}"/>'
		} else if command.kind == 'draw_text' {
			half_leading := (command.height - command.font_size) / 2.0
			baseline := command.y + half_leading + command.font_size * 0.8
			weight := if command.bold { ' font-weight="bold"' } else { '' }
			style := if command.italic { ' font-style="italic"' } else { '' }
			family := if command.mono { ' font-family="monospace"' } else { '' }
			text_x := if command.rtl { command.x + command.width } else { command.x }
			direction := if command.rtl { ' direction="rtl" unicode-bidi="plaintext"' } else { '' }
			body << '<text x="${fmt_px(text_x)}" y="${fmt_px(baseline)}" font-size="${fmt_px(command.font_size)}" textLength="${fmt_px(command.width)}" lengthAdjust="spacingAndGlyphs"${direction}${weight}${style}${family} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}">${escape_xml(command.text)}</text>'
		} else if command.kind == 'draw_svg_path' {
			path_matrix := normalized_affine(command.path_transform)
			mut fill := if command.color.len > 0 { command.color } else { 'none' }
			mut stroke := if command.stroke_color.len > 0 { command.stroke_color } else { 'none' }
			if gradient := command.fill_linear_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_linear_gradient_definition(id, gradient)
				fill = 'url(#${id})'
			} else if gradient := command.fill_radial_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_radial_gradient_definition(id, gradient)
				fill = 'url(#${id})'
			} else if pattern := command.fill_pattern {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_pattern_definition(id, pattern, 0)
				fill = 'url(#${id})'
			}
			if gradient := command.stroke_linear_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_linear_gradient_definition(id, gradient)
				stroke = 'url(#${id})'
			} else if gradient := command.stroke_radial_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_radial_gradient_definition(id, gradient)
				stroke = 'url(#${id})'
			} else if pattern := command.stroke_pattern {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_pattern_definition(id, pattern, 0)
				stroke = 'url(#${id})'
			}
			fill_rule := if command.fill_even_odd { 'evenodd' } else { 'nonzero' }
			paint_order := if command.stroke_first { ' paint-order="stroke fill"' } else { '' }
			linecap := match command.stroke_linecap {
				1 { 'round' }
				2 { 'square' }
				else { 'butt' }
			}

			linejoin := match command.stroke_linejoin {
				1 { 'round' }
				2 { 'bevel' }
				else { 'miter' }
			}

			vector_effect := if command.non_scaling_stroke {
				' vector-effect="non-scaling-stroke"'
			} else {
				''
			}
			dasharray := if command.stroke_dasharray.len > 0 {
				' stroke-dasharray="${command.stroke_dasharray.map(fmt_px(it)).join(' ')}" stroke-dashoffset="${fmt_px(command.stroke_dashoffset)}"'
			} else {
				''
			}
			body << '<path d="${escape_xml(command.path)}" transform="matrix(${fmt_px(path_matrix[0])} ${fmt_px(path_matrix[1])} ${fmt_px(path_matrix[2])} ${fmt_px(path_matrix[3])} ${fmt_px(path_matrix[4])} ${fmt_px(path_matrix[5])})" fill="${fill}" fill-rule="${fill_rule}" fill-opacity="${fmt_px(command.opacity * command.fill_opacity)}" stroke="${stroke}" stroke-opacity="${fmt_px(command.opacity * command.stroke_opacity)}" stroke-width="${fmt_px(command.stroke_width)}" stroke-linecap="${linecap}" stroke-linejoin="${linejoin}" stroke-miterlimit="${fmt_px(command.stroke_miterlimit)}"${dasharray}${paint_order}${vector_effect}/>'
		}
		if body.len > body_start && !affine_is_identity(command.transform) {
			matrix := normalized_affine(command.transform)
			transformed_body := body[body_start..].join('')
			body = body[..body_start].clone()
			body << '<g transform="matrix(${fmt_px(matrix[0])} ${fmt_px(matrix[1])} ${fmt_px(matrix[2])} ${fmt_px(matrix[3])} ${fmt_px(matrix[4])} ${fmt_px(matrix[5])})">${transformed_body}</g>'
		}
	}
	mut parts := [
		'<svg xmlns="http://www.w3.org/2000/svg" width="${fmt_px(width)}" height="${fmt_px(height)}">',
	]
	if defs.len > 0 {
		parts << '<defs>${defs.join('')}</defs>'
	}
	parts << body
	parts << '</svg>'
	return parts.join('\n')
}

// Compare all original logical fields; force-dark independently allocates its
// gradient snapshot, so verify each gradient value and test identity separately.
fn svg_payload_assert_original_fields(actual LegacySVGPathPaintCommand, expected LegacySVGPathPaintCommand) {
	assert retained_paint_payload_equal(actual, expected)
}

fn test_svg_payload_reduces_actual_command_width_and_keeps_nil_defaults() {
	// V compiler versions use different option and enum representations.
	// Require the payload split to save at least 256 bytes in either layout.
	assert sizeof(LegacySVGPathPaintCommand) >= sizeof(PaintCommand) + 256
	// Includes the independently added shared sRGB color payload pointer.
	assert sizeof(PaintCommand) <= 1328
	assert sizeof(PaintSVGPathData) <= 352
	println('svg-payload-size old=${sizeof(LegacySVGPathPaintCommand)} new=${sizeof(PaintCommand)} payload=${sizeof(PaintSVGPathData)}')
	for kind in ['draw_text', 'fill_rect', 'draw_line', 'draw_svg_path', 'fill_gradient'] {
		command := PaintCommand{
			kind: kind
		}
		assert command.svg_data == unsafe { nil }
		assert retained_paint_payload_equal(svg_payload_legacy(command), LegacySVGPathPaintCommand{ kind: kind })
	}
}

fn svg_payload_returned_command() PaintCommand {
	path := build_triangle_wave_path(painting.IntPoint{3, 5}, painting.IntPoint{103, 5}, 6)
	assert path.segments.len > 0
	return BlockBox{
		width:    100
		height:   50
		svg_data: &BlockBoxSVGData{
			points:       [
				f64(3),
				5,
				103,
				25,
			]
			stroke_color: 'blue'
			fill_color:   'red'
			stroke_width: 3
			path:         &PaintSVGPathData{
				path:               painting_path_svg(path)
				path_data:          compatibility_pack_clip_path_segments(path)
				stroke_dasharray:   [f64(3), 4]
				stroke_dashoffset:  2
				non_scaling_stroke: true
				stroke_first:       true
				stroke_linecap:     1
				stroke_linejoin:    2
				stroke_miterlimit:  7
				fill_opacity:       0.4
				stroke_opacity:     0.6
			}
		}
	}.paint_commands().filter(it.kind == 'draw_svg_path')[0]
}

fn test_svg_payload_typed_producer_matches_all_original_fields() {
	for empty_gradients in [false, true] {
		path := build_triangle_wave_path(painting.IntPoint{3, 5}, painting.IntPoint{103, 5}, 6)
		assert path.segments.len > 0
		gradient_data := if empty_gradients {
			&PaintSVGGradientData{}
		} else {
			&PaintSVGGradientData{
				fill_linear_gradient: painting.SVGLinearGradientPaintStyle{
					gradient:  painting.SVGGradientPaintStyle{
						color_stops: [
							painting.ColorStop{
								color:    painting.Color{1, 2, 3, 255}
								position: 0.5
							},
						]
					}
					end_point: painting.Point{100, 50}
				}
			}
		}
		box := BlockBox{
			x:        3
			y:        5
			width:    100
			height:   50
			svg_data: &BlockBoxSVGData{
				points:       [
					f64(3),
					5,
					103,
					25,
				]
				fill_color:   'red'
				stroke_color: 'blue'
				stroke_width: 3
				path:         &PaintSVGPathData{
					path:               painting_path_svg(path)
					path_data:          compatibility_pack_clip_path_segments(path)
					path_transform:     [f64(2), 0, 0, 3, 7, 11]!
					stroke_dasharray:   [
						f64(3),
						4,
					]
					stroke_dashoffset:  2
					stroke_first:       true
					non_scaling_stroke: true
					fill_even_odd:      true
					stroke_linecap:     1
					stroke_linejoin:    2
					stroke_miterlimit:  7
					fill_opacity:       0.4
					stroke_opacity:     0.6
					svg_gradient_data:  gradient_data
				}
			}
		}
		commands := box.paint_commands().filter(it.kind == 'draw_svg_path')
		assert commands.len == 1
		command := commands[0]
		// Exact original outer dispatcher annotations (old paint_transport.v).
		mut expected := svg_payload_legacy_typed(&box, 1)
		expected.transform = box.paint_transform
		expected.paint_box_index = 0
		expected.force_dark_backdrop =
			painting.Color{box.background_color.r, box.background_color.g, box.background_color.b, box.background_color.a}
		expected.paint_phase = .foreground
		svg_payload_assert_original_fields(svg_payload_legacy(command), expected)
	}
}

fn test_svg_payload_generic_path_producer_matches_original_display_commands() {
	path := build_triangle_wave_path(painting.IntPoint{3, 5}, painting.IntPoint{103, 5}, 6)
	assert path.segments.len > 0
	for rule in [painting.WindingRule.nonzero, .even_odd] {
		input := painting.FillPath{
			path:               path
			path_bounding_rect: painting.IntRect{3, 5, 100, 20}
			color:              painting.Color{1, 2, 3, 255}
			opacity:            0.7
			winding_rule:       rule
		}
		mut actual := []PaintCommand{}
		mut expected := []LegacySVGPathPaintCommand{}
		append_painting_display_command(mut actual, input, 0.8)
		svg_payload_legacy_append_painting_display_command(mut expected, input, 0.8)
		assert retained_paint_payload_equal(actual.map(svg_payload_legacy(it)), expected)
	}
}

fn test_svg_payload_wavy_and_other_text_decoration_producers_match_original() {
	for style in ['wavy', 'solid', 'dotted', 'double'] {
		for line in ['underline', 'overline', 'line-through'] {
			mut actual := []PaintCommand{}
			mut expected := []LegacySVGPathPaintCommand{}
			append_text_decoration_style(mut actual, line, painting.IntPoint{3, 5}, painting.IntPoint{103, 5},
				'red', 3, style, 0.6)
			svg_payload_legacy_append_text_decoration_style(mut expected, line, painting.IntPoint{3, 5}, painting.IntPoint{103, 5},
				'red', 3, style, 0.6)
			assert retained_paint_payload_equal(actual.map(svg_payload_legacy(it)), expected)
		}
	}
}

fn test_svg_payload_outlives_producer_collection_and_other_results() {
	first := svg_payload_returned_command()
	second := svg_payload_returned_command()
	assert voidptr(first.svg_data) != voidptr(second.svg_data)
	saved := svg_payload_legacy(first)
	for _ in 0 .. 3 {
		_ = svg_payload_returned_command()
		$if gcboehm ? {
			C.GC_gcollect()
		}
		assert retained_paint_payload_equal(svg_payload_legacy(first), saved)
	}
	second_data := second.svg()
	changed := PaintCommand{
		...second
		svg_data: &PaintSVGPathData{
			...second_data
			path_transform:   second_data.path_transform
			path:             'M0 0L1 1'
			stroke_dasharray: [f64(9)]
		}
	}
	assert first.svg().path == second.svg().path
	assert first.svg().stroke_dasharray == [f64(3), 4]
	assert changed.svg().stroke_dasharray == [f64(9)]
	assert changed.svg().path != first.svg().path
}

fn test_svg_payload_nested_and_scroll_replay_share_source_geometry() {
	first := svg_payload_returned_command()
	nested :=
		paint_command_for_nested_viewport(first, [f64(2), 0, 0, 3, 11, 13]!, painting.IntPoint{5, 7}, 0.5)
	assert voidptr(first.svg_data) == voidptr(nested.svg_data)
	assert retained_paint_payload_equal(first.svg(), nested.svg())
	assert nested.transform == [f64(2), 0, 0, 3, 21, 34]!
	assert first.transform == [6]f64{}
	mut replay := nested
	box := BlockBox{
		overlay: &CompatibilityOverlayData{
			scroll_offset_x: 17
			scroll_offset_y: 29
		}
	}
	apply_live_background_offsets(mut replay, &box)
	assert retained_paint_payload_equal(replay.svg(), first.svg())
	assert replay.image_scroll_offset_x == nested.image_scroll_offset_x
}

fn test_svg_payload_force_dark_matches_original_and_preserves_shared_gradients() {
	mut source := svg_payload_returned_command()
	source_data := source.svg()
	source.svg_data = &PaintSVGPathData{
		...source_data
		path_transform:    source_data.path_transform
		svg_gradient_data: &PaintSVGGradientData{
			fill_linear_gradient: painting.SVGLinearGradientPaintStyle{
				gradient:  painting.SVGGradientPaintStyle{
					color_stops: [
						painting.ColorStop{
							color:    painting.Color{0, 0, 0, 255}
							position: 0.5
						},
					]
				}
				end_point: painting.Point{100, 50}
			}
		}
	}
	source.force_dark_role = .svg
	source.force_dark_role_set = true
	original := svg_payload_legacy(source)
	settings := painting.ForceDarkSettings.default()
	mut expected := original
	mut resolver := painting.ForceDarkResolver.create(settings)
	svg_payload_legacy_resolve_force_dark_paint_command(mut expected, mut resolver)
	actual := resolve_force_dark_paint_commands([source, source], settings)
	svg_payload_assert_original_fields(svg_payload_legacy(actual[0]), expected)
	svg_payload_assert_original_fields(svg_payload_legacy(actual[1]), expected)
	assert voidptr(actual[0].svg_data) != voidptr(source.svg_data)
	assert voidptr(actual[0].svg_data) != voidptr(actual[1].svg_data)
	assert retained_paint_payload_equal(svg_payload_legacy(source), original)
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert retained_paint_payload_equal(svg_payload_legacy(source), original)
}

fn test_svg_payload_cache_source_replacement_and_collection_preserve_old_recordings() {
	mut document :=
		html.parse_document('<!doctype html><svg width="120" height="80"><path id="p" d="M0 0L100 0L100 50Z" fill="red" stroke="blue" stroke-dasharray="3 4"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 120)
	first_list := document.record_display_list() or { panic('first') }
	first_scene := retain_display_list_scene(first_list)
	defer { release_display_list_scene(first_scene) }
	first := display_list_commands(first_list).filter(it.kind == 'draw_svg_path')[0]
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := display_list_commands(document.record_display_list() or { panic('second') }).filter(it.kind == 'draw_svg_path')[0]
	assert voidptr(first.svg_data) == voidptr(second.svg_data)
	saved := svg_payload_legacy(first)
	// The exact old/full baseline retains its original d after direct attribute
	// mutation even with a typed-layout rebuild. Exercise supported parsed source
	// replacement here; native bridge mutation cases run in the focused matrix.
	mut replacement :=
		html.parse_document('<!doctype html><svg width="120" height="80"><path id="p" d="M0 0L50 0L100 50Z" fill="red" stroke="blue" stroke-dasharray="7 8"/></svg>')
	defer { replacement.finalize() }
	_ = layout_document_typed_in_viewport(replacement, 200, 120)
	third := display_list_commands(replacement.record_display_list() or { panic('third') }).filter(it.kind == 'draw_svg_path')[0]
	assert voidptr(first.svg_data) != voidptr(third.svg_data)
	assert first.svg().path != third.svg().path
	assert first.svg().stroke_dasharray == [f64(3), 4]
	assert third.svg().stroke_dasharray == [f64(7), 8]
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert retained_paint_payload_equal(svg_payload_legacy(first), saved)
}

fn test_svg_payload_svg_export_matches_the_entire_original_player() {
	document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}div{width:80px;height:30px;border:double 6px blue;border-radius:7px;text-decoration:wavy underline}svg{display:block}</style><div>waves</div><svg width="120" height="80"><defs><linearGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs><path d="M0 0C0 30 50 60 100 50Z" fill="url(#g)" stroke="green" stroke-width="3" stroke-dasharray="3 4" stroke-linejoin="bevel" fill-rule="evenodd" paint-order="stroke fill"/></svg>')
	root := layout_document_typed_in_viewport(document, 240, 200)
	assert root.render_svg(240, 200) == root.svg_payload_legacy_render_svg(240, 200)
}
