module main

import html
import layout
import os

fn test_complete_root_picture_keeps_inset_shadows_with_other_decorations() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/Tests/Browser/Brave/diagnostic/inset-rounded-box-shadow.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := layout.chromium_raster_layer_plan(document, commands, 1)
	assert plan.layers.len == 1
	assert chromium_shared_recording_supported(commands, plan)
	shadows := commands.filter(it.kind == 'paint_inner_box_shadow')
	assert shadows.len == 3
	for shadow in shadows {
		supported, _ := chromium_shared_recording_leaf_supported(&shadow)
		assert supported
		missing := layout.PaintCommand{ ...shadow, box_shadow_data: unsafe { nil } }
		accepted, _ := chromium_shared_recording_leaf_supported(&missing)
		assert !accepted
	}
}
