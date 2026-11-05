module layout

import html

fn flat_perspective_test_layer_count(transform string, ancestor_transform string, nested bool) int {
	inner_style := if nested { 'perspective:500px' } else { '' }
	mut document := html.parse_document('<!doctype html><style>
		html,body{margin:0}.outside{${ancestor_transform}}
		.stage{perspective:999px}.nested{${inner_style}}
		.hint{will-change:transform;width:160px;height:100px;transform:${transform}}
		.child{width:80px;height:40px;background:rgb(4 5 6)}
		.scroll{width:100px;height:30px;overflow:auto}
		.wide{width:400px;height:30px;background:rgb(1 2 3)}
	</style><div class="outside"><div class="stage"><div class="nested"><div class="hint"><div class="child"></div></div></div></div></div><div class="scroll"><div class="wide"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document,300,240)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	assert commands.any(it.color == 'rgb(4 5 6)')
	plan := chromium_raster_layer_plan(document,commands,1)
	return plan.layers.len
}

fn test_flat_perspective_preserves_independent_compositor_and_scroll_layers() {
	for transform in ['none','translate3d(0,0,0)','translate3d(4px,7px,0)',
		'scaleZ(2)','rotateY(0deg)'] {
		assert flat_perspective_test_layer_count(transform,'',false) > 1, transform
	}
}

fn test_perspective_with_depth_transforms_retains_the_root_raster_fallback() {
	for transform in ['translateZ(1px)','translate3d(0,0,1px)','rotateY(7deg)','rotateX(-5deg)'] {
		assert flat_perspective_test_layer_count(transform,'',false) == 1, transform
	}
}

fn test_perspective_under_a_depth_transformed_ancestor_stays_conservative() {
	for transform in ['transform:translateZ(1px)','transform:rotateY(7deg)'] {
		assert flat_perspective_test_layer_count('none',transform,false) == 1, transform
	}
}

fn test_nested_perspective_retains_its_existing_raster_fallback() {
	assert flat_perspective_test_layer_count('none','',true) == 1
}

fn test_perspective_raster_scratch_resets_between_depth_and_flat_documents() {
	for _ in 0 .. 3 {
		assert flat_perspective_test_layer_count('translateZ(1px)','',false) == 1
		assert flat_perspective_test_layer_count('none','',false) > 1
	}
}
