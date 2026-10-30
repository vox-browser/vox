// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import html
import painting
import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

// Exact original record and background producer from canonical 77e2a22e.
// Only their type/function names are changed; the setup script pins the source.
pub struct LegacyImagePaintCommand {
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
	// `draw_background_image` payload. Intrinsic dimensions are resolved by the image renderer.
	image_url                   string
	background_svg_document     ?&dom.Document           = none
	background_static_svg_resource ?&StaticSVGBackgroundResource = none
	background_svg_color_scheme css.PreferredColorScheme = .auto_
	image_intrinsic_width       f64
	image_intrinsic_height      f64
	image_repeat_x              string
	image_repeat_y              string
	image_size                  string
	image_position_x            string
	image_position_y            string
	image_rendering             css.ImageRendering
	image_clip_x                f64
	image_clip_y                f64
	image_clip_width            f64
	image_clip_height           f64
	image_clip_radii            BoxRadii
	image_attachment            string
	background_layer_data       ?&PaintBackgroundLayerData = none
	image_scroll_offset_x       f64
	image_scroll_offset_y       f64
	background_blend_mode       painting.BlendMode
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
	nested_viewport_commands  []LegacyImagePaintCommand
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

fn image_payload_legacy_background_layer_command(layer BackgroundImageLayer, origin LayoutRect, clip LayoutRect,
	clip_radii BoxRadii, opacity f64, radius f64, points []f64,
	background_scroll_offset painting.Point, image_rendering css.ImageRendering,
	fixed_background_visual_context ?int, initial_containing_block LayoutRect) ?LegacyImagePaintCommand {
	blend_mode := background_image_layer_blend_mode(layer)
	mut positioning_area := origin
	mut visual_context_index := ?int(none)
	if layer.attachment == 'fixed' {
		if fixed_context := fixed_background_visual_context {
			positioning_area = initial_containing_block
			visual_context_index = fixed_context
		}
	}
	if source := layer.gradient_source {
		computed_layer := layer.computed_layer or { return none }
		resolved_layer := painting.resolve_background_layer_without_intrinsic(painting.BackgroundLayerWithoutIntrinsicResolutionInput{
			layer:                       computed_layer
			image_id:                    source.serialize(.normal)
			background_positioning_area: painting.Rect{positioning_area.x, positioning_area.y, positioning_area.width, positioning_area.height}
			resolution_context:          layer.resolution_context
		}) or { return none }
		gradient := resolve_background_gradient(source, resolved_layer.image_rect.width, resolved_layer.image_rect.height, layer.resolution_context, layer.gradient_context) or {
			return none
		}
		return LegacyImagePaintCommand{
			kind:                      'fill_gradient'
			x:                         positioning_area.x
			y:                         positioning_area.y
			width:                     positioning_area.width
			height:                    positioning_area.height
			opacity:                   opacity
			radius:                    radius
			points:                    points
			gradient:                  &LinearGradient{ ...gradient }
			gradient_background_layer: true
			force_dark_role:           .background
			force_dark_role_set:       true
			image_clip_x:              clip.x
			image_clip_y:              clip.y
			image_clip_width:          clip.width
			image_clip_height:         clip.height
			image_clip_radii:          clip_radii
			image_attachment:          layer.attachment
			background_layer_data:     retained_background_layer_data(layer, false)
			image_scroll_offset_x:     background_scroll_offset.x
			image_scroll_offset_y:     background_scroll_offset.y
			background_blend_mode:     blend_mode
			visual_context_index:      visual_context_index
		}
	}
	if layer.url == '' {
		return none
	}
	return LegacyImagePaintCommand{
		kind:                        'draw_background_image'
		x:                           positioning_area.x
		y:                           positioning_area.y
		width:                       positioning_area.width
		height:                      positioning_area.height
		opacity:                     opacity
		radius:                      radius
		points:                      points
		image_url:                   layer.url
		force_dark_role:             .background
		force_dark_role_set:         true
		background_svg_document:     layer.svg_document
		background_static_svg_resource: layer.static_svg_resource
		background_svg_color_scheme: layer.color_scheme
		image_intrinsic_width:       layer.intrinsic_width
		image_intrinsic_height:      layer.intrinsic_height
		image_repeat_x:              layer.repeat_x
		image_repeat_y:              layer.repeat_y
		image_size:                  layer.size
		image_position_x:            layer.position_x
		image_position_y:            layer.position_y
		image_rendering:             image_rendering
		image_clip_x:                clip.x
		image_clip_y:                clip.y
		image_clip_width:            clip.width
		image_clip_height:           clip.height
		image_clip_radii:            clip_radii
		image_attachment:            layer.attachment
		background_layer_data:       retained_background_layer_data(layer, false)
		image_scroll_offset_x:       background_scroll_offset.x
		image_scroll_offset_y:       background_scroll_offset.y
		background_blend_mode:       blend_mode
		visual_context_index:        visual_context_index
	}
}

fn image_payload_assert_legacy(actual PaintCommand, expected LegacyImagePaintCommand) {
	image := actual.image()
	assert actual.kind == expected.kind
	assert actual.x == expected.x
	assert actual.y == expected.y
	assert actual.width == expected.width
	assert actual.height == expected.height
	assert actual.opacity == expected.opacity
	assert actual.radius == expected.radius
	assert actual.points == expected.points
	assert actual.force_dark_role == expected.force_dark_role
	assert actual.force_dark_role_set == expected.force_dark_role_set
	assert actual.gradient_background_layer == expected.gradient_background_layer
	assert actual.image_scroll_offset_x == expected.image_scroll_offset_x
	assert actual.image_scroll_offset_y == expected.image_scroll_offset_y
	assert actual.visual_context_index == expected.visual_context_index
	assert image.image_url == expected.image_url
	assert retained_paint_payload_equal(image.background_svg_document, expected.background_svg_document)
	assert retained_paint_payload_equal(image.background_static_svg_resource, expected.background_static_svg_resource)
	assert image.background_svg_color_scheme == expected.background_svg_color_scheme
	assert image.image_intrinsic_width == expected.image_intrinsic_width
	assert image.image_intrinsic_height == expected.image_intrinsic_height
	assert image.image_repeat_x == expected.image_repeat_x
	assert image.image_repeat_y == expected.image_repeat_y
	assert image.image_size == expected.image_size
	assert image.image_position_x == expected.image_position_x
	assert image.image_position_y == expected.image_position_y
	assert image.image_rendering == expected.image_rendering
	assert image.image_clip_x == expected.image_clip_x
	assert image.image_clip_y == expected.image_clip_y
	assert image.image_clip_width == expected.image_clip_width
	assert image.image_clip_height == expected.image_clip_height
	assert image.image_clip_radii == expected.image_clip_radii
	assert image.image_attachment == expected.image_attachment
	assert image.background_blend_mode == expected.background_blend_mode
	if data := image.background_layer_data {
		old_data := expected.background_layer_data or { panic('missing old retained layer') }
		assert data.layer == old_data.layer
		assert data.resolution_context == old_data.resolution_context
	} else {
		assert expected.background_layer_data == none
	}
	if gradient := actual.gradient {
		old_gradient := expected.gradient or { panic('missing old gradient') }
		assert *gradient == *old_gradient
	} else {
		assert expected.gradient == none
	}
}

fn test_image_payload_reduces_the_actual_common_record_width() {
	assert sizeof(PaintCommand) < sizeof(LegacyImagePaintCommand)
	assert sizeof(LegacyImagePaintCommand) - sizeof(PaintCommand) >= 280
	assert sizeof(PaintImageData) <= 400
	println('image-payload-size old=${sizeof(LegacyImagePaintCommand)} new=${sizeof(PaintCommand)} payload=${sizeof(PaintImageData)}')
}

fn test_image_payload_absent_defaults_match_the_original_record() {
	for kind in ['draw_text', 'fill_rect', 'draw_svg_path', 'begin_opacity_layer', 'fill_gradient'] {
		command := PaintCommand{ kind: kind }
		assert command.image_data == unsafe { nil }
		assert command.image_url() == ''
		image_payload_assert_legacy(command, LegacyImagePaintCommand{ kind: kind })
	}
}

fn test_image_payload_background_producers_match_original_fields_and_gradients() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:120px;height:80px;background-image:url(retained.png),linear-gradient(to right,red,blue);background-repeat:round space,no-repeat;background-position:25% 75%;background-size:30px auto;background-attachment:fixed,local;background-blend-mode:multiply,screen;image-rendering:pixelated}</style><div id="target"></div>')
	root := layout_document_typed_in_viewport(document, 240, 160)
	boxes := root.paint_order().filter(it.decorations().background_images.len == 2)
	assert boxes.len == 1
	for layer in boxes[0].decorations().background_images {
		for fixed_context in [?int(none), ?int(7)] {
			actual := background_layer_command(layer, LayoutRect{3, 4, 120, 80}, LayoutRect{5, 6, 90, 60}, BoxRadii{ top_left: CornerRadius{3, 7} }, 0.7, 9, [
				f64(1),
				2,
				3,
				4,
			], painting.Point{13, 17}, .pixelated, fixed_context, LayoutRect{0, 0, 240, 160}, false, none, false) or { panic('missing new command') }
			expected := image_payload_legacy_background_layer_command(layer, LayoutRect{3, 4, 120, 80}, LayoutRect{5, 6, 90, 60}, BoxRadii{ top_left: CornerRadius{3, 7} }, 0.7, 9, [
				f64(1),
				2,
				3,
				4,
			], painting.Point{13, 17}, .pixelated, fixed_context, LayoutRect{0, 0, 240, 160}) or { panic('missing old command') }
			image_payload_assert_legacy(actual, expected)
			assert actual.image_data != unsafe { nil }
		}
	}
}

