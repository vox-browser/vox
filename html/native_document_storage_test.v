module html

import dom
import platform

struct NativeTaskStorageProbe {
mut:
	called bool
}

fn test_unassociated_progress_task_retains_its_explicit_document_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	storage := document.native_storage()
	probe := &NativeTaskStorageProbe{}
	mut scope := document.enter_native_storage()
	payload := 'unassociated progress payload'.bytes()
	scope.finish()
	mut loop := EventLoop.create(.window)
	queue_a_task_with_storage(.unspecified, loop, none, fn [payload, probe] () {
		assert payload.bytestr() == 'unassociated progress payload'
		mut observation := unsafe { &NativeTaskStorageProbe(probe) }
		observation.called = true
	}, storage)
	document.release_native_storage()
	task := loop.task_queue().take_first_runnable()?
	assert task.document() == none
	task.execute()
	assert probe.called
	$if prealloc { assert storage.arena.usage().used == 0 }
	if mut timer := loop.system_event_loop_timer_ { timer.stop() }
}

fn test_inner_html_fragment_adoption_does_not_pin_the_native_document() {
	url := dom.URL{value: 'https://fragment-storage.example/'}
	mut document := create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	storage := document.native_storage()
	mut allocations := document.enter_native_storage()
	parse_html_from_a_string(document, '<!doctype html><main id="target"></main>')
	allocations.finish()
	target := document.get_element_by_id('target')?
	for _ in 0 .. 3 {
		set_inner_html(target, '<p>Fragment content</p><template><b>Inert child</b></template>')
		assert target.as_node().text_content()? == 'Fragment content'
	}
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	document.release_native_storage()
	mut loop := main_thread_event_loop()
	loop.process()
	$if prealloc { assert storage.arena.usage().used == 0 }
}

fn test_inert_template_adoption_uses_the_containing_documents_native_lifetime() {
	url := dom.URL{value: 'https://template-storage.example/'}
	mut document := create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	storage := document.native_storage()
	mut allocations := document.enter_native_storage()
	parse_html_from_a_string(document, '<!doctype html><template><p>Template content</p></template>')
	allocations.finish()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	document.release_native_storage()
	mut loop := main_thread_event_loop()
	loop.process()
	$if prealloc { assert storage.arena.usage().used == 0 }
}

fn test_queued_task_keeps_native_payload_until_callback_returns() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	storage := document.native_storage()
	probe := &NativeTaskStorageProbe{}
	mut allocations := document.enter_native_storage()
	payload := 'task-owned document payload'.bytes()
	task := Task.create(.unspecified, document, fn [payload, probe] () {
		assert payload.bytestr() == 'task-owned document payload'
		mut observation := unsafe { &NativeTaskStorageProbe(probe) }
		observation.called = true
	})
	allocations.finish()
	document.release_native_storage()
	$if prealloc { assert storage.arena.usage().used > 0 }
	task.execute()
	assert probe.called
	$if prealloc { assert storage.arena.usage().used == 0 }
}

fn test_removing_queued_task_releases_its_native_payload_without_calling_it() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	storage := document.native_storage()
	probe := &NativeTaskStorageProbe{}
	mut allocations := document.enter_native_storage()
	task := Task.create(.unspecified, document, fn [probe] () {
		mut observation := unsafe { &NativeTaskStorageProbe(probe) }
		observation.called = true
	})
	allocations.finish()
	mut event_loop := EventLoop.create(.window)
	mut queue := event_loop.task_queue()
	queue.add(task)
	document.release_native_storage()
	queue.remove_tasks_matching(fn (_ &Task) bool { return true })
	assert queue.is_empty() && !probe.called
	$if prealloc { assert storage.arena.usage().used == 0 }
	if mut timer := event_loop.system_event_loop_timer_ { timer.stop() }
}

fn test_animated_session_unregisters_before_its_document_arena_is_released() {
	$if prealloc {
		mut owner := platform.new_retained_arena('animated image owner')
		mut scope := owner.enter()
		_ = AnimatedDecodedImageData.create(731234, 2, 0, 1, 1, .srgb,
			[u32(100), 100], [], none, none)
		scope.finish()
		assert 731234 in html_animated_image_sessions
		owner.release()
		assert 731234 !in html_animated_image_sessions
		assert owner.arena.usage().used == 0
	}
}
