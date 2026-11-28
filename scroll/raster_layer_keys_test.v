module main

import layout

fn raster_layer_key_commands() []layout.PaintCommand {
	return [layout.PaintCommand{kind: 'fill_rect', x: 0, y: 0, width: 100, height: 20, color: 'red'},
		layout.PaintCommand{kind: 'fill_rect', x: 10, y: 40, width: 80, height: 20, color: 'blue'}]
}

fn raster_layer_keys(plan layout.ChromiumRasterLayerPlan) []ScrollRasterCommandKey {
	mut app := BrowserApp{
		paint_commands:       raster_layer_key_commands()
		chromium_raster_plan: plan
	}
	mut keys := scroll_raster_frame_keys(app.paint_commands, 0, 1, 1024, 768)
	app.mix_raster_layer_keys(mut keys)
	return keys
}

// A command that moves from a composited raster layer back to the root layer
// changes its retained-raster key; one that stays in the root layer keeps it.
fn test_moving_between_raster_layers_changes_the_command_key() {
	root := layout.ChromiumRasterLayer{bounds: layout.LayoutRect{0, 0, 1024, 768}}
	composited := layout.ChromiumRasterLayer{bounds: layout.LayoutRect{10.5, 40.25, 80, 20},
		composited_contents: true}
	split := raster_layer_keys(layout.ChromiumRasterLayerPlan{layers: [root, composited],
		command_layers: [0, 1]})
	merged := raster_layer_keys(layout.ChromiumRasterLayerPlan{layers: [root],
		command_layers: [0, 0]})
	assert split[0].hash == merged[0].hash
	assert (split[1].hash != merged[1].hash) == !retain_layer_blind_raster_keys
}