fn image_payload_returned_background() PaintCommand {
	return BlockBox{ width: 100, height: 50,
		decoration_data: retained_block_box_decoration(BlockBoxDecorationData{
			background_images: [BackgroundImageLayer{ url: 'retained.png', repeat_x: 'round', repeat_y: 'space', size: '20px auto', position_x: '25%', position_y: '75%', attachment: 'local', intrinsic_width: 40, intrinsic_height: 30 }]
		})
	}.paint_commands().filter(it.kind == 'draw_background_image')[0]
}

fn test_image_payload_survives_producer_return_collection_and_source_replacement() {
	first := image_payload_returned_background()
	second := image_payload_returned_background()
	assert voidptr(first.image_data) != voidptr(second.image_data)
	saved := first.image()
	for _ in 0 .. 3 {
		_ = image_payload_returned_background()
		$if gcboehm ? {
			C.GC_gcollect()
		}
		assert retained_paint_payload_equal(first.image(), saved)
		assert first.image_url() == 'retained.png'
	}
	changed := PaintCommand{ ...first, image_data: &PaintImageData{ ...first.image(), image_url: 'replacement.png', image_clip_y: 999 } }
	assert changed.image_url() == 'replacement.png'
	assert first.image_url() == 'retained.png'
	assert first.image().image_clip_y == 0
	assert voidptr(first.image_data) != voidptr(changed.image_data)
}

