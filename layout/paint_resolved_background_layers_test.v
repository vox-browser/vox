module layout

import css
import html

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

@[noinline]
fn resolved_paint_background_layer_count(properties &css.ComputedProperties) int {
	return resolved_background_layers_for_paint(properties).len
}

fn test_paint_uses_resolved_background_lists_without_reallocating_them() {
	mut document := html.parse_document('<!doctype html><div id="box" style="width:50px;height:20px;background-image:none,url(first.png),linear-gradient(red,blue);background-size:10px 20px,contain; background-position:right 3px bottom 7px,20% 30%;background-repeat:space round,no-repeat; background-clip:content-box,padding-box; background-origin:padding-box,content-box;background-attachment:scroll,fixed"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	element := document.get_element_by_id('box')?
	node := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	properties := unsafe { &css.ComputedProperties(node.computed_values()) }
	assert properties.computed_values_resolved_
	actual := resolved_background_layers_for_paint(properties)
	assert actual.len == 2
	assert actual == properties.background_layers()
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut layers := 0
	for _ in 0 .. 512 { layers += resolved_paint_background_layer_count(properties) }
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert layers == 1024
	assert allocated < 4096, 'resolved layer reads allocated ${allocated} bytes'
}

fn test_paint_background_lists_refresh_after_style_changes_and_keep_raw_property_fallback() {
	mut raw := css.ComputedProperties.new()
	for property_id, value in {
		css.PropertyID.background_image: 'url(raw.png),none'
		.background_attachment: 'scroll'
		.background_blend_mode: 'normal'
		.background_clip: 'border-box'
		.background_origin: 'padding-box'
		.background_position_x: '0%'
		.background_position_y: '0%'
		.background_repeat: 'repeat'
		.background_size: 'auto'
	} {
		raw.set_property(property_id, css.parse_css_value(css.ParsingParams{}, value, property_id)?, .no, .no)
	}
	assert !raw.computed_values_resolved_
	assert resolved_background_layers_for_paint(raw) == raw.background_layers()
	assert resolved_background_layers_for_paint(raw).len == 1
	mut document := html.parse_document('<!doctype html><div id="box" style="width:50px;height:20px;background:url(first.png) 25% 50% / 10px 20px no-repeat"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	mut element := document.get_element_by_id('box')?
	initial := display_list_commands(document.record_display_list()?).filter(it.kind == 'draw_background_image')[0].image().background_layer_data?
	for style in [
		'width:50px;height:20px;background-image:none,url(second.png);background-size:auto,contain;background-position:10% 20%,right 7px bottom 3px;background-repeat:space round,round no-repeat',
		'width:50px;height:20px;background-image:linear-gradient(blue,red),url(third.png);background-size:20px 30px;background-position:3px 9px;background-repeat:no-repeat',
	] {
		element.set_attribute_value('style', style)
		document.update_layout(.debugging)
		node := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
		properties := unsafe { &css.ComputedProperties(node.computed_values()) }
		assert resolved_background_layers_for_paint(properties) == properties.background_layers()
		current := (document.record_display_list()?).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list()?).dump() == current
	}
	assert initial.layer.position_x.to_string() == '25%'
	assert initial.layer.position_y.to_string() == '50%'
}
