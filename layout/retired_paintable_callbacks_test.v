module layout

import dom
import html

fn snapshot_callback_paintables(node &Node, mut output []&dom.Paintable) {
	if node.dom_layout_node_ != unsafe { nil } { output << node.dom_layout_node_.paintables() }
	for child in node.children() { snapshot_callback_paintables(child, mut output) }
}

fn test_replaced_paintables_release_renderer_callbacks_while_live_wrappers_rebind() {
	mut document := html.parse_document('<!doctype html><div id="changed"><p>Old comment</p></div><p id="stable">Unchanged comment</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	previous := document_layout_result(document)?
	mut paintables := []&dom.Paintable{}
	snapshot_callback_paintables(previous.root, mut paintables)
	assert paintables.len > 0
	assert paintables.all(it.repaint_callback_target == voidptr(previous))
	old_list := document.record_display_list()?
	old_scene := retain_display_list_scene(old_list)
	defer { release_display_list_scene(old_scene) }
	old_commands := display_list_commands(old_list).clone()
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>Replacement comment with different text</p>')!
	document.update_layout(.debugging)
	current := document_layout_result(document)?
	assert paintables.any(it.repaint_callback_target == unsafe { nil })
	assert paintables.any(it.repaint_callback_target == voidptr(current))
	for paintable in paintables {
		assert paintable.repaint_callback_target != voidptr(previous)
		if paintable.repaint_callback_target == unsafe { nil } {
			assert paintable.callbacks == unsafe { nil }
		}
	}
	mut live := []&dom.Paintable{}
	snapshot_callback_paintables(current.root, mut live)
	assert live.all(it.repaint_callback_target == voidptr(current))
	gc_collect()
	assert display_list_commands(old_list).clone() == old_commands
	current_list := document.record_display_list()?
	assert display_list_commands(current_list).any(it.text.contains('Replacement'))
}

fn test_geometry_only_layout_keeps_current_paintables_bound_to_the_new_renderer() {
	mut document := html.parse_document('<!doctype html><p>Resize this unchanged text onto more lines.</p>')
	defer { document.finalize() }
	for width in [400.0, 100.0, 300.0] {
		_ = layout_document_typed_in_viewport(document, width, 200)
		current := document_layout_result(document)?
		mut live := []&dom.Paintable{}
		snapshot_callback_paintables(current.root, mut live)
		assert live.len > 0
		assert live.all(it.repaint_callback_target == voidptr(current))
	}
}

fn test_renderer_binding_inventory_survives_mutating_the_previous_layout_tree() {
	mut document := html.parse_document('<!doctype html><style>.closed{display:none}</style><div id="changed"><p>Expanded</p></div><section><p>Unchanged</p></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	previous := document_layout_result(document)?
	mut saved := previous.paintable_bindings.clone()
	assert saved.len > 0
	// Tree fixups and retained-node reparenting may have changed the old tree
	// before retirement. Its installation-time bindings remain authoritative.
	mut old_root := unsafe { &Node(previous.root) }
	old_root.children_.clear()
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('class', 'closed')
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert previous.paintable_bindings.len == 0
	assert saved.all(it.repaint_callback_target != voidptr(previous))
	current := document_layout_result(document)?
	assert current.paintable_bindings.len > 0
	assert current.paintable_bindings.all(it.repaint_callback_target == voidptr(current))
}
