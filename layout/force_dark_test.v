module layout

import css
import dom
import html
import painting

fn force_dark_test_color_string(color painting.Color) string {
	return css.Color{color.r, color.g, color.b, color.a}.serialize()
}

fn test_force_dark_command_resolution_uses_paint_roles_and_explicit_exceptions() {
	settings := painting.ForceDarkSettings.default()
	commands := [
		PaintCommand{
			kind: 'fill_rect'
			color: 'white'
			paint_phase: .background
		},
		PaintCommand{
			kind: 'draw_text'
			color: 'black'
			paint_phase: .foreground
		},
		PaintCommand{
			kind: 'stroke_rounded_rect'
			color: 'black'
			force_dark_role: .none_
			force_dark_role_set: true
			paint_phase: .outline
		},
	]
	resolved := resolve_force_dark_paint_commands(commands, settings)
	assert resolved[0].color == force_dark_test_color_string(painting.force_dark_resolve(painting.Color{255,
		255, 255, 255}, .background, settings))
	assert resolved[1].color == force_dark_test_color_string(painting.force_dark_resolve(painting.Color{0,
		0, 0, 255}, .foreground, settings))
	assert resolved[2].color == 'black'
	assert commands[0].color == 'white'
}

fn test_force_dark_command_resolution_marks_only_eligible_image_roles() {
	resolved := resolve_force_dark_paint_commands([
		PaintCommand{
			kind: 'draw_replaced_image'
			force_dark_role: .background
			force_dark_role_set: true
		},
		PaintCommand{
			kind: 'draw_background_image'
			force_dark_role: .none_
			force_dark_role_set: true
		},
	], painting.ForceDarkSettings.default())
	assert resolved[0].apply_force_dark_to_image
	assert !resolved[1].apply_force_dark_to_image
}

fn test_force_dark_command_resolution_uses_authored_backdrop_for_contrast_roles() {
	settings := painting.ForceDarkSettings.default()
	backdrop := painting.Color{240, 240, 240, 255}
	border := painting.Color{255, 255, 255, 255}
	selection := painting.Color{102, 102, 102, 255}
	resolved := resolve_force_dark_paint_commands([
		PaintCommand{
			color: force_dark_test_color_string(border)
			force_dark_role: .border
			force_dark_role_set: true
			force_dark_backdrop: backdrop
		},
		PaintCommand{
			color: force_dark_test_color_string(selection)
			force_dark_role: .selection
			force_dark_role_set: true
			force_dark_backdrop: backdrop
		},
	], settings)
	assert resolved[0].color == force_dark_test_color_string(painting.force_dark_resolve_against_backdrop(border,
		.border, backdrop, settings))
	assert resolved[1].color == force_dark_test_color_string(painting.force_dark_resolve_against_backdrop(selection,
		.selection, backdrop, settings))
}

fn test_force_dark_command_resolution_translates_css_and_svg_gradient_stops() {
	settings := painting.ForceDarkSettings.default()
	white := css.Color{255, 255, 255, 255}
	black := painting.Color{0, 0, 0, 255}
	resolved := resolve_force_dark_paint_commands([
		PaintCommand{
			force_dark_role: .background
			force_dark_role_set: true
			gradient: &LinearGradient{
				colors: [white]
				stops: [GradientStop{color: white, offset: 0}]
			}
		},
		PaintCommand{
			force_dark_role: .svg
			force_dark_role_set: true
			svg_data: &PaintSVGPathData{
				svg_gradient_data: &PaintSVGGradientData{
					fill_linear_gradient: painting.SVGLinearGradientPaintStyle{
						gradient: painting.SVGGradientPaintStyle{
							color_stops: [painting.ColorStop{color: black, position: 0}]
						}
					}
				}
			}
		},
	], settings)
	css_gradient := resolved[0].gradient or { panic('missing CSS gradient') }
	expected_background := painting.force_dark_resolve(painting.Color{255, 255, 255, 255},
		.background, settings)
	assert css_gradient.colors[0] == css.Color{expected_background.r, expected_background.g,
		expected_background.b, expected_background.a}
	assert css_gradient.stops[0].color == css_gradient.colors[0]
	svg_gradient := resolved[1].fill_linear_gradient() or { panic('missing SVG gradient') }
	assert svg_gradient.gradient.color_stops[0].color == painting.force_dark_resolve(black,
		.svg, settings)
}

