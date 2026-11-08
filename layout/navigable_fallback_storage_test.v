module layout

import css
import dom
import html
import platform

fn fallback_storage_test_document(markup string) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(false)
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, markup)
	allocations.finish()
	enable_native_paint_tree_storage(document)
	return document
}

fn fallback_storage_test_close(mut document dom.Document) {
	if navigable := document.navigable() {
		mut retiring := unsafe { &dom.Navigable(navigable) }
		retiring.remove_from_all_navigables()
	}
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	document.release_native_storage()
}

fn fallback_storage_test_viewport(frame &dom.Element) &NavigableContainerViewport {
	mirror := frame.unsafe_layout_node() or { panic('missing frame layout') }
	node := unsafe { &Node(mirror.layout_handle) }
	assert node.is_navigable_container_viewport()
	return unsafe { &NavigableContainerViewport(node) }
}

fn fallback_storage_test_nested(commands []PaintCommand) PaintCommand {
	for command in commands {
		if command.kind == 'paint_nested_display_list' { return command }
	}
	panic('missing fallback recording')
}

fn test_navigable_fallback_is_lazy_and_a_real_host_retires_the_unused_adapter() {
	mut parent := fallback_storage_test_document('<!doctype html><iframe id="frame" srcdoc="<p>fallback child</p>"></iframe>')
	mut child := fallback_storage_test_document('<!doctype html><p>real child</p>')
	frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	mut navigable := &dom.Navigable{container_: frame.as_node()}
	navigable.set_active_document(child)
	viewport := NavigableContainerViewport.new(parent, frame, css.ComputedProperties.new())
	assert viewport.content_document_ == unsafe { nil }
	assert voidptr(viewport.content_document()?) == voidptr(child)
	assert viewport.content_document_ == unsafe { nil }
	navigable.set_active_document(none)
	assert viewport.content_document() == none
	assert viewport.content_document_ == unsafe { nil }
	navigable.remove_from_all_navigables()
	mut fallback := viewport.content_document() or { panic('missing standalone fallback') }
	assert voidptr(viewport.content_document()?) == voidptr(fallback)
	fallback_owner := fallback.native_storage()
	// Installing a real host must stop publishing an existing native adapter.
	navigable.set_active_document(child)
	assert voidptr(viewport.content_document()?) == voidptr(child)
	assert viewport.content_document_ == unsafe { nil }
	$if prealloc {
		assert fallback.native_storage() == unsafe { nil }
		assert fallback_owner.arena.usage().capacity == 0
	} $else {
		fallback.finalize()
	}
	fallback_storage_test_close(mut child)
	fallback_storage_test_close(mut parent)
}

fn test_native_fallback_header_and_payload_outlive_the_parent_paint_workspace() {
	$if !prealloc { return }
	mut parent := fallback_storage_test_document('<!doctype html><iframe id="frame" srcdoc="<p id=payload>workspace child</p>"></iframe>')
	parent_owner := parent.native_storage()
	frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	mut parent_scope := parent.enter_native_storage()
	mut workspace := platform.new_arena('standalone fallback parent workspace')
	entry := workspace.enter()
	viewport := NavigableContainerViewport.new(parent, frame, css.ComputedProperties.new())
	mut child := viewport.content_document() or { panic('missing native fallback') }
	child_owner := child.native_storage()
	assert child_owner != unsafe { nil }
	assert !workspace.contains(child)
	assert !parent_owner.arena.contains(child)
	assert !child_owner.arena.contains(child)
	assert child_owner.arena.contains(child.get_element_by_id('payload')?)
	workspace.leave(entry)
	workspace.release()
	parent_scope.finish()
	_ = run_document_layout(child, 180, 80) or { panic('missing child layout') }
	list := child.record_display_list() or { panic('missing child recording') }
	reader := retain_display_list_scene(list)
	commands := display_list_commands(list)
	fallback_storage_test_close(mut parent)
	// Cleanup captures the persistent child header, not the temporary viewport.
	assert child.native_storage() == unsafe { nil }
	assert child.layout_engine_handle() == unsafe { nil }
	assert parent_owner.arena.usage().capacity == 0
	assert child_owner.arena.usage().used > 0
	assert commands.any(it.text == 'workspace child')
	release_display_list_scene(reader)
	assert child_owner.arena.usage().capacity == 0
}

fn test_native_fallback_source_replacement_and_relayouts_preserve_retained_parent_commands() {
	$if !prealloc { return }
	mut parent := fallback_storage_test_document('<!doctype html><iframe id="frame" style="width:180px;height:80px" srcdoc="<p id=payload>original fallback</p>"></iframe>')
	parent_owner := parent.native_storage()
	mut frame := parent.get_element_by_id('frame') or { panic('missing frame') }
	_ = run_document_layout(parent, 320, 200) or { panic('missing parent layout') }
	viewport := fallback_storage_test_viewport(frame)
	first_child := viewport.content_document() or { panic('missing original fallback') }
	first_owner := first_child.native_storage()
	for _ in 0 .. 4 {
		assert voidptr(viewport.content_document()?) == voidptr(first_child)
	}
	first := parent.record_display_list() or { panic('missing original parent recording') }
	reader := retain_display_list_scene(first)
	commands := display_list_commands(first)
	nested := fallback_storage_test_nested(commands)
	first_scene := nested.nested_viewport_scene
	frame.set_attribute_value('srcdoc', '<p id=payload>changed fallback</p>')
	second_child := viewport.content_document() or { panic('missing replacement fallback') }
	assert voidptr(second_child) != voidptr(first_child)
	assert first_child.native_storage() == unsafe { nil }
	assert first_child.layout_engine_handle() == unsafe { nil }
	assert nested.nested_viewport_commands.any(it.text == 'original fallback')
	mut children := [second_child]
	mut owners := [second_child.native_storage()]
	// Full replacement layout trees have their own standalone adapter. Every
	// one has an eventual parent cleanup, while repeated reads of one viewport
	// reuse its child instead of parsing another document.
	for _ in 0 .. 3 {
		parent.invalidate_layout_tree(.navigable_active_document_changed)
		_ = run_document_layout(parent, 320, 200) or { panic('missing replacement layout') }
		current_viewport := fallback_storage_test_viewport(frame)
		current_child := current_viewport.content_document() or { panic('missing current fallback') }
		assert voidptr(current_viewport.content_document()?) == voidptr(current_child)
		children << current_child
		owners << current_child.native_storage()
		current := parent.record_display_list() or { panic('missing replacement parent recording') }
		assert fallback_storage_test_nested(display_list_commands(current)).nested_viewport_commands.any(it.text == 'changed fallback')
		assert nested.nested_viewport_commands.any(it.text == 'original fallback')
	}
	assert first_scene.references == 1
	fallback_storage_test_close(mut parent)
	for index, child in children {
		assert child.native_storage() == unsafe { nil }
		assert child.layout_engine_handle() == unsafe { nil }
		assert owners[index].arena.usage().capacity == 0
	}
	assert first_owner.arena.usage().used > 0
	assert parent_owner.arena.usage().used > 0
	assert nested.nested_viewport_commands.any(it.text == 'original fallback')
	release_display_list_scene(reader)
	assert first_scene.references == 0
	assert first_owner.arena.usage().capacity == 0
	assert parent_owner.arena.usage().capacity == 0
}
