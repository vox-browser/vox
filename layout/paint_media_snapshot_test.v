module layout

import css
import dom
import painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn retained_media_snapshot_commands() []PaintCommand {
	box := BlockBox{
		width:                    100
		height:                   50

		media_data: retained_block_box_media(BlockBoxMediaData{
			replaced_image_url:       'retained.png'
			replaced_image_paintable: &painting.ImagePaintable{
			image_rect:      painting.Rect{10, 20, 100, 50}
			object_fit:      .contain
			object_position: css.Position{
				offset_x: css.LengthPercentage.from_percentage(css.Percentage.new(25))
				offset_y: css.LengthPercentage.from_percentage(css.Percentage.new(75))
			}
		}
			canvas_bitmap:            &dom.Bitmap_{
			width:  1
			height: 1
			pitch:  4
			data:   [u8(1), 2, 3, 255]
		}
			canvas_paintable:         &painting.CanvasPaintable{
			canvas_rect: painting.Rect{30, 40, 100, 50}
		}
			video_representation:     .transparent_black
			video_paintable:          &painting.VideoPaintable{
			video_rect:         painting.Rect{50, 60, 100, 50}
			natural_media_size: painting.IntSize{20, 10}
		}
		})
	}
	mut commands := box.paint_commands()
	commands << PaintCommand{
		kind:                      'paint_nested_display_list'
		nested_viewport_paintable: &painting.NavigableContainerViewportPaintable{
			viewport_rect: painting.Rect{70, 80, 100, 50}
			nested_rect:   painting.Rect{75, 85, 90, 40}
		}
	}
	return commands
}

fn test_common_layout_boxes_and_paint_commands_keep_media_geometry_out_of_line() {
	// Catch accidental reintroduction of the four inline media payloads.
	assert sizeof(PaintCommand) <= 4600
	assert sizeof(BlockBox) <= 5400
	box := BlockBox{}
	assert box.media().replaced_image_paintable == none
	assert box.media().canvas_paintable == none
	assert box.media().video_paintable == none
	assert box.media().nested_viewport_paintable == none
	command := PaintCommand{
		kind: 'draw_text'
		text: 'no media'
	}
	assert command.image_paintable == none
	assert command.canvas_paintable == none
	assert command.video_paintable == none
	assert command.nested_viewport_paintable == none
}

fn test_media_command_snapshots_survive_collection_and_replay_geometry() {
	commands := retained_media_snapshot_commands()
	$if gcboehm ? { C.GC_gcollect() }
	converter := painting.new_device_pixel_converter(1) or { panic(err) }
	image_command := commands.filter(it.kind == 'draw_replaced_image')[0]
	image := image_command.image_paintable or { panic('missing image snapshot') }
	assert image.object_position.offset_x.to_string() == '25%'
	assert image.object_position.offset_y.to_string() == '75%'
	painted_image := image.paint('retained.png', painting.IntRect{0, 0, 20, 10}, converter) or {
		panic('missing image replay')
	}
	assert painted_image.bitmap.destination == painting.IntRect{10, 20, 100, 50}
	canvas_command := commands.filter(it.kind == 'draw_canvas')[0]
	canvas := canvas_command.canvas_paintable or { panic('missing canvas snapshot') }
	bitmap := canvas_command.canvas_bitmap or { panic('missing retained bitmap') }
	assert bitmap.data == [u8(1), 2, 3, 255]
	painted_canvas := canvas.paint('canvas', painting.IntSize{1, 1}, converter) or {
		panic('missing canvas replay')
	}
	assert painted_canvas.content.destination == painting.IntRect{30, 40, 100, 50}
	video_command := commands.filter(it.kind == 'draw_video')[0]
	video := video_command.video_paintable or { panic('missing video snapshot') }
	assert video.natural_media_size? == painting.IntSize{20, 10}
	painted_video := video.paint(.transparent_black, '', none, none, converter) or {
		panic('missing video replay')
	}
	assert painted_video.clip_rect == painting.IntRect{50, 60, 100, 50}
	nested := commands.last().nested_viewport_paintable or { panic('missing nested snapshot') }
	painted_nested := nested.paint(converter) or { panic('missing nested replay') }
	assert painted_nested.clip_rect == painting.IntRect{70, 80, 100, 50}
	assert painted_nested.nested_rect == painting.IntRect{75, 85, 90, 40}
}

fn test_image_command_owns_geometry_across_source_replacement() {
	mut source := BlockBox{
		width:                    100
		height:                   50

		media_data: retained_block_box_media(BlockBoxMediaData{
			replaced_image_url:       'old.png'
			replaced_image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{1, 2, 100, 50}
		}
		})
	}
	old_commands := source.paint_commands()
	retained_geometry := source.media().replaced_image_paintable or { panic('missing source image') }
	source.media_data = retained_block_box_media(BlockBoxMediaData{
		...*source.media()
		replaced_image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{3, 4, 200, 80}
		}
	})
	new_commands := source.paint_commands()
	old_image := old_commands.filter(it.kind == 'draw_replaced_image')[0].image_paintable or {
		panic('missing old image')
	}

	new_image := new_commands.filter(it.kind == 'draw_replaced_image')[0].image_paintable or {
		panic('missing new image')
	}

	assert old_image == retained_geometry
	assert new_image != old_image
	assert old_image.image_rect == painting.Rect{1, 2, 100, 50}
	assert new_image.image_rect == painting.Rect{3, 4, 200, 80}
}
