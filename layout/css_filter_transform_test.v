module layout

import html
import math
import painting

fn test_css_shadow_offsets_follow_the_effect_transform_not_the_first_descendant() {
	for entry in [
		['rotate(-90deg)', '20', '0', '4'],
		['scale(2) rotate(90deg)', '-40', '0', '8'],
		['translate(123px,45px)', '0', '20', '4'],
	] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}svg{width:160px;height:80px;transform:${entry[0]};filter:drop-shadow(0 20px 4px red)}</style><svg viewBox="0 0 40 20"><g transform="scale(.5)"><rect width="40" height="20"/></g></svg>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		filters := commands.filter(it.kind == 'begin_css_filter_layer')
		assert filters.len == 1
		filter := filters[0].visual_layer().filter or { panic('filter') }
		assert filter.operations.len == 1
		shadow := filter.operations[0]
		assert math.abs(shadow.first - entry[1].f64()) < 1e-8
		assert math.abs(shadow.second - entry[2].f64()) < 1e-8
		assert math.abs(shadow.third - entry[3].f64()) < 1e-8
	}
}

fn test_css_filter_mapping_keeps_order_colors_and_the_retained_source() {
	filter := painting.GfxFilter{ operations: [
		painting.GfxFilterOperation{kind:'color',first:1.5},
		painting.GfxFilterOperation{kind:'drop-shadow',first:3,second:7,third:4,color:painting.Color{10,20,30,128}},
		painting.GfxFilterOperation{kind:'blur',first:2},
	] }
	mapped := compatibility_transformed_css_filter(filter, [f64(0),-2,2,0,123,456]!)
	assert mapped.operations[0] == filter.operations[0]
	assert mapped.operations[1].first == 14 && mapped.operations[1].second == -6
	assert mapped.operations[1].third == 8
	assert mapped.operations[1].color == filter.operations[1].color
	assert mapped.operations[2].first == 4
	assert filter.operations[1].first == 3 && filter.operations[1].second == 7
	assert filter.operations[1].third == 4 && filter.operations[2].first == 2
	for transform in [[f64(2),0,0,1,0,0]!, [f64(1),0,1,1,0,0]!, [6]f64{}] {
		assert compatibility_transformed_css_filter(filter, transform).operations == filter.operations
	}
}

fn test_css_filter_transform_updates_without_mutating_an_earlier_recording() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:80px;height:40px;filter:drop-shadow(5px 7px 4px red)}#target div{width:20px;height:10px;background:blue;transform:rotate(90deg)}</style><div id="target"><div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	first_commands := display_list_commands(document.record_display_list() or { panic('first paint') })
	first := first_commands.filter(it.kind == 'begin_css_filter_layer')[0].visual_layer().filter or { panic('first filter') }
	mut target := document.get_element_by_id('target') or { panic('target') }
	target.set_attribute_value('style', 'transform:rotate(-90deg)')
	document.update_layout(.dump_display_list)
	second_commands := display_list_commands(document.record_display_list() or { panic('second paint') })
	second := second_commands.filter(it.kind == 'begin_css_filter_layer')[0].visual_layer().filter or { panic('second filter') }
	assert math.abs(second.operations[0].first - 7) < 1e-8
	assert math.abs(second.operations[0].second + 5) < 1e-8
	assert first.operations[0].first == 5 && first.operations[0].second == 7
	assert first.operations[0].third == 4 && second.operations[0].third == 4
}
