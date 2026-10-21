module layout

import dom
import css
import math
import painting

const html_ns = 'http://www.w3.org/1999/xhtml'

fn styled(doc &dom.Document, tag string, style string) &dom.Element {
	mut e := doc.create_element_ns(html_ns, tag) or { panic('${err}') }
	if style != '' {
		e.set_attribute_value('style', style)
	}
	return e
}

// layout_document on an empty document (no root element) returns an empty box.
fn test_layout_document_no_root() {
	doc := dom.Document.create(dom.url_about_blank())
	box := layout_document(doc, 800)
	assert box.tag_name == ''
	assert box.width == 0.0
}

// layout_document over a manually built html>body>div tree: root fills the viewport, body keeps its
// explicit width, the div's height flows through.
fn test_layout_document_manual_root() {
	doc := dom.Document.create(dom.url_about_blank())
	html_el := styled(doc, 'html', '')
	body := styled(doc, 'body', 'width: 300px')
	child := styled(doc, 'div', 'height: 50px')
	mut bn := body.as_node()
	bn.append_child(child.as_node()) or { panic('${err}') }
	mut hn := html_el.as_node()
	hn.append_child(body.as_node()) or { panic('${err}') }
	mut docn := unsafe { &dom.Node(doc) }
	docn.append_child(html_el.as_node()) or { panic('${err}') }

	box := layout_document(doc, 800)
	assert box.tag_name == 'html'
	assert box.width == 800.0 // fills the viewport

	assert box.children.len == 1
	assert box.children[0].tag_name == 'body'
	assert box.children[0].width == 300.0
	assert box.children[0].children[0].height == 50.0
}

fn test_fragmented_inline_omits_away_borders_and_corner_radii() {
	fragment := TextFragment{
		x: 20
		y: 10
		width: 30
		height: 12
		text: 'continued'
		inline_node_id: 1
		fragment_left_edge_away: true
		border: BoxEdges{2, 3, 4, 5}
		border_colors: BoxColors{
			top: css.Color{255, 0, 0, 255}
			right: css.Color{0, 128, 0, 255}
			bottom: css.Color{0, 0, 255, 255}
			left: css.Color{0, 0, 0, 255}
		}
		border_radii: BoxRadii{
			top_left: CornerRadius{5, 5}
			top_right: CornerRadius{5, 5}
			bottom_right: CornerRadius{5, 5}
			bottom_left: CornerRadius{5, 5}
		}
		border_radius: 5
	}
	fragment_commands := inline_fragment_commands([fragment], 1)
	mut commands := fragment_commands.decorations.clone()
	commands << fragment_commands.outlines
	borders := commands.filter(it.kind == 'draw_svg_path')
	assert borders.len == 3
	assert borders.map(it.color) == ['rgb(0 128 0)', 'rgb(0 0 255)', 'rgb(255 0 0)']
	assert borders.all(it.x == 20)
	assert borders.all(it.corner_radii.top_left == CornerRadius{})
	assert borders.all(it.corner_radii.bottom_left == CornerRadius{})

	middle := TextFragment{
		...fragment
		fragment_right_edge_away: true
	}
	middle_commands := inline_fragment_commands([middle], 1)
	mut middle_all_commands := middle_commands.decorations.clone()
	middle_all_commands << middle_commands.outlines
	middle_borders := middle_all_commands.filter(it.kind == 'draw_svg_path')
	assert middle_borders.len == 2
	assert middle_borders.map(it.color) == ['rgb(0 0 255)', 'rgb(255 0 0)']
	assert middle_borders.all(it.corner_radii == BoxRadii{})
}

// Collect the text of every inline fragment in a box's line boxes, in order.
fn tt_fragment_texts(box BlockBox) []string {
	mut texts := []string{}
	for line in box.lines {
		for frag in line.fragments {
			texts << frag.text
		}
	}
	return texts
}

