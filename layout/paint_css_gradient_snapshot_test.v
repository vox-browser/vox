module layout

import css
import html
import painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn ephemeral_css_gradient_commands() []PaintCommand {
	return BlockBox{
		width: 100
		height: 50
		background_gradient: &LinearGradient{
			x2: 1
			colors: [css.Color{255, 255, 255, 255}, css.Color{0, 0, 0, 255}]
			stops: [GradientStop{color: css.Color{255, 255, 255, 255}, offset: 0},
				GradientStop{color: css.Color{0, 0, 0, 255}, offset: 1}]
		}
	}.paint_commands().filter(it.kind == 'fill_gradient')
}

fn test_css_gradient_commands_retain_the_image_after_the_producer_and_collections() {
	commands := ephemeral_css_gradient_commands()
	assert commands.len == 1
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		gradient := commands[0].gradient or { panic('missing retained CSS gradient') }
		assert gradient.x2 == 1
		assert gradient.colors.len == 2
		assert gradient.stops.len == 2
		assert gradient.stops[1].offset == 1
		assert gradient_color_at(gradient, 0.5) == css.Color{128, 128, 128, 255}
	}
	assert (PaintCommand{kind: 'draw_text'}).gradient == none
	assert (PaintCommand{kind: 'fill_rect'}).gradient == none
}

fn test_force_dark_replaces_css_gradient_colors_without_mutating_cached_recordings() {
	command := ephemeral_css_gradient_commands()[0]
	original := command.gradient or { panic('missing original gradient') }
	settings := painting.ForceDarkSettings.default()
	resolved := resolve_force_dark_paint_commands([command, command], settings)
	for dark_command in resolved {
		gradient := dark_command.gradient or { panic('missing dark gradient') }
		assert voidptr(gradient) != voidptr(original)
		for index, color in original.colors {
			expected := painting.force_dark_resolve(painting.Color{color.r, color.g, color.b, color.a},
				.background, settings)
			assert gradient.colors[index] == css.Color{expected.r, expected.g, expected.b, expected.a}
			assert gradient.stops[index].color == gradient.colors[index]
		}
	}
	$if gcboehm ? { C.GC_gcollect() }
	assert original.colors[0] == css.Color{255, 255, 255, 255}
	assert original.stops[0].color == original.colors[0]
}

fn test_css_gradient_recordings_survive_replay_and_author_background_replacement() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:100px;height:50px;background:linear-gradient(to right,red,blue)}</style><div id="target"></div>')
	_ = layout_document_typed_in_viewport(document, 100, 50)
	first := display_list_commands(document.record_display_list() or { panic('missing first recording') }).filter(it.kind == 'fill_gradient')[0]
	first_image := first.gradient or { panic('missing first gradient') }
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := display_list_commands(document.record_display_list() or { panic('missing replay') }).filter(it.kind == 'fill_gradient')[0]
	second_image := second.gradient or { panic('missing replay gradient') }
	assert voidptr(first_image) == voidptr(second_image)
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	target.set_attribute_value('style', 'background:linear-gradient(to right,green,blue)')
	document.update_layout(.dump_display_list)
	third := display_list_commands(document.record_display_list() or { panic('missing updated recording') }).filter(it.kind == 'fill_gradient')[0]
	third_image := third.gradient or { panic('missing updated gradient') }
	assert voidptr(first_image) != voidptr(third_image)
	$if gcboehm ? { C.GC_gcollect() }
	assert gradient_color_at(first_image, 0) == css.Color{255, 0, 0, 255}
	assert gradient_color_at(third_image, 0) == css.Color{0, 128, 0, 255}
}