fn test_image_payload_phase_cache_replay_shares_only_immutable_parameters() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:100px;height:50px;background:url(retained.png) no-repeat 25% 50%}</style><div id="target">retained text</div>')
	_ = layout_document_typed_in_viewport(document, 320, 100)
	first := display_list_commands(document.record_display_list() or { panic('first recording') })
	first_image := first.filter(it.kind == 'draw_background_image')[0]
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := display_list_commands(document.record_display_list() or { panic('second recording') })
	second_image := second.filter(it.kind == 'draw_background_image')[0]
	assert voidptr(first_image.image_data) == voidptr(second_image.image_data)
	assert retained_paint_payload_equal(first_image.image(), second_image.image())
	for command in second {
		if command.kind !in ['draw_background_image', 'draw_replaced_image', 'draw_svg_image'] && !(command.kind == 'fill_gradient' && command.gradient_background_layer) {
			assert command.image_data == unsafe { nil }
		}
	}
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	target.set_attribute_value('style', 'background-image:url(replacement.png)')
	document.update_layout(.dump_display_list)
	third := display_list_commands(document.record_display_list() or { panic('third recording') }).filter(it.kind == 'draw_background_image')[0]
	assert voidptr(third.image_data) != voidptr(first_image.image_data)
	assert third.image_url().ends_with('replacement.png')
	assert first_image.image_url().ends_with('retained.png')
}

