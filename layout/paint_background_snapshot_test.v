module layout

import css
import html

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn background_snapshot_test_layer(font_size int) BackgroundImageLayer {
	mut context := css.LengthResolutionContext.default()
	context.font_metrics.font_size = css.CSSPixels.new(font_size)
	return BackgroundImageLayer{
		url: 'retained.png'
		computed_layer: css.BackgroundLayerData{
			position_x: css.LengthPercentage.from_length(css.Length.new(2, .em))
			position_y: css.LengthPercentage.from_percentage(css.Percentage.new(25))
			repeat_x: .no_repeat
			repeat_y: .no_repeat
		}
		resolution_context: context
	}
}

fn retained_background_snapshot_commands() []PaintCommand {
	return BlockBox{
		width: 100
		height: 50

		decoration_data: retained_block_box_decoration(BlockBoxDecorationData{
			background_images: [background_snapshot_test_layer(12)]
		})
	}.paint_commands()
}

fn test_common_paint_commands_do_not_embed_background_resolution_state() {
	assert sizeof(PaintCommand) <= 4200
	assert (PaintCommand{kind: 'draw_text', text: 'retained'}).image().background_layer_data == none
	assert (PaintCommand{kind: 'fill_rect'}).image().background_layer_data == none
}

fn test_background_snapshot_outlives_the_box_and_preserves_font_relative_resolution() {
	commands := retained_background_snapshot_commands()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		image := commands.filter(it.kind == 'draw_background_image')[0]
		data := image.image().background_layer_data or { panic('missing retained background') }
		assert data.layer.position_x.to_px(data.resolution_context, css.CSSPixels.new(100)) == css.CSSPixels.new(24)
		assert data.layer.position_y.to_px(data.resolution_context, css.CSSPixels.new(100)) == css.CSSPixels.new(25)
	}
}

fn test_replacing_background_source_preserves_earlier_recordings() {
	mut box := BlockBox{
		width: 100
		height: 50

		decoration_data: retained_block_box_decoration(BlockBoxDecorationData{
			background_images: [background_snapshot_test_layer(12)]
		})
	}
	old_commands := box.paint_commands()
	box.decoration_data = retained_block_box_decoration(BlockBoxDecorationData{
		...*box.decorations()
		background_images: [background_snapshot_test_layer(20)]
	})
	new_commands := box.paint_commands()
	old_data := old_commands.filter(it.kind == 'draw_background_image')[0].image().background_layer_data or { panic('missing old background') }
	new_data := new_commands.filter(it.kind == 'draw_background_image')[0].image().background_layer_data or { panic('missing new background') }
	assert voidptr(old_data) != voidptr(new_data)
	assert old_data.layer.position_x.to_px(old_data.resolution_context, css.CSSPixels.new(100)) == css.CSSPixels.new(24)
	assert new_data.layer.position_x.to_px(new_data.resolution_context, css.CSSPixels.new(100)) == css.CSSPixels.new(40)
}

fn test_background_cache_and_display_list_replays_share_one_snapshot() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{width:100px;height:50px;background:url(retained.png) no-repeat 25% 50%}</style><div>retained text</div>')
	_ = layout_document_typed_in_viewport(document, 320, 100)
	first := display_list_commands(document.record_display_list() or { panic('missing first recording') })
	first_data := first.filter(it.kind == 'draw_background_image')[0].image().background_layer_data or { panic('missing first snapshot') }
	document.set_needs_repaint_with_invalidation(.paint_commands)
	second := display_list_commands(document.record_display_list() or { panic('missing replay') })
	second_data := second.filter(it.kind == 'draw_background_image')[0].image().background_layer_data or { panic('missing second snapshot') }
	assert voidptr(first_data) == voidptr(second_data)
	assert first_data.layer.position_x.to_string() == '25%'
	assert first_data.layer.position_y.to_string() == '50%'
}