fn test_double_and_dotted_text_decoration_emit_their_distinct_geometry() {
	double_fragment := TextFragment{
		x: 0
		y: 0
		width: 30
		height: 20
		font_size: 20
		baseline: 15
		baseline_set: true
		font_metrics_set: true
		font_ascent: 15
		font_descent: 5
		glyph_height: 20
		color: css.Color{0, 0, 0, 255}
		decoration: 'underline'
		decoration_color: css.Color{255, 0, 0, 255}
		decoration_color_set: true
		decoration_style: 'double'
		decoration_thickness: 2
	}
	double_commands := decoration_commands(double_fragment, 1)
	assert double_commands.len == 2
	assert double_commands.all(it.kind == 'draw_line' && it.stroke_width == 2)
	// The first underline stroke is centered half a thickness below the baseline edge.
	assert double_commands[0].points[1] == 16
	assert double_commands[1].points[1] - double_commands[0].points[1] == 3

	dotted_fragment := TextFragment{
		...double_fragment
		decoration_style: 'dotted'
	}
	dots := decoration_commands(dotted_fragment, 1)
	assert dots.len == 1
	assert dots[0].kind == 'draw_line'
	assert dots[0].line_style == 'dotted'
}

fn test_triangle_wave_path_matches_upstream_full_and_partial_wave_geometry() {
	path := build_triangle_wave_path(painting.IntPoint{0, 0}, painting.IntPoint{18, 0}, 6)
	assert path.segments.len == 6
	assert path.segments[0].kind == .move_to
	assert path.segments[1..].all(it.kind == .line_to)
	assert path.polygon == [
		painting.Point{0, 0},
		painting.Point{3, -3},
		painting.Point{9, 3},
		painting.Point{12, 0},
		painting.Point{15, -3},
		painting.Point{18, 0},
	]
}

fn test_spelling_and_grammar_error_decorations_use_upstream_ua_styles() {
	base := TextFragment{
		x: 0
		y: 0
		width: 30
		height: 20
		font_size: 20
		color: css.Color{0, 0, 0, 255}
		decoration_color: css.Color{0, 0, 255, 255}
		decoration_color_set: true
		decoration_style: 'double'
		decoration_thickness: 4
	}
	spelling := decoration_commands(TextFragment{
		...base
		decoration: 'spelling-error'
	}, 1)
	assert spelling.len == 1
	assert spelling[0].kind == 'draw_svg_path'
	assert spelling[0].stroke_color == 'rgb(255 0 0)'
	assert spelling[0].stroke_width == 1
	assert spelling[0].svg().path_data.len > 0

	grammar := decoration_commands(TextFragment{
		...base
		decoration: 'grammar-error'
	}, 1)
	assert grammar.len == 1
	assert grammar[0].kind == 'draw_svg_path'
	assert grammar[0].stroke_color == 'rgb(0 128 0)'
	assert grammar[0].stroke_width == 1
}

fn test_local_background_attachment_offset_is_refreshed_during_retained_replay() {
	box := &BlockBox{
		overlay: &CompatibilityOverlayData{
			scroll_offset_x: 7
			scroll_offset_y: 9
		}
	}
	mut command := PaintCommand{ kind: 'draw_background_image' }
	apply_live_background_offsets(mut command, box)
	assert command.image_scroll_offset_x == 7
	assert command.image_scroll_offset_y == 9
	mut gradient_command := PaintCommand{
		kind: 'fill_gradient'
		gradient_background_layer: true
	}
	apply_live_background_offsets(mut gradient_command, box)
	assert gradient_command.image_scroll_offset_x == 7
	assert gradient_command.image_scroll_offset_y == 9
}

fn text_clip_test_box(text string) BlockBox {
	return BlockBox{
		paintable_with_lines: true
		lines: [
			TextLine{
				fragments: [
					TextFragment{
						x: 10
						y: 12
						width: 40
						height: 20
						text: text
						color: css.Color{0, 0, 0, 255}
						font_size: 16
					},
				]
			},
		]
	}
}

