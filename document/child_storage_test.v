module main

import dom
import html
import layout
import page
import time

fn test_closing_a_rendered_hosted_child_reclaims_storage_after_the_parent_reader() {
	$if !prealloc { return }
	page_owner := page.Page.create(1)!
	mut root := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><iframe id="frame" srcdoc="<p>hosted child payload</p>" style="width:180px;height:80px"></iframe>',
		dom.URL{value: 'https://rendered-host.example/'}, none, none,
		unsafe { &dom.Page(page_owner) }, time.sys_mono_now())
	root.set_scripting_enabled_by_embedder(false)
	layout.enable_native_paint_tree_storage(root)
	mut host := browser_child_document_host(root, .javascriptcore)
	mut messages := []string{}
	host.discover(root, mut messages)
	assert host.children.len == 1
	child_host := host.children[0]
	mut loop := html.main_thread_event_loop()
	deadline := time.sys_mono_now() + 5 * time.second
	loop.spin_until(fn [host, child_host, deadline] () bool {
		mut owner := unsafe { &BrowserChildDocumentHost(host) }
		mut log := []string{}
		owner.poll(mut log)
		if service := child_host.service {
			if service.initialized && service.document.native_storage() != unsafe { nil } {
				return true
			}
		}
		return time.sys_mono_now() >= deadline
	})
	service := child_host.service or { panic('hosted child was not installed') }
	assert service.initialized
	child := service.document
	root_storage := root.native_storage()
	child_storage := child.native_storage()
	assert child_storage != unsafe { nil }
	_ = layout.run_document_layout(root, 320, 200) or { panic('missing parent layout') }
	list := root.record_display_list() or { panic('missing parent recording') }
	reader := layout.retain_display_list_scene(list)
	commands := layout.display_list_commands(list)
	assert commands.any(it.kind == 'paint_nested_display_list'
		&& it.nested_viewport_commands.any(it.text == 'hosted child payload'))
	assert child.layout_engine_handle() != unsafe { nil }

	// This runs the real child unload path, which clears its layout handle.
	// The publisher must retire before that handle becomes unreachable.
	host.close()
	assert child.layout_engine_handle() == unsafe { nil }
	root.destroy_a_document_and_its_descendants()
	root.finalize()
	root.release_native_storage()
	assert child.native_storage() == unsafe { nil }
	assert root_storage.arena.usage().used > 0
	assert child_storage.arena.usage().used > 0
	assert commands.any(it.kind == 'paint_nested_display_list'
		&& it.nested_viewport_commands.any(it.text == 'hosted child payload'))
	layout.release_display_list_scene(reader)
	assert root_storage.arena.usage().capacity == 0
	assert child_storage.arena.usage().capacity == 0
}

fn test_hosted_document_retires_before_the_roots_last_payload_reader() {
	$if !prealloc { return }
	mut root := dom.Document.create(dom.URL{value: 'https://host-storage.example/'})
	root.enable_native_storage()
	mut root_scope := root.enter_native_storage()
	root_payload := 'retained root payload'.clone()
	root_scope.finish()
	mut root_storage := root.native_storage()
	root_storage.retain()
	mut host := browser_child_document_host(root, .javascriptcore)
	mut child := dom.Document.create(dom.URL{value: 'https://host-storage.example/child'})
	host.prepare_document(child)
	mut child_scope := child.enter_native_storage()
	mut element := child.create_element('p')!
	element.set_attribute_value('data-value', 'retained child payload'.clone())
	child_scope.finish()
	mut child_storage := child.native_storage()
	child_storage.retain()
	assert child_storage.arena.contains(element)

	root.finalize()
	root.release_native_storage()
	assert host.closed
	assert child.native_storage() == unsafe { nil }
	assert child.has_been_destroyed()
	assert root_storage.arena.usage().used > 0
	assert child_storage.arena.usage().used > 0
	assert root_payload == 'retained root payload'
	assert element.get_attribute_value('data-value') == 'retained child payload'
	// An already-retired child's persistent header remains safe to close.
	retire_hosted_browser_document(child)
	root.release_native_storage()
	child_storage.release()
	assert child_storage.arena.usage().used == 0
	root_storage.release()
	assert root_storage.arena.usage().used == 0
}

fn test_adopting_a_child_node_does_not_cycle_with_hosted_document_cleanup() {
	$if !prealloc { return }
	mut root := dom.Document.create(dom.URL{value: 'https://adoption-host.example/'})
	root.enable_native_storage()
	mut host := browser_child_document_host(root, .javascriptcore)
	mut child := dom.Document.create(dom.URL{value: 'https://adoption-host.example/child'})
	host.prepare_document(child)
	mut child_scope := child.enter_native_storage()
	mut element := child.create_element('p')!
	element.set_attribute_value('data-value', 'adopted child payload'.clone())
	child_scope.finish()
	mut root_storage := root.native_storage()
	child_storage := child.native_storage()
	root.adopt_node(element.as_node())
	root_storage.retain()

	root.finalize()
	root.release_native_storage()
	assert host.closed
	assert child.native_storage() == unsafe { nil }
	assert child.has_been_destroyed()
	assert child_storage.arena.usage().used > 0
	assert element.get_attribute_value('data-value') == 'adopted child payload'
	assert voidptr(element.document()) == voidptr(root)
	// The retained consumer is now the only owner of the shared payloads.
	root_storage.release()
	assert root_storage.arena.usage().used == 0
	assert child_storage.arena.usage().used == 0
}
