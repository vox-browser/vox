module layout

import html

fn gradient_pattern_command(result DocumentLayoutResult) PaintCommand {
	for command in result.paint_tree.paint_commands() {
		if command.kind == 'fill_gradient' && command.gradient_background_layer {
			return command
		}
	}
	panic('missing generated background')
}

fn gradient_pattern_flag(command PaintCommand) bool {
	image := command.image_data
	if image == unsafe { nil } { panic('missing image payload') }
	data := image.background_layer_data or { panic('missing background geometry') }
	return data.gradient_pattern
}

fn test_chromium_generated_gradient_tile_covers_the_unsnapped_paint_area() {
	for geometry, expected in {
		'top:100px;width:583px;height:448.1875px':                        true
		'top:100px;width:583px;height:448px':                             false
		'top:100.4px;width:583px;height:448.2px':                         false
		'top:100px;width:583.1875px;height:448px':                        true
		'top:100.6px;width:583px;height:448.2px':                         true
		'top:100px;width:583px;height:448.1875px;border-radius:0':        false
		'top:100px;width:583px;height:448.1875px;border:none':            false
		'top:100px;width:583px;height:448.1875px;border-radius:.03125px': true
	} {
		for chromium in [true, false] {
			mut document := html.parse_document('<!doctype html><style>
				body{margin:0}.card{position:absolute;left:48px;box-sizing:border-box;
				border:1px solid;border-radius:10px;background:linear-gradient(135deg,#121b288f,#10151e8f);${geometry}}
			</style><div class="card"></div>')
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			result := run_document_layout(document, 1280, 800) or { panic('missing layout') }
			assert gradient_pattern_flag(gradient_pattern_command(result)) == (chromium && expected), geometry
		}
	}
}

fn test_gradient_pattern_choice_updates_when_the_snapped_size_is_unchanged() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}#card{position:absolute;top:100px;left:48px;width:583px;height:448.1875px;
		box-sizing:border-box;border:1px solid;border-radius:10px;background:linear-gradient(135deg,#121b288f,#10151e8f)}
	</style><div id="card"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	first := run_document_layout(document, 1280, 800) or { panic('missing first layout') }
	before := gradient_pattern_command(first)
	assert gradient_pattern_flag(before)
	mut card := document.get_element_by_id('card') or { panic('missing card') }
	card.set_attribute_for_bindings('style', 'height:448px')!
	second := run_document_layout(document, 1280, 800) or { panic('missing second layout') }
	after := gradient_pattern_command(second)
	assert before.width == after.width && before.height == after.height
	assert !gradient_pattern_flag(after)
	assert gradient_pattern_flag(before)
}
