module layout

import painting

// Export the static shape-only subset into the caller's allocation owner. No
// source display-list, document, font, image or native-resource lease survives
// this copy. The caller must keep that owner alive while reading the result,
// and may discard it on rejection. Source eligibility (including animations
// and CSS) must be checked separately: a recording is only one point in time.
fn own_static_svg_commands(commands []PaintCommand) ?[]PaintCommand {
	mut result := []PaintCommand{cap: commands.len}
	mut layers := []PaintVisualLayerKind{}
	mut scopes := []u64{}
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		match command.kind {
			'fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect', 'fill_ellipse',
			'stroke_ellipse', 'fill_polygon', 'draw_line', 'draw_svg_path' {
			}
			'begin_css_effect_layer', 'begin_svg_mask_layer' {
				layer := command.visual_layer_data or { return none }
				expected := if command.kind == 'begin_css_effect_layer' {
					PaintVisualLayerKind.css_effect
				} else {
					PaintVisualLayerKind.svg_mask
				}
				if layer.kind != expected { return none }
				layers << layer.kind
				scopes << layer.scope_id
			}
			'end_css_effect_layer', 'end_svg_mask_layer' {
				layer := command.visual_layer_data or { return none }
				expected := if command.kind == 'end_css_effect_layer' {
					PaintVisualLayerKind.css_effect
				} else {
					PaintVisualLayerKind.svg_mask
				}
				if layers.len == 0 || layer.kind != expected || layers.last() != expected
					|| scopes.last() != layer.scope_id {
					return none
				}
				layers.delete_last()
				scopes.delete_last()
			}
			else { return none }
		}
		result << own_static_svg_command(command)?
	}
	if layers.len != 0 { return none }
	return result
}