fn test_background_clip_text_uses_inclusive_in_flow_and_floating_glyph_runs() {
	mut in_flow := text_clip_test_box('flow')
	mut floating := text_clip_test_box('float')
	floating.floating = true
	mut absolute := text_clip_test_box('absolute')
	absolute.absolutely_positioned = true
	absolute.children = [text_clip_test_box('absolute-child')]
	box := BlockBox{
		width: 100
		height: 60
		background_color: css.Color{255, 0, 0, 255}
		background_color_clip: 'text'
		paintable_with_lines: true
		lines: text_clip_test_box('own').lines
		children: [in_flow, floating, absolute]
	}
	commands := box.paint_commands()
	begin_commands := commands.filter(it.kind == 'begin_background_text_clip')
	assert begin_commands.len == 1
	run_text := begin_commands[0].text_clip_runs.map(it.text)
	assert run_text == ['own', 'flow', 'float']
	mut background_sequence := []string{}
	for command in commands {
		if command.kind in ['begin_background_text_clip', 'end_background_text_clip']
			|| (command.kind == 'fill_rect' && command.color == 'rgb(255 0 0)') {
			background_sequence << command.kind
		}
	}
	assert background_sequence == ['begin_background_text_clip', 'fill_rect',
		'end_background_text_clip']
	svg := box.render_svg(120, 80)
	assert svg.contains('<mask id="background-text-mask0"')
	assert svg.contains('fill="white">own</text>')
	assert svg.contains('<g mask="url(#background-text-mask0)">')

	root := BlockBox{
		width: 100
		height: 60
		background_color: css.Color{255, 0, 0, 255}
		background_color_clip: 'text'
		paints_canvas_background: true
		canvas_width: 120
		canvas_height: 80
		paintable_with_lines: true
		lines: text_clip_test_box('root').lines
	}
	assert root.paint_commands().all(it.kind != 'begin_background_text_clip')
}

fn test_sampled_gradient_stops_preserve_interpolation_and_hard_boundaries() {
	gradient := LinearGradient{
		stops: [
			GradientStop{css.Color{255, 0, 0, 255}, 0.0},
			GradientStop{css.Color{255, 0, 0, 255}, 0.5},
			GradientStop{css.Color{0, 0, 255, 255}, 0.5},
			GradientStop{css.Color{0, 0, 255, 255}, 1.0},
		]
		interpolation_method: css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)
	}
	sampled := sampled_gradient_stops(gradient, 16)
	assert sampled[0] == GradientStop{css.Color{255, 0, 0, 255}, 0.0}
	assert sampled[sampled.len - 1] == GradientStop{css.Color{0, 0, 255, 255}, 1.0}
	hard_edge := sampled.filter(math.abs(it.offset - 0.5) < 0.000001)
	assert hard_edge.len == 2
	assert hard_edge[0].color == css.Color{255, 0, 0, 255}
	assert hard_edge[1].color == css.Color{0, 0, 255, 255}
}

fn test_sampled_gradient_stops_clip_out_of_range_stops_to_rendered_interval() {
	gradient := LinearGradient{
		stops: [
			GradientStop{css.Color{255, 0, 0, 255}, -1.0},
			GradientStop{css.Color{0, 0, 255, 255}, 2.0},
		]
	}
	sampled := sampled_gradient_stops(gradient, 16)
	assert sampled[0].offset == 0
	assert sampled[sampled.len - 1].offset == 1
	assert sampled.all(it.offset >= 0 && it.offset <= 1)
	assert sampled[0].color == gradient_color_at(gradient, 0)
	assert sampled[sampled.len - 1].color == gradient_color_at(gradient, 1)
}