fn test_force_dark_navigable_resolves_recorded_page_colors_and_honors_dark_opt_out() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}html{background:white}p{color:black}</style><p>text</p>')
	host := &dom.Navigable{ active_document_: document }
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	document.set_cached_navigable(host)
	navigable.set_force_dark_enabled(true)
	_ = layout_document_typed_in_viewport(document, 120, 80)
	commands := display_list_commands(document.record_display_list() or {
		panic('missing force-dark display list')
	})
	settings := painting.ForceDarkSettings.default()
	dark_surface := force_dark_test_color_string(painting.force_dark_resolve(painting.Color{255,
		255, 255, 255}, .background, settings))
	light_text := force_dark_test_color_string(painting.force_dark_resolve(painting.Color{0, 0,
		0, 255}, .foreground, settings))
	assert commands.any(it.kind == 'fill_rect' && it.color == dark_surface)
	assert commands.any(it.kind == 'draw_text' && it.color == light_text)

	mut opted_out_document := html.parse_document('<!doctype html><style>html,body{margin:0}html{color-scheme:dark;background:white}</style>')
	opted_out_host := &dom.Navigable{ active_document_: opted_out_document }
	mut opted_out_navigable := html.NavigableModel.create(opted_out_host, none) or { panic(err) }
	opted_out_document.set_cached_navigable(opted_out_host)
	opted_out_navigable.set_force_dark_enabled(true)
	_ = layout_document_typed_in_viewport(opted_out_document, 120, 80)
	opted_out_commands := display_list_commands(opted_out_document.record_display_list() or {
		panic('missing opted-out display list')
	})
	assert opted_out_commands.any(it.kind == 'fill_rect' && it.color == 'rgb(255 255 255)')
}

fn test_force_dark_leaves_line_box_debug_commands_unfiltered() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}body{background:#181818;color:#e8e8e8}</style><div>chrome stays chrome</div>')
	host := &dom.Navigable{ active_document_: document }
	mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
	document.set_cached_navigable(host)
	navigable.set_should_show_line_box_borders(true)
	navigable.set_force_dark_enabled(true)
	_ = layout_document_typed_in_viewport(document, 320, 100)
	commands := display_list_commands(document.record_display_list() or {
		panic('missing debug-overlay display list')
	})
	debug_commands := commands.filter(it.line_box_debug)
	assert debug_commands.len >= 2
	assert debug_commands.any(it.kind == 'stroke_rounded_rect' && it.color == '#00ff00')
	assert debug_commands.any(it.kind == 'draw_line' && it.color == '#ff0000')
	assert debug_commands.all(it.force_dark_role_set && it.force_dark_role == .none_)
	mut debug_index := -1
	mut text_index := -1
	for index, command in commands {
		if debug_index < 0 && command.line_box_debug {
			debug_index = index
		}
		if text_index < 0 && command.kind == 'draw_text' {
			text_index = index
		}
	}
	assert debug_index < text_index

	mut plain_document := html.parse_document('<!doctype html><p>plain</p>')
	plain_host := &dom.Navigable{ active_document_: plain_document }
	_ = html.NavigableModel.create(plain_host, none) or { panic(err) }
	plain_document.set_cached_navigable(plain_host)
	_ = layout_document_typed_in_viewport(plain_document, 320, 100)
	plain_commands := display_list_commands(plain_document.record_display_list() or {
		panic('missing ordinary display list')
	})
	assert plain_commands.all(!it.line_box_debug)
}