fn own_static_svg_command(command &PaintCommand) ?PaintCommand {
	// Reject every unsupported reference payload even when its command kind
	// would not normally consume it. This boundary must never copy a hidden
	// child-document pointer through an otherwise supported shape command.
	if command.text != '' || command.glyph_run != none
		|| command.box_shadow_data != unsafe { nil } || command.gradient != none
		|| command.image_data != unsafe { nil } || command.image_paintable != none
		|| command.replaced_image_bitmap != none || command.canvas_bitmap != none
		|| command.canvas_paintable != none || command.video_bitmap != none
		|| command.video_frame_source != none || command.video_paintable != none
		|| command.nested_viewport_commands.len != 0 || command.nested_viewport_paintable != none
		|| command.nested_viewport_scene != unsafe { nil }
		|| command.text_clip_runs.len != 0 || command.backdrop_filter_data != none
		|| command.scrollbar_axis != '' {
		return none
	}
	mut srgb := unsafe { &PaintSRGBColor(nil) }
	if command.srgb_color_data != unsafe { nil } {
		srgb = &PaintSRGBColor{
			serialized: command.srgb_color_data.serialized.clone()
			components: command.srgb_color_data.components
		}
	}
	mut border := unsafe { &PaintLocalBorderData(nil) }
	if command.local_border_data != unsafe { nil } {
		border = &PaintLocalBorderData{
			...*command.local_border_data
		}
	}
	mut svg := unsafe { &PaintSVGPathData(nil) }
	if command.svg_data != unsafe { nil } { svg = own_static_svg_path(command.svg_data)? }
	mut clips := unsafe { &PaintClipList(nil) }
	if command.clip_list != unsafe { nil } {
		mut items := []PaintClip{cap: command.clip_list.items.len}
		for index in 0 .. command.clip_list.items.len {
			items << own_static_svg_clip(unsafe { &command.clip_list.items[index] })?
		}
		clips = &PaintClipList{ items: items }
	}
	mut layers := unsafe { &PaintVisualLayerList(nil) }
	if command.visual_layer_list != unsafe { nil } {
		mut items := []PaintVisualLayer{cap: command.visual_layer_list.items.len}
		for index in 0 .. command.visual_layer_list.items.len {
			items << own_static_svg_layer(unsafe { &command.visual_layer_list.items[index] })?
		}
		layers = &PaintVisualLayerList{ items: items }
	}
	mut layer := ?&PaintVisualLayer(none)
	if source := command.visual_layer_data {
		mut owned := own_static_svg_layer(source)?
		layer = &owned
	}
	mut mask := ?&PaintClip(none)
	if source := command.mask_clip_data {
		mut owned := own_static_svg_clip(source)?
		mask = &owned
	}
	// Spell out the transport fields, rather than shallow-copying the source:
	// a new reference payload must be deliberately admitted at this boundary.
	return PaintCommand{
		kind:                             command.kind.clone()
		x:                                command.x
		y:                                command.y
		width:                            command.width
		height:                           command.height
		color:                            command.color.clone()
		srgb_color_data:                  srgb
		force_dark_role:                  command.force_dark_role
		force_dark_role_set:              command.force_dark_role_set
		force_dark_backdrop:              command.force_dark_backdrop
		apply_force_dark_to_image:        command.apply_force_dark_to_image
		line_box_debug:                   command.line_box_debug
		antialiased_rect:                 command.antialiased_rect
		disable_antialias:                command.disable_antialias
		underlays_next:                   command.underlays_next
		font_size:                        command.font_size
		bold:                             command.bold
		italic:                           command.italic
		mono:                             command.mono
		rtl:                              command.rtl
		glyph_translation_x:              command.glyph_translation_x
		glyph_translation_y:              command.glyph_translation_y
		glyph_orientation:                command.glyph_orientation
		font_smoothing:                   command.font_smoothing
		opacity:                          command.opacity
		group_opacity:                    command.group_opacity
		radius:                           command.radius
		local_border_data:                border
		clip_outs:                        command.clip_outs.clone()
		corner_radii:                     command.corner_radii
		blur:                             command.blur
		shadow_offset_x:                  command.shadow_offset_x
		shadow_offset_y:                  command.shadow_offset_y
		shadow_spread:                    command.shadow_spread
		outer_shadow:                     command.outer_shadow
		gradient_background_layer:        command.gradient_background_layer
		svg_data:                         svg
		transform:                        command.transform
		points:                           command.points.clone()
		stroke_color:                     command.stroke_color.clone()
		stroke_width:                     command.stroke_width
		line_style:                       command.line_style.clone()
		image_scroll_offset_x:            command.image_scroll_offset_x
		image_scroll_offset_y:            command.image_scroll_offset_y
		visual_context_index:             command.visual_context_index
		video_representation:             command.video_representation
		has_clip:                         command.has_clip
		clip_x:                           command.clip_x
		clip_y:                           command.clip_y
		clip_width:                       command.clip_width
		clip_height:                      command.clip_height
		clip_list:                        clips
		recording_clip:                   command.recording_clip
		visual_layer_list:                layers
		visual_layer_data:                layer
		backdrop_source_outside_filter:   command.backdrop_source_outside_filter
		mask_clip_data:                   mask
		fixed_to_viewport:                command.fixed_to_viewport
		scrollbar_thumb_travel_ratio:     command.scrollbar_thumb_travel_ratio
		scrollbar_recorded_scroll_offset: command.scrollbar_recorded_scroll_offset
		paint_box_index:                  command.paint_box_index
		paint_phase:                      command.paint_phase
	}
}

