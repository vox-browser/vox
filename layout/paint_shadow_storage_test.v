module layout

import css
import html
import painting

fn shadow_storage_recorded_commands() []PaintCommand {
	mut commands := []PaintCommand{}
	radii := BoxRadii{
		top_left: CornerRadius{10, 5}
		top_right: CornerRadius{20, 10}
		bottom_right: CornerRadius{30, 15}
		bottom_left: CornerRadius{40, 20}
	}
	paintable_box_paint_box_shadow(mut commands, [
		BoxShadow{offset_x: 1, offset_y: 2, blur: 3, spread: 2, color: css.Color{r: 200, a: 255}},
		BoxShadow{offset_x: 4, offset_y: 5, blur: 6, spread: 1, color: css.Color{b: 200, a: 255}, inset: true},
	], BoxEdges{top: 3, right: 3, bottom: 3, left: 3}, BoxColors{}, BoxBorderStyles{},
		radii, LayoutRect{10, 20, 114, 64}, LayoutRect{13, 23, 108, 58}, 0.75)
	return commands
}

fn test_ordinary_paint_commands_do_not_retain_box_shadow_geometry() {
	assert sizeof(PaintBoxShadowData) == 256
	assert sizeof(PaintCommand) <= 2140
	command := PaintCommand{kind: 'draw_text', text: 'ordinary text'}
	assert command.box_shadow_data == unsafe { nil }
	assert command.box_shadow().content_rect == LayoutRect{}
	assert command.box_shadow().inner_rect == LayoutRect{}
	assert command.box_shadow().content_radii == BoxRadii{}
	nested := paint_command_for_nested_viewport(command, [f64(1), 0, 0, 1, 7, 8]!, painting.IntPoint{10, 20}, 0.5)
	assert nested.box_shadow_data == unsafe { nil }
	assert nested.box_shadow().clip_radii == BoxRadii{}
}

fn test_shadow_geometry_survives_recording_scope_and_nested_replay_without_mutation() {
	commands := shadow_storage_recorded_commands()
	assert commands.len == 2
	for _ in 0 .. 3 {
		gc_collect()
		for command in commands {
			assert command.box_shadow_data != unsafe { nil }
			geometry := command.box_shadow()
			expected := if command.kind == 'paint_outer_box_shadow' {
				LayoutRect{10, 20, 114, 64}
			} else {
				LayoutRect{13, 23, 108, 58}
			}
			assert geometry.content_rect == expected
			assert geometry.content_radii.top_left != geometry.content_radii.bottom_left
			if command.kind == 'paint_inner_box_shadow' {
				assert geometry.inner_rect.width > 0
				assert geometry.inner_radii.top_right != geometry.inner_radii.bottom_right
			}
			nested := paint_command_for_nested_viewport(command, [f64(2), 0, 0, 3, 7, 8]!, painting.IntPoint{10, 20}, 0.5)
			assert nested.box_shadow_data == command.box_shadow_data
			assert nested.box_shadow() == geometry
			assert command.box_shadow() == geometry
			assert nested.opacity == command.opacity * 0.5
			assert nested.transform == [f64(2), 0, 0, 3, 27, 68]!
		}
	}
}

fn test_retained_shadow_payload_keeps_source_order_source_rectangles_and_svg_clips() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:100px;height:50px;padding:4px;border:3px solid black;border-radius:10px 20px 30px 40px / 5px 10px 15px 20px;background:rgb(0 200 0);box-shadow:1px 2px 3px 2px rgb(200 0 0),inset 4px 5px 6px 1px rgb(0 0 200)}</style><div id="target"></div>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 320, 200)
	commands := root.paint_commands()
	shadows := commands.filter(it.kind in ['paint_inner_box_shadow', 'paint_outer_box_shadow'])
	assert shadows.map(it.kind) == ['paint_inner_box_shadow', 'paint_outer_box_shadow']
	assert shadows[0].box_shadow().content_rect.width == 108
	assert shadows[0].box_shadow().content_rect.height == 58
	assert shadows[1].box_shadow().content_rect.width == 114
	assert shadows[1].box_shadow().content_rect.height == 64
	gc_collect()
	assert shadows[0].box_shadow_data != shadows[1].box_shadow_data
	svg := root.render_svg(320, 200)
	assert svg.contains('outer-shadow-clip')
	assert svg.contains('inner-shadow-scoped')
	assert svg.contains('fill-rule="evenodd"')
}