fn test_sampled_gradient_stops_keep_clamped_leading_and_trailing_ranges() {
	gradient := LinearGradient{
		stops: [
			GradientStop{css.Color{255, 0, 0, 255}, 0.25},
			GradientStop{css.Color{0, 0, 255, 255}, 0.75},
		]
	}
	sampled := sampled_gradient_stops(gradient, 4)
	assert sampled[0] == GradientStop{css.Color{255, 0, 0, 255}, 0.0}
	assert sampled[1] == GradientStop{css.Color{255, 0, 0, 255}, 0.25}
	assert sampled[sampled.len - 2] == GradientStop{css.Color{0, 0, 255, 255}, 0.75}
	assert sampled[sampled.len - 1] == GradientStop{css.Color{0, 0, 255, 255}, 1.0}
}

fn test_gradient_color_at_interpolates_compatibility_color_arrays() {
	gradient := LinearGradient{
		colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 255}]
	}
	assert gradient_color_at(gradient, 0.5) == css.Color{128, 0, 128, 255}
}

// Build a grid with the given template + gap and n items (each 20px tall); return their (x, width, y).
struct GridCell {
	x     f64
	width f64
	y     f64
}

fn test_nested_viewport_commands_compose_translation_transform_clip_and_opacity() {
	clip := PaintClip{
		rect: LayoutRect{1, 2, 30, 40}
		is_svg_mask: true
		transform: [f64(1), 0, 0, 1, 5, 6]!
		path_components: [PaintPath{
			transform: [f64(1), 0, 0, 1, 7, 8]!
		}]
		mask_operations: [PaintMaskOperation{
			kind: .path
			transform: [f64(1), 0, 0, 1, 9, 10]!
		}]
	}
	command := PaintCommand{
		x: 1
		y: 2
		opacity: 0.5
		transform: [f64(1), 0, 0, 1, 3, 4]!
		has_clip: true
		clip_x: 1
		clip_y: 2
		clip_width: 30
		clip_height: 40
		clip_list: &PaintClipList{ items: [clip] }
		mask_clip_data: &PaintClip{ ...clip }
	}
	transformed := paint_command_for_nested_viewport(command, [f64(2), 0, 0, 2, 7, 8]!, painting.IntPoint{10, 20}, 0.5)
	assert transformed.transform == [f64(2), 0, 0, 2, 33, 56]!
	assert transformed.opacity == 0.25
	assert transformed.clip_x == 29
	assert transformed.clip_y == 52
	assert transformed.clip_width == 60
	assert transformed.clip_height == 80
	assert transformed.clip_list.items[0].transform == [f64(2), 0, 0, 2, 37, 60]!
	assert transformed.clip_list.items[0].path_components[0].transform == [f64(2), 0, 0, 2, 41,
		64]!
	assert transformed.mask_clip().mask_operations[0].transform == [f64(2), 0, 0, 2, 45, 68]!
	assert transformed.mask_clip().cache_key != command.mask_clip().cache_key
}

fn test_font_smoothing_is_retained_by_text_paint_commands() {
	fragment := TextFragment{
		x: 10
		y: 20
		width: 40
		height: 16
		text: 'Text'
		color: css.Color{1, 2, 3, 255}
		font_smoothing: .antialiased
		text_run_id: 1
		shape_as_run: true
		paintable_fragment: painting.PaintableFragment{
			text_value: 'Text'
			length_in_code_units: 4
		}
		text_shadows: [BoxShadow{
			offset_x: 1
			offset_y: 2
			color: css.Color{4, 5, 6, 255}
		}]
	}
	foreground := unselected_text_fragment_commands([fragment], 1)
	assert foreground.len == 1
	assert foreground[0].font_smoothing == .antialiased

	mut shadows := []PaintCommand{}
	paint_text_shadow(mut shadows, fragment, TextRenderSpan{
		end_code_unit: 4
	}, 1)
	assert shadows.len == 1
	assert shadows[0].font_smoothing == .antialiased

	box := &BlockBox{
		paintable_with_lines: true
		lines: [TextLine{ fragments: [fragment] }]
	}
	mut clip_runs := []PaintTextClipRun{}
	append_background_text_clip_runs(box, mut clip_runs)
	assert clip_runs.len == 1
	assert clip_runs[0].font_smoothing == .antialiased
}