fn test_image_payload_live_scroll_offsets_do_not_mutate_retained_parameters() {
	first := image_payload_returned_background()
	mut replay := first
	box := BlockBox{ overlay: &CompatibilityOverlayData{ scroll_offset_x: 17, scroll_offset_y: 29 } }
	apply_live_background_offsets(mut replay, &box)
	assert replay.image_scroll_offset_x == 17
	assert replay.image_scroll_offset_y == 29
	assert voidptr(replay.image_data) == voidptr(first.image_data)
	assert retained_paint_payload_equal(replay.image(), first.image())
	assert first.image_scroll_offset_x == 0
	assert first.image_scroll_offset_y == 0
}

fn test_image_payload_nested_replay_preserves_source_geometry_and_earlier_recording() {
	first := image_payload_returned_background()
	nested := paint_command_for_nested_viewport(first, [f64(2), 0, 0, 3, 11, 13]!, painting.IntPoint{5, 7}, 0.5)
	assert voidptr(nested.image_data) == voidptr(first.image_data)
	assert retained_paint_payload_equal(nested.image(), first.image())
	assert nested.transform == [f64(2), 0, 0, 3, 21, 34]!
	assert nested.opacity == first.opacity * 0.5
	assert first.transform == [6]f64{}
	assert first.opacity == 1
	copied := PaintCommand{ ...nested, image_data: &PaintImageData{ ...nested.image(), image_clip_x: 99 } }
	assert voidptr(copied.image_data) != voidptr(first.image_data)
	assert copied.image().image_clip_x == 99
	assert first.image().image_clip_x == 0
}

fn test_image_payload_replaced_producer_retains_exact_image_parameters() {
	box := BlockBox{ x: 3, y: 5, width: 100, height: 50, replaced_image_rendering: .pixelated
		media_data: retained_block_box_media(BlockBoxMediaData{
			replaced_image_url: 'retained.png'
			replaced_image_size: 'contain'
			replaced_image_position_x: '25%'
			replaced_image_position_y: '75%'
		})
	}
	command := box.paint_commands().filter(it.kind == 'draw_background_image')[0]
	image := command.image()
	assert image.image_url == 'retained.png'
	assert image.image_repeat_x == 'no-repeat'
	assert image.image_repeat_y == 'no-repeat'
	assert image.image_size == 'contain'
	assert image.image_position_x == '25%'
	assert image.image_position_y == '75%'
	assert image.image_rendering == .pixelated
	assert image.image_clip_x == 3
	assert image.image_clip_y == 5
	assert image.image_clip_width == 100
	assert image.image_clip_height == 50
}

fn test_image_payload_svg_export_preserves_image_parameters_and_escaping() {
	box := BlockBox{ x: 3, y: 5, width: 100, height: 50,
		media_data: retained_block_box_media(BlockBoxMediaData{
			replaced_image_url: 'retained&image.png'
			replaced_image_size: 'contain'
			replaced_image_position_x: '25%'
			replaced_image_position_y: '75%'
		})
	}
	svg := box.render_svg(120, 80)
	assert svg.contains('href="retained&amp;image.png"')
	assert svg.contains('x="3" y="5" width="100" height="50" preserveAspectRatio="xMidYMid meet"')
	assert svg.contains('data-background-repeat="no-repeat no-repeat" data-background-position="25% 75%"')
	assert svg.contains('<rect x="3" y="5" width="100" height="50"/>')
}
