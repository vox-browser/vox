module layout

import html

fn test_item_paint_projection_reuses_geometry_and_keeps_published_scenes_immutable() {
	for display in ['grid', 'flex'] {
		mut document := html.parse_document('<!doctype html><style>
			#parent{display:${display};width:300px;gap:10px;align-items:start}
			#target{width:100px;padding:4px;border:2px solid blue;border-radius:4px;
			outline:1px solid red;box-shadow:1px 2px 3px gray}
		</style><div id="changed"></div><div id="parent"><section id="target">Text</section></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		old := document.record_display_list()?
		retained := retain_display_list_scene(old)
		commands := display_list_commands(old).clone()
		node := ordinary_projection_test_node(document, 'target')
		ordinary_projection_test_compare(document, 'target')
		snapshot := node.ordinary_paint_box_
		assert (snapshot != unsafe { nil }) == !retain_uncached_item_paint
		mut changed := document.get_element_by_id('changed')?
		for content in ['<p>Move the item down</p>', '', '<p>First</p><p>Second</p>'] {
			changed.set_inner_html(content)!
			document.update_layout(.debugging)
			ordinary_projection_test_compare(document, 'target')
			if !retain_uncached_item_paint {
				assert voidptr(node.ordinary_paint_box_) == voidptr(snapshot)
			}
			assert display_list_commands(old).clone() == commands
		}
		release_display_list_scene(retained)
	}
}

fn test_item_paint_projection_rechecks_live_item_roles_and_box_model() {
	mut document := html.parse_document('<!doctype html><style>
		#parent{display:grid;width:240px}#target{padding:5%;border:1px solid blue;height:30px}
	</style><div id="parent"><section id="target">Text</section></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut node := unsafe { &Node(ordinary_projection_test_node(document, 'target')) }
	ordinary_projection_test_compare(document, 'target')
	grid_snapshot := node.ordinary_paint_box_
	node.is_grid_item_ = false
	node.set_flex_item(true)
	ordinary_projection_test_compare(document, 'target')
	if !retain_uncached_item_paint {
		assert voidptr(node.ordinary_paint_box_) != voidptr(grid_snapshot)
		assert node.ordinary_paint_box_.flex_item && !node.ordinary_paint_box_.grid_item
	}
	mut parent := document.get_element_by_id('parent')?
	for style in ['display:flex;width:120px', 'display:grid;width:300px', 'display:block;width:240px'] {
		parent.set_attribute_value('style', style)
		document.update_layout(.debugging)
		ordinary_projection_test_compare(document, 'target')
	}
}
