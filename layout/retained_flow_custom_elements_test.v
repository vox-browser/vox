module layout

import dom
import html

fn custom_flow_handle(element &dom.Element) voidptr {
	return element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()
}

fn custom_flow_check_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

fn test_clean_autonomous_custom_elements_keep_their_boxes_across_rebuilds() {
	mut document := html.parse_document('<!doctype html><style>relative-time{display:inline}file-row{display:block}</style><div id="changed"></div><section id="stable">' +
		'<file-row><span>name</span> <relative-time>3 days ago</relative-time> <kbd>k</kbd> <label>l</label></file-row>'.repeat(8) + '</section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	for index in 0 .. 3 {
		before := custom_flow_handle(stable)
		mut changed := document.get_element_by_id('changed')?
		changed.set_inner_html('<p>new branch ${index}</p>')!
		document.update_layout(.debugging)
		assert custom_flow_handle(stable) == before
		recording := document.record_display_list()?
		commands := display_list_commands(recording)
		assert commands.any(it.kind == 'draw_text' && it.text.contains('days'))
		assert commands.any(it.kind == 'draw_text' && it.text.contains('new branch ${index}'))
	}
	custom_flow_check_full_rebuild(mut document)
}

fn test_custom_element_display_change_rebuilds_its_box() {
	mut document := html.parse_document('<!doctype html><style>.block{display:block}</style><div id="changed"></div><section id="stable"><relative-time id="time">3 days ago</relative-time></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut time := document.get_element_by_id('time')?
	before := custom_flow_handle(time)
	time.set_attribute_value('class', 'block')
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new branch</p>')!
	document.update_layout(.debugging)
	after := custom_flow_handle(time)
	assert after != before
	assert unsafe { &Node(after) }.display().is_block_outside()
	custom_flow_check_full_rebuild(mut document)
}

fn test_custom_element_with_shadow_root_is_rebuilt() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable"><tool-tip id="tip">hint</tool-tip></section>')
	defer { document.finalize() }
	mut tip := document.get_element_by_id('tip')?
	_ = tip.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert !retained_flow_element_name_is_generic('button')
	assert retained_flow_element_name_is_generic('tool-tip')
	mut rejected := map[u64]bool{}
	assert reusable_clean_flow_subtree(tip, mut rejected) == none
}
