module layout

import dom
import html

fn hosted_scene_test_document(markup string) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(false)
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, markup)
	allocations.finish()
	enable_native_paint_tree_storage(document)
	return document
}

fn hosted_scene_test_attach(parent &dom.Document, child &dom.Document) {
	frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	mut navigable := &dom.Navigable{container_: frame.as_node()}
	navigable.set_active_document(child)
}

fn hosted_scene_test_retire(mut document dom.Document) {
	handle := document.layout_engine_handle()
	if navigable := document.navigable() {
		mut retiring := unsafe { &dom.Navigable(navigable) }
		retiring.remove_from_all_navigables()
	}
	document.destroy_a_document_and_its_descendants()
	retire_native_document_layout(handle)
	document.layout_engine_handle_ = unsafe { nil }
	document.cached_display_list_ = unsafe { nil }
	document.finalize()
	document.release_native_storage()
}

fn hosted_scene_test_nested(commands []PaintCommand) PaintCommand {
	for command in commands {
		if command.kind == 'paint_nested_display_list' { return command }
	}
	panic('missing hosted recording')
}

fn test_hosted_scene_survives_phase_cache_eviction_and_native_document_retirement() {
	mut parent := hosted_scene_test_document('<!doctype html><iframe id="frame" style="width:180px;height:80px"></iframe>')
	mut child := hosted_scene_test_document('<!doctype html><p>retained child</p>')
	parent_owner := parent.native_storage()
	child_owner := child.native_storage()
	hosted_scene_test_attach(parent, child)
	_ = run_document_layout(parent, 320, 200) or { panic('missing parent layout') }
	list := parent.record_display_list() or { panic('missing parent recording') }
	reader := retain_display_list_scene(list)
	parent_scene := unsafe { &DisplayListScene(reader) }
	commands := display_list_commands(list)
	nested := hosted_scene_test_nested(commands)
	child_scene := nested.nested_viewport_scene
	assert child_scene != unsafe { nil }
	assert child_scene.references == 3 // Child publisher, parent phase, parent scene.
	assert parent_scene.dependencies.len == 1
	$if prealloc {
		// Recording while the parent is entered must put the child's layout
		// in the child's owner, not in its host's current allocation scope.
		assert child_owner.arena.contains(child.layout_engine_handle())
		assert !parent_owner.arena.contains(child.layout_engine_handle())
	}
	release_unused_display_list_caches(list)
	assert child_scene.references == 2
	hosted_scene_test_retire(mut child)
	assert child_scene.references == 1
	assert nested.nested_viewport_commands.any(it.text == 'retained child')
	hosted_scene_test_retire(mut parent)
	assert parent_scene.references == 1
	assert child_scene.references == 1
	assert hosted_scene_test_nested(commands).nested_viewport_commands.any(it.text == 'retained child')
	assert hosted_scene_test_nested(display_list_commands(list)).nested_viewport_commands.any(it.text == 'retained child')
	$if prealloc {
		assert parent_owner.arena.usage().used > 0
		assert child_owner.arena.usage().used > 0
	}
	release_display_list_scene(reader)
	assert parent_scene.references == 0
	assert parent_scene.dependencies.len == 0
	assert child_scene.references == 0
	$if prealloc {
		assert parent_owner.arena.usage().capacity == 0
		assert child_owner.arena.usage().capacity == 0
		assert parent_scene.arena.usage().capacity == 0
		assert child_scene.arena.usage().capacity == 0
	}
}

