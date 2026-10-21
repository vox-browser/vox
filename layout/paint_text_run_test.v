module layout

import css
import math
import painting

fn test_paint_text_run_is_joined_once_in_linear_order() {
	fragment_count := 2048
	mut fragments := []TextFragment{cap: fragment_count}
	for index in 0 .. fragment_count {
		fragments << TextFragment{
			x: f64(index * 2)
			y: 1
			width: 1
			height: 10
			text: 'x'
			text_run_id: 1
			shape_as_run: true
			separator_after: if index + 1 < fragment_count { ' ' } else { '' }
			separator_width_after: 1
		}
	}
	box := BlockBox{
		lines: [TextLine{
			fragments: fragments
		}]
	}
	text_commands := box.paint_commands().filter(it.kind == 'draw_text')
	assert text_commands.len == 1
	assert text_commands[0].text == 'x '.repeat(fragment_count - 1) + 'x'
}

fn test_paint_stacking_context_sort_uses_z_index_then_tree_order() {
	context_count := 2048
	mut children := []BlockBox{cap: context_count + 2}
	for index in 0 .. context_count {
		children << BlockBox{
			node_id: i64(index + 1)
			z_index: context_count - index
			z_index_auto: false
			stacking_context: true
		}
	}
	children << BlockBox{
		node_id: i64(context_count + 1)
		z_index: context_count + 1
		z_index_auto: false
		stacking_context: true
	}
	children << BlockBox{
		node_id: i64(context_count + 2)
		z_index: context_count + 1
		z_index_auto: false
		stacking_context: true
	}
	root := BlockBox{
		children: children
	}
	order := root.paint_order()
	assert order.len == context_count + 3
	assert order[1].z_index == 1
	assert order[context_count].z_index == context_count
	assert order[context_count + 1].node_id == context_count + 1
	assert order[context_count + 2].node_id == context_count + 2
}

fn phase_test_box(color css.Color) BlockBox {
	return BlockBox{
		width: 10
		height: 10
		background_color: color
	}
}

fn test_paint_commands_follow_stacking_context_phase_order() {
	mut negative := phase_test_box(css.Color{0, 128, 0, 255})
	negative.z_index = -1
	negative.z_index_auto = false
	negative.stacking_context = true

	mut normal := phase_test_box(css.Color{255, 0, 0, 255})
	normal.lines = [TextLine{
		fragments: [TextFragment{
			text: 'normal foreground'
			color: css.Color{128, 0, 128, 255}
		}]
	}]

	mut zero := phase_test_box(css.Color{0, 0, 255, 255})
	zero.positioned = true

	mut positive := phase_test_box(css.Color{255, 255, 0, 255})
	positive.z_index = 1
	positive.z_index_auto = false
	positive.stacking_context = true

	root := BlockBox{
		width: 20
		height: 20
		background_color: css.Color{255, 255, 255, 255}
		outline_width: 1
		outline_color: css.Color{0, 0, 0, 255}
		lines: [TextLine{
			fragments: [TextFragment{
				text: 'root foreground'
				color: css.Color{0, 255, 255, 255}
			}]
		}]
		children: [negative, normal, zero, positive]
	}

	commands := root.paint_commands()
	assert commands[..7].map('${it.kind}:${it.color}') == [
		'fill_rect:rgb(255 255 255)',
		'fill_rect:rgb(0 128 0)',
		'fill_rect:rgb(255 0 0)',
		'draw_text:rgb(0 255 255)',
		'draw_text:rgb(128 0 128)',
		'fill_rect:rgb(0 0 255)',
		'fill_rect:rgb(255 255 0)',
	]
	assert commands[7..].len == 1
	assert commands[7].kind == 'draw_svg_path' && commands[7].color == 'rgb(0 0 0)'
}

fn test_paint_commands_separate_block_float_and_inline_background_phases() {
	mut inline_box := phase_test_box(css.Color{0, 255, 255, 255})
	inline_box.inline_or_replaced = true
	mut float_box := phase_test_box(css.Color{255, 0, 255, 255})
	float_box.floating = true
	block_box := phase_test_box(css.Color{255, 0, 0, 255})
	root := BlockBox{
		background_color: css.Color{0, 0, 0, 0}
		children: [inline_box, float_box, block_box]
	}
	colors := root.paint_commands().filter(it.kind == 'fill_rect').map(it.color)
	assert colors == ['rgb(255 0 0)', 'rgb(255 0 255)', 'rgb(0 255 255)']
}

fn test_noninvertible_and_zero_opacity_stacking_contexts_do_not_paint() {
	noninvertible := BlockBox{
		width: 10
		height: 10
		background_color: css.Color{255, 0, 0, 255}
		stacking_context: true
		paint_transform: [f64(0), 0, 0, 1, 0, 0]!
	}
	transparent := BlockBox{
		width: 10
		height: 10
		background_color: css.Color{0, 0, 255, 255}
		stacking_context: true
		opacity: 0
	}
	root := BlockBox{
		background_color: css.Color{0, 0, 0, 0}
		children: [noninvertible, transparent]
	}
	assert root.paint_commands().len == 0
}

