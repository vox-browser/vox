module layout

import dom
import html

fn retained_flow_handle(element &dom.Element) voidptr {
	return element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()
}

fn retained_flow_check_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing full paint') }).dump() == before
}

fn test_clean_comment_flow_branches_keep_boxes_text_and_dom_boundaries() {
	mut document := html.parse_document(
		'<!doctype html><style>.collapsed .body{display:none}</style>
	<div id="changed" class="collapsed"><a id="toggle">expand</a><p class="body">revealed</p></div>
	<section id="stable">' +
		'<div><p>unchanged <strong>comment</strong></p></div>'.repeat(96) + '</section>')
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	for class_name in ['', 'collapsed', ''] {
		before := retained_flow_handle(stable)
		mirror := stable.as_node().unsafe_layout_node()?
		mut changed := document.get_element_by_id('changed')?
		changed.set_attribute_value('class', class_name)
		mut toggle := document.get_element_by_id('toggle')?
		toggle.set_inner_html(if class_name == '' { 'collapse' } else { 'expand' })!
		document.update_layout(.event_handler_handle_mouse_up)
		assert retained_flow_handle(stable) == before
		assert voidptr(stable.as_node().unsafe_layout_node()?) == voidptr(mirror)
		commands := display_list_commands(document.record_display_list()?)
		assert commands.any(it.kind == 'draw_text' && it.text == 'revealed') == (class_name == '')
		retained_flow_check_full_rebuild(mut document)
		assert retained_flow_handle(stable) != before
	}
}

fn test_retained_flow_tracks_inherited_paint_and_reparented_geometry() {
	mut document :=
		html.parse_document('<!doctype html><div id="changed"></div><section id="left" style="width:300px"><div id="stable"><strong>inherited</strong></div></section><section id="right" style="width:100px"></section>')
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	before := retained_flow_handle(stable)
	mut left := document.get_element_by_id('left')?
	left.set_attribute_value('style', 'width:300px;color:red')
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new branch</p>')!
	document.update_layout(.debugging)
	assert retained_flow_handle(stable) == before
	commands := display_list_commands(document.record_display_list()?)
	assert commands.any(it.kind == 'draw_text' && it.text == 'inherited'
		&& it.color == 'rgb(255 0 0)')
	mut right := document.get_element_by_id('right')?
	mut right_node := right.as_node()
	right_node.append_child(stable.as_node())!
	document.update_layout(.debugging)
	assert retained_flow_handle(stable) != before
	assert stable.get_bounding_client_rect().width == 100
	retained_flow_check_full_rebuild(mut document)
}

fn test_retained_flow_replays_counter_order_before_generated_following_content() {
	mut document :=
		html.parse_document('<!doctype html><style>body{counter-reset:n}.count{counter-increment:n}#result::before{content:counter(n)}</style><div id="stable" class="count"><p>retained</p></div><div id="changed" class="count"></div><div id="result"></div>')
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	before := retained_flow_handle(stable)
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p class="count">new counter</p>')!
	document.update_layout(.debugging)
	assert retained_flow_handle(stable) == before
	commands := display_list_commands(document.record_display_list()?)
	assert commands.any(it.kind == 'draw_text' && it.text == '3')
	retained_flow_check_full_rebuild(mut document)
}

fn test_retained_flow_keeps_special_subtrees_on_the_complete_builder_path() {
	for content in [
		'<ol><li>list marker</li></ol>',
		'<svg width="10" height="10"><rect width="10" height="10" fill="red"/></svg>',
		'<span class="generated">pseudo</span>',
		'<input value="control">',
	] {
		mut document := html.parse_document(
			'<!doctype html><style>.generated::before{content:"before"}</style><div id="changed"></div><div id="special">' +
			content + '</div>')
		_ = layout_document_typed_in_viewport(document, 400, 300)
		special := document.get_element_by_id('special')?
		before := retained_flow_handle(special)
		mut changed := document.get_element_by_id('changed')?
		changed.set_inner_html('<p>new</p>')!
		document.update_layout(.debugging)
		assert retained_flow_handle(special) != before
		retained_flow_check_full_rebuild(mut document)
	}
}

fn test_clean_action_forms_retain_flow_boxes_and_rebuild_when_their_content_changes() {
	mut document := html.parse_document('<!doctype html><style>.closed p{display:none}form{display:inline}li{display:inline}</style><div id="changed" class="closed"><p>expanded</p></div><section id="stable"><ul><li><form id="action"><input type="hidden" value="token"><span><a>save</a></span></form></li><li><a>reply</a></li></ul><p>comment body</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	mut action := document.get_element_by_id('action')?
	mut changed := document.get_element_by_id('changed')?
	for class_name in ['', 'closed', ''] {
		before := retained_flow_handle(stable)
		form_before := retained_flow_handle(action)
		changed.set_attribute_value('class', class_name)
		document.update_layout(.debugging)
		assert retained_flow_handle(stable) == before
		assert retained_flow_handle(action) == form_before
		retained_flow_check_full_rebuild(mut document)
	}
	before := retained_flow_handle(stable)
	action.set_inner_html('<span>updated action</span>')!
	document.update_layout(.debugging)
	assert retained_flow_handle(stable) != before
	assert display_list_commands(document.record_display_list()?).any(it.text == 'updated action')
	retained_flow_check_full_rebuild(mut document)
}

fn test_forms_with_rendered_controls_keep_the_complete_builder_path() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable"><form><input value="editable"><button>submit</button></form></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	before := retained_flow_handle(stable)
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new preceding content</p>')!
	document.update_layout(.debugging)
	assert retained_flow_handle(stable) != before
	retained_flow_check_full_rebuild(mut document)
}