fn test_hosted_scene_repaint_leases_stay_bounded_while_an_older_parent_is_retained() {
	mut parent := hosted_scene_test_document('<!doctype html><iframe id="frame" style="width:180px;height:80px"></iframe>')
	mut child := hosted_scene_test_document('<!doctype html><p id="text">original child</p>')
	parent_owner := parent.native_storage()
	child_owner := child.native_storage()
	hosted_scene_test_attach(parent, child)
	_ = run_document_layout(parent, 320, 200) or { panic('missing parent layout') }
	parent_layout := parent.layout_engine_handle()
	first := parent.record_display_list() or { panic('missing initial recording') }
	first_reader := retain_display_list_scene(first)
	first_dump := first.dump()
	first_generation := first.generation()
	first_commands := display_list_commands(first)
	first_nested := hosted_scene_test_nested(first_commands)
	old_child := first_nested.nested_viewport_scene
	child_pool := old_child.pool
	frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	mut text := child.get_element_by_id('text') or { panic('missing child text') }
	for generation in 0 .. 12 {
		mut allocations := child.enter_native_storage()
		text.set_text_content('child ${generation}')!
		allocations.finish()
		child.update_layout(.debugging)
		mut paintable := frame.paintable_box() or { panic('missing frame paintable') }
		paintable.set_needs_repaint(.paint_commands)
		current := parent.record_display_list() or { panic('missing replacement recording') }
		nested := hosted_scene_test_nested(display_list_commands(current))
		assert nested.nested_viewport_commands.any(it.text == 'child ${generation}')
		assert first_nested.nested_viewport_commands.any(it.text == 'original child')
		retained_nested := hosted_scene_test_nested(display_list_commands(first))
		assert retained_nested.nested_viewport_commands.any(it.text == 'original child')
		assert voidptr(retained_nested.nested_viewport_scene) == voidptr(old_child)
		assert first.dump() == first_dump
		assert first.generation() == first_generation
		assert current.generation() > first_generation
		another_reader := retain_display_list_scene(first)
		assert another_reader == first_reader
		release_display_list_scene(another_reader)
		assert parent.layout_engine_handle() == parent_layout
		assert old_child.references == 1
		assert child_pool.live.len == 2
		assert child_pool.free.len <= display_list_scene_spares
		$if prealloc { assert old_child.arena.reset_count() == 0 }
	}
	release_display_list_scene(first_reader)
	assert old_child.references == 0
	assert child_pool.live.len == 1
	$if prealloc { assert old_child.arena.reset_count() == 1 }
	hosted_scene_test_retire(mut child)
	hosted_scene_test_retire(mut parent)
	assert child_pool.live.len == 0
	$if prealloc {
		assert parent_owner.arena.usage().capacity == 0
		assert child_owner.arena.usage().capacity == 0
	}
}

fn test_raw_paint_commands_transfer_and_release_their_hosted_scene_leases() {
	mut parent := hosted_scene_test_document('<!doctype html><iframe id="frame" style="width:180px;height:80px"></iframe>')
	mut child := hosted_scene_test_document('<!doctype html><p>raw child</p>')
	child_owner := child.native_storage()
	hosted_scene_test_attach(parent, child)
	result := run_document_layout(parent, 320, 200) or { panic('missing parent layout') }
	commands := result.paint_tree.paint_commands()
	nested := hosted_scene_test_nested(commands)
	child_scene := nested.nested_viewport_scene
	// The temporary phase cache is gone; the raw vector and child publisher
	// each own one lease, even though replay copied the command record.
	assert child_scene.references == 2
	hosted_scene_test_retire(mut child)
	assert child_scene.references == 1
	assert nested.nested_viewport_commands.any(it.text == 'raw child')
	release_paint_commands(commands)
	assert child_scene.references == 0
	$if prealloc { assert child_owner.arena.usage().capacity == 0 }
	hosted_scene_test_retire(mut parent)
}

fn test_hosted_scene_leases_release_nested_descendants_transitively() {
	mut parent := hosted_scene_test_document('<!doctype html><iframe id="frame" style="width:220px;height:120px"></iframe>')
	mut child := hosted_scene_test_document('<!doctype html><iframe id="frame" style="width:160px;height:60px"></iframe>')
	// Keep the payload in one command regardless of the platform's font widths;
	// this fixture tests retained storage, not line wrapping in the narrow frame.
	mut grandchild := hosted_scene_test_document('<!doctype html><p style="white-space:nowrap">grandchild payload</p>')
	parent_owner := parent.native_storage()
	child_owner := child.native_storage()
	grandchild_owner := grandchild.native_storage()
	hosted_scene_test_attach(parent, child)
	hosted_scene_test_attach(child, grandchild)
	_ = run_document_layout(parent, 320, 200) or { panic('missing parent layout') }
	list := parent.record_display_list() or { panic('missing parent recording') }
	reader := retain_display_list_scene(list)
	commands := display_list_commands(list)
	nested := hosted_scene_test_nested(commands)
	inner := hosted_scene_test_nested(nested.nested_viewport_commands)
	child_scene := nested.nested_viewport_scene
	grandchild_scene := inner.nested_viewport_scene
	assert child_scene.dependencies.len == 1
	assert grandchild_scene.references == 3
	assert inner.nested_viewport_commands.any(it.text == 'grandchild payload')
	hosted_scene_test_retire(mut grandchild)
	hosted_scene_test_retire(mut child)
	hosted_scene_test_retire(mut parent)
	assert child_scene.references == 1
	assert grandchild_scene.references == 1
	assert inner.nested_viewport_commands.any(it.text == 'grandchild payload')
	release_display_list_scene(reader)
	assert child_scene.references == 0
	assert grandchild_scene.references == 0
	$if prealloc {
		assert parent_owner.arena.usage().capacity == 0
		assert child_owner.arena.usage().capacity == 0
		assert grandchild_owner.arena.usage().capacity == 0
	}
}