fn test_scrollbar_overlay_uses_translated_geometry_and_paints_after_outline() {
	root := BlockBox{
		x: 10
		y: 10
		width: 100
		height: 100
		background_color: css.Color{0, 0, 0, 0}
		outline_width: 1
		outline_color: css.Color{0, 0, 0, 255}
		overlay: &CompatibilityOverlayData{
			scrollable_overflow: LayoutRect{10, 10, 100, 300}
			scroll_offset_y: 60
			can_scroll_vertically: true
			scrollbar_width: .auto_
			scrollbar_thumb_color: css.Color{64, 64, 64, 192}
			scrollbar_track_color: css.Color{212, 208, 200, 192}
		}
	}
	commands := root.paint_commands()
	assert commands.len == 3
	assert commands[0].kind == 'draw_svg_path' && commands[0].color == 'rgb(0 0 0)'
	thumb := commands[1]
	assert thumb.kind == 'fill_rounded_rect'
	assert math.abs(thumb.x - 102.0) < 0.001
	// Scrollbar geometry crosses the recorder boundary in device pixels.
	assert math.abs(thumb.y - 31.0) < 0.001
	assert math.abs(thumb.width - 6.0) < 0.001
	assert math.abs(thumb.height - 32.0) < 0.001
	assert thumb.color == css.Color{64, 64, 64, 192}.serialize()
	assert commands[2].kind == 'stroke_rounded_rect'
}

fn test_scrollbar_width_none_suppresses_scrollbars_but_not_resizer() {
	without_resizer := BlockBox{
		width: 100
		height: 100
		background_color: css.Color{0, 0, 0, 0}
		overlay: &CompatibilityOverlayData{
			scrollable_overflow: LayoutRect{0, 0, 100, 300}
			can_scroll_vertically: true
			scrollbar_width: .none_
		}
	}
	assert without_resizer.paint_commands().len == 0

	with_resizer := BlockBox{
		width: 100
		height: 100
		background_color: css.Color{0, 0, 0, 0}
		overlay: &CompatibilityOverlayData{
			scrollable_overflow: LayoutRect{0, 0, 100, 100}
			scrollbar_width: .none_
			has_resizer: true
		}
	}
	resizer := with_resizer.paint_commands()
	assert resizer.len == 8
	assert resizer.all(it.kind == 'draw_line')
	assert resizer[0].points == [f64(96), 97, 97, 96]
	assert resizer[1].points == [f64(95), 97, 97, 95]
}

fn test_scrollbar_overlay_paints_vertical_before_horizontal() {
	root := BlockBox{
		width: 100
		height: 80
		background_color: css.Color{0, 0, 0, 0}
		overlay: &CompatibilityOverlayData{
			scrollable_overflow: LayoutRect{0, 0, 300, 240}
			can_scroll_horizontally: true
			can_scroll_vertically: true
			scrollbar_thumb_color: css.Color{64, 64, 64, 192}
			scrollbar_track_color: css.Color{212, 208, 200, 192}
		}
	}
	commands := root.paint_commands()
	assert commands.len == 4
	vertical := commands[0]
	assert vertical.kind == 'fill_rounded_rect'
	assert math.abs(vertical.x - 92.0) < 0.001
	assert math.abs(vertical.width - 6.0) < 0.001
	horizontal := commands[2]
	assert horizontal.kind == 'fill_rounded_rect'
	assert math.abs(horizontal.y - 72.0) < 0.001
	assert math.abs(horizontal.height - 6.0) < 0.001
}

fn test_viewport_scrollbar_painting_can_be_disabled_without_hiding_element_scrollbars() {
	overlay := CompatibilityOverlayData{
		scrollable_overflow: LayoutRect{0, 0, 100, 300}
		can_scroll_vertically: true
		scrollbar_thumb_color: css.Color{64, 64, 64, 192}
		scrollbar_track_color: css.Color{212, 208, 200, 192}
	}
	viewport := BlockBox{
		width: 100
		height: 100
		background_color: css.Color{0, 0, 0, 0}
		is_viewport_scroller: true
		overlay: &overlay
	}
	element := BlockBox{
		width: 100
		height: 100
		background_color: css.Color{0, 0, 0, 0}
		overlay: &overlay
	}

	painting.set_paint_viewport_scrollbars(false)
	assert !painting.should_paint_viewport_scrollbars()
	assert viewport.paint_commands().len == 0
	assert element.paint_commands().len == 2

	painting.set_paint_viewport_scrollbars(true)
	assert painting.should_paint_viewport_scrollbars()
	assert viewport.paint_commands().len == 2
}

fn test_root_overlay_paints_after_positive_stacking_context() {
	mut positive := phase_test_box(css.Color{255, 0, 0, 255})
	positive.z_index = 1
	positive.z_index_auto = false
	positive.stacking_context = true
	root := BlockBox{
		width: 100
		height: 100
		background_color: css.Color{0, 0, 0, 0}
		children: [positive]
		overlay: &CompatibilityOverlayData{
			scrollable_overflow: LayoutRect{0, 0, 100, 300}
			can_scroll_vertically: true
			scrollbar_thumb_color: css.Color{64, 64, 64, 192}
			scrollbar_track_color: css.Color{212, 208, 200, 192}
		}
	}
	commands := root.paint_commands()
	assert commands[0].color == 'rgb(255 0 0)'
	assert commands[1].kind == 'fill_rounded_rect'
	assert commands[2].kind == 'stroke_rounded_rect'
}
