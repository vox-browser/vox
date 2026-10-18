module layout

import html

fn test_retained_inline_flow_survives_new_anonymous_block_wrapping() {
	mut document := html.parse_document('<!doctype html><div id="parent"><span id="stable">prefix <strong>label</strong><br>suffix</span><i id="changed">old</i></div>')
	_ = layout_document_typed_in_viewport(document, 400, 300)
	stable := document.get_element_by_id('stable')?
	before := stable.as_node().unsafe_layout_node()?.real_layout_handle()
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('updated')!
	document.update_layout(.debugging)
	assert stable.as_node().unsafe_layout_node()?.real_layout_handle() == before
	mut parent := document.get_element_by_id('parent')?.as_node()
	block := document.create_element('p')!
	parent.pre_insert(block.as_node(), changed.as_node())!
	document.update_layout(.debugging)
	assert stable.as_node().unsafe_layout_node()?.real_layout_handle() == before
	paint := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == paint
}

fn test_retained_flow_handles_flat_list_and_timestamp_markup_without_list_markers() {
	mut document := html.parse_document('<!doctype html><style>li{display:inline}</style><div id="changed"></div><ul id="list"><li><a>reply</a><time>one minute ago</time></li><li><a>expand</a></li></ul>')
	_ = layout_document_typed_in_viewport(document, 400, 300)
	list := document.get_element_by_id('list')?
	before := list.as_node().unsafe_layout_node()?.real_layout_handle()
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>new branch</p>')!
	document.update_layout(.debugging)
	assert list.as_node().unsafe_layout_node()?.real_layout_handle() == before
	paint := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == paint
}