fn own_static_svg_path(source &PaintSVGPathData) ?&PaintSVGPathData {
	if source.fill_pattern != none || source.stroke_pattern != none { return none }
	mut polygons := [][]f64{cap: source.path_polygons.len}
	for index in 0 .. source.path_polygons.len { polygons << source.path_polygons[index].clone() }
	mut solid := unsafe { &PaintSVGSolidColorData(nil) }
	if source.svg_solid_color_data != unsafe { nil } {
		data := source.svg_solid_color_data
		solid = &PaintSVGSolidColorData{
			fill_serialized:   data.fill_serialized.clone()
			fill:              data.fill
			has_fill:          data.has_fill
			stroke_serialized: data.stroke_serialized.clone()
			stroke:            data.stroke
			has_stroke:        data.has_stroke
		}
	}
	mut gradients := ?&PaintSVGGradientData(none)
	if data := source.svg_gradient_data {
		gradients = &PaintSVGGradientData{
			fill_linear_gradient:   own_static_svg_linear_gradient(data.fill_linear_gradient)
			stroke_linear_gradient: own_static_svg_linear_gradient(data.stroke_linear_gradient)
			fill_radial_gradient:   own_static_svg_radial_gradient(data.fill_radial_gradient)
			stroke_radial_gradient: own_static_svg_radial_gradient(data.stroke_radial_gradient)
		}
	}
	return &PaintSVGPathData{
		path:                 source.path.clone()
		path_data:            source.path_data.clone()
		path_transform:       source.path_transform
		path_polygons:        polygons
		svg_gradient_data:    gradients
		svg_solid_color_data: solid
		stroke_dasharray:     source.stroke_dasharray.clone()
		stroke_dashoffset:    source.stroke_dashoffset
		non_scaling_stroke:   source.non_scaling_stroke
		stroke_first:         source.stroke_first
		fill_even_odd:        source.fill_even_odd
		stroke_linecap:       source.stroke_linecap
		stroke_linejoin:      source.stroke_linejoin
		stroke_miterlimit:    source.stroke_miterlimit
		fill_opacity:         source.fill_opacity
		stroke_opacity:       source.stroke_opacity
	}
}

fn own_static_svg_gradient(source &painting.SVGGradientPaintStyle) painting.SVGGradientPaintStyle {
	return painting.SVGGradientPaintStyle{
		color_stops:        source.color_stops.clone()
		repeat_length:      source.repeat_length
		gradient_transform: source.gradient_transform
		spread_method:      source.spread_method
		color_space:        source.color_space
	}
}

fn own_static_svg_linear_gradient(source ?painting.SVGLinearGradientPaintStyle) ?painting.SVGLinearGradientPaintStyle {
	style := source or { return none }
	return painting.SVGLinearGradientPaintStyle{
		gradient:    own_static_svg_gradient(&style.gradient)
		start_point: style.start_point
		end_point:   style.end_point
	}
}

fn own_static_svg_radial_gradient(source ?painting.SVGRadialGradientPaintStyle) ?painting.SVGRadialGradientPaintStyle {
	style := source or { return none }
	return painting.SVGRadialGradientPaintStyle{
		gradient:     own_static_svg_gradient(&style.gradient)
		start_center: style.start_center
		start_radius: style.start_radius
		end_center:   style.end_center
		end_radius:   style.end_radius
	}
}

fn own_static_svg_clip(source &PaintClip) ?PaintClip {
	// clipPath uses is_svg_mask too. Actual SVG masks carry operations and may
	// own images/pattern recordings, so leave those on the full-document path.
	if source.is_svg_content_mask || source.mask_operations.len != 0 { return none }
	mut components := []PaintPath{cap: source.path_components.len}
	for index in 0 .. source.path_components.len {
		path := unsafe { &source.path_components[index] }
		components << PaintPath{
			path_data:     path.path_data.clone()
			path_even_odd: path.path_even_odd
			transform:     path.transform
		}
	}
	return PaintClip{
		rect:            source.rect
		corner_radii:    source.corner_radii
		is_path:         source.is_path
		is_svg_mask:     source.is_svg_mask
		path_data:       source.path_data.clone()
		path_even_odd:   source.path_even_odd
		path_components: components
		cache_key:       source.cache_key
		scope_id:        source.scope_id
		mask_luminance:  source.mask_luminance
		transform:       source.transform
	}
}

fn own_static_svg_layer(source &PaintVisualLayer) ?PaintVisualLayer {
	if source.kind == .css_filter || source.filter != none { return none }
	return PaintVisualLayer{
		kind:       source.kind
		scope_id:   source.scope_id
		opacity:    source.opacity
		blend_mode: source.blend_mode
		clip_rect:  source.clip_rect
		mask_clip:  own_static_svg_clip(&source.mask_clip)?
	}
}
