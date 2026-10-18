module layout

import html

fn test_paint_tree_queue_keeps_wide_sibling_storage_and_nested_geometry_live() {
	mut markup := []string{}
	for index in 0 .. 128 {
		markup << '<section id="tile${index}" class="tile"><span id="left${index}">L${index}</span><span id="right${index}">R${index}</span></section>'
	}
	mut document := html.parse_document('<!doctype html><style>html,body,main,section{margin:0;padding:0}.tile{width:120px;height:32px;transform:translateX(2px)}span{display:block;height:16px}</style><main id="host">${markup.join('')}</main>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 320, 240)
	gc_collect()
	host := document.get_element_by_id('host') or { panic('missing host') }
	parent := root.find_box(i64(host.as_node().unique_id())) or { panic('missing host box') }
	assert parent.children.len == 128
	assert parent.children.cap == 128
	// Growing the work queue must not move any already-enqueued child boxes.
	for index in 0 .. 128 {
		tile := document.get_element_by_id('tile${index}') or { panic('missing tile') }
		left := document.get_element_by_id('left${index}') or { panic('missing left') }
		right := document.get_element_by_id('right${index}') or { panic('missing right') }
		box := parent.children[index]
		assert box.node_id == i64(tile.as_node().unique_id())
		assert box.width == 120
		assert box.height == 32
		assert box.paint_transform[4] == 2
		assert box.children.len == 2
		assert box.children.cap == 2
		assert box.children[0].node_id == i64(left.as_node().unique_id())
		assert box.children[1].node_id == i64(right.as_node().unique_id())
		assert box.children[0].width == 120
		assert box.children[0].height == 16
		assert box.children[0].lines.len == 1
		assert box.children[0].lines[0].fragments.any(it.text == 'L${index}')
		assert box.children[1].lines[0].fragments.any(it.text == 'R${index}')
	}
	// The arena plan holds one node pointer and compact child/parent indexes;
	// it must not retain another wide BlockBox per paint node.
	assert sizeof(TypedPaintArenaEntry) <= sizeof(voidptr) + 4 * sizeof(int)
}

fn test_paint_tree_final_storage_preserves_unboxed_order_and_previous_snapshots() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:120px;height:20px}#wrapper{display:contents}#hidden{display:none}</style><div id="wrapper"><div id="target"><span id="text">before</span></div></div><div id="hidden">hidden</div>')
	defer { document.finalize() }
	old_root := layout_document_typed_in_viewport(document, 320, 240)
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	text := document.get_element_by_id('text') or { panic('missing text') }
	wrapper := document.get_element_by_id('wrapper') or { panic('missing wrapper') }
	hidden := document.get_element_by_id('hidden') or { panic('missing hidden') }
	identity := i64(target.as_node().unique_id())
	previous := old_root.find_box(identity) or { panic('missing old target') }
	old_commands := old_root.paint_commands()
	assert previous.width == 120
	assert old_root.find_box(i64(wrapper.as_node().unique_id())) == none
	assert old_root.find_box(i64(hidden.as_node().unique_id())) == none
	assert old_commands.any(it.text == 'before')
	target.set_attribute_value('style', 'width:200px')
	mut text_node := text.as_node()
	text_node.set_text_content('after') or { panic(err) }
	new_root := layout_document_typed_in_viewport(document, 320, 240)
	gc_collect()
	updated := new_root.find_box(identity) or { panic('missing updated target') }
	assert updated.width == 200
	assert previous.width == 120
	assert (old_root.find_box(identity) or { panic('lost retained target') }).width == 120
	assert old_commands.any(it.text == 'before')
	assert !old_commands.any(it.text == 'after')
	assert new_root.paint_commands().any(it.text == 'after')
}
