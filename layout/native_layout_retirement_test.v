module layout

import dom
import html

fn native_retirement_test_document(markup string) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(false)
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, markup)
	allocations.finish()
	enable_native_paint_tree_storage(document)
	return document
}

// Exercise the DOM-owned retirement hook, without manually capturing or
// retiring a concrete layout handle as the native shell used to require.
fn native_retirement_test_close(mut document dom.Document) {
	if navigable := document.navigable() {
		mut retiring := unsafe { &dom.Navigable(navigable) }
		retiring.remove_from_all_navigables()
	}
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	document.release_native_storage()
}

fn test_native_child_deactivation_retires_its_publisher_before_losing_the_handle() {
	$if !prealloc { return }
	mut parent := native_retirement_test_document('<!doctype html><iframe id="frame" style="width:180px;height:80px"></iframe>')
	mut child := native_retirement_test_document('<!doctype html><p>deactivated child</p>')
	parent_owner := parent.native_storage()
	child_owner := child.native_storage()
	frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	mut navigable := &dom.Navigable{container_: frame.as_node()}
	navigable.set_active_document(child)
	_ = run_document_layout(parent, 320, 200) or { panic('missing parent layout') }
	list := parent.record_display_list() or { panic('missing parent recording') }
	reader := retain_display_list_scene(list)
	commands := display_list_commands(list)
	child_result := document_layout_result(child) or { panic('missing child layout') }
	child_scene := child_result.scene
	child_tree := child_result.paint_tree_storage
	assert child_scene.references == 3
	assert child_tree != unsafe { nil }

	child.did_stop_being_active_document_in_navigable()
	assert child.layout_engine_handle() == unsafe { nil }
	assert child_scene.pool.retired
	assert child_tree.pool.retired
	assert child_result.scene == unsafe { nil }
	assert child_result.paint_tree_storage == unsafe { nil }
	assert child_scene.references == 2
	// No concrete handle remains for a later host cleanup to recover.
	native_retirement_test_close(mut child)
	native_retirement_test_close(mut parent)
	assert child_scene.references == 1
	assert commands.any(it.kind == 'paint_nested_display_list'
		&& it.nested_viewport_commands.any(it.text == 'deactivated child'))
	assert parent_owner.arena.usage().used > 0
	assert child_owner.arena.usage().used > 0
	release_display_list_scene(reader)
	assert child_scene.references == 0
	assert child_tree.references == 0
	assert parent_owner.arena.usage().capacity == 0
	assert child_owner.arena.usage().capacity == 0
}

fn test_implicit_adoption_owner_finalization_retires_rendering_with_and_without_a_reader() {
	$if !prealloc { return }
	for keep_reader in [false, true] {
		mut source := native_retirement_test_document('<!doctype html><p id="adopted">adopted rendering</p>')
		mut destination := html.parse_document('<!doctype html><main id="target"></main>')
		destination.set_scripting_enabled_by_embedder(false)
		assert destination.native_storage() == unsafe { nil }
		node := source.get_element_by_id('adopted') or { panic('missing adopted node') }
		mut target := destination.get_element_by_id('target') or { panic('missing destination') }
		destination.adopt_node(node.as_node())
		target.append_child(node)
		source_owner := source.native_storage()
		destination_owner := destination.native_storage()
		assert destination_owner != unsafe { nil }
		// This opts in only the paint slots, leaving the document's implicit
		// adoption owner under its existing finalize() boundary.
		enable_native_paint_tree_storage(destination)
		_ = run_document_layout(destination, 320, 200) or { panic('missing adopted layout') }
		list := destination.record_display_list() or { panic('missing adopted recording') }
		commands := display_list_commands(list)
		result := document_layout_result(destination) or { panic('missing adopted result') }
		scene := result.scene
		tree := result.paint_tree_storage
		reader := if keep_reader { retain_display_list_scene(list) } else { unsafe { nil } }
		native_retirement_test_close(mut source)
		// General DOM callers finalize without explicitly closing a layout
		// publisher or calling release_native_storage themselves.
		destination.finalize()
		assert destination.native_storage() == unsafe { nil }
		assert destination.layout_engine_handle() == unsafe { nil }
		assert scene.pool.retired
		assert tree.pool.retired
		assert scene.references == if keep_reader { 1 } else { 0 }
		if keep_reader {
			assert commands.any(it.text == 'adopted rendering')
			assert source_owner.arena.usage().used > 0
			assert destination_owner.arena.usage().used > 0
			release_display_list_scene(reader)
		}
		assert scene.references == 0
		assert tree.references == 0
		assert source_owner.arena.usage().capacity == 0
		assert destination_owner.arena.usage().capacity == 0
		// Repeated finalization cannot retire the same concrete handle twice.
		destination.finalize()
	}
}

fn test_suspended_native_document_keeps_its_publisher_until_owner_retirement() {
	$if !prealloc { return }
	mut document := native_retirement_test_document('<!doctype html><p>cached page</p>')
	owner := document.native_storage()
	_ = run_document_layout(document, 320, 200) or { panic('missing cached layout') }
	handle := document.layout_engine_handle()
	list := document.record_display_list() or { panic('missing cached recording') }
	reader := retain_display_list_scene(list)
	commands := display_list_commands(list)
	result := document_layout_result(document) or { panic('missing cached result') }
	scene := result.scene
	tree := result.paint_tree_storage
	document.retains_layout_while_inactive = true
	document.did_stop_being_active_document_in_navigable()
	assert document.layout_engine_handle() == handle
	assert !scene.pool.retired
	assert !tree.pool.retired
	assert scene.references == 2
	assert voidptr(result.scene) == voidptr(scene)
	assert commands.any(it.text == 'cached page')
	// Destroying a suspended session still retires its publisher. The retain
	// flag suppresses deactivation cleanup, not the final owner release.
	native_retirement_test_close(mut document)
	assert document.layout_engine_handle() == unsafe { nil }
	assert scene.pool.retired
	assert tree.pool.retired
	assert scene.references == 1
	assert commands.any(it.text == 'cached page')
	release_display_list_scene(reader)
	assert scene.references == 0
	assert tree.references == 0
	assert owner.arena.usage().capacity == 0
}
