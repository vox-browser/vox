module html

import dom
import page
import platform

fn storage_rendering_document() (&dom.Document, &WindowModel, &page.Page) {
	mut document := parse_document('<!doctype html><body></body>')
	window := WindowModel.create_top_level(document, none, 'rendering-storage') or { panic(err) }
	mut page_ := page.Page.create(1) or { panic(err) }
	mut client := page_.client()
	client.set_event_recording(false)
	client.rendering_opportunity(1_000_000, 16)
	document.set_page(unsafe { &dom.Page(page_) })
	page_.set_local_root_navigable(window.navigable() or { panic('missing navigable') }) or { panic(err) }
	document.update_the_visibility_state(.visible)
	return document, window, page_
}

fn test_rendering_snapshots_release_only_their_private_pointer_vectors() {
	mut owner := EventLoop.create(.window)
	mut document, _, page_ := storage_rendering_document()
	defer { document.finalize() }
	owner.register_document(document)
	before := platform.thread_arena_usage().used
	mut client := page_.client()
	for _ in 0 .. 256 {
		client.rendering_opportunity(1_000_000, 16)
		snapshot := owner.rendering_document_snapshot()
		assert snapshot.documents.len == 1
		assert voidptr(snapshot.documents[0]) == voidptr(document)
		notify_pages_of_rendering_update(true)
		notify_pages_of_rendering_update(false)
		snapshot.scratch.finish()
	}
	$if prealloc {
		retained := platform.thread_arena_usage().used - before
		assert retained < 8192, '${retained} retained by rendering snapshots'
	}
	assert owner.documents_.len == 1
	assert voidptr(owner.documents_[0]) == voidptr(document)
	assert document.body() != none
}

fn test_rendering_checks_without_hooks_or_pending_callbacks_do_not_build_lists() {
	mut owner := EventLoop.create(.window)
	mut document, _, page_ := storage_rendering_document()
	defer { document.finalize() }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner.register_environment_settings_object(settings)
	owner.register_document(document)
	mut client := page_.client()
	client.set_manual_rendering_opportunities(true)
	owner.process()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		owner.process_input_events()
		assert !owner.rendering_opportunity(0, false)
		assert !owner.has_active_idle_callbacks()
		_ = owner.compute_deadline()
		owner.process()
	}
	$if prealloc {
		retained := platform.thread_arena_usage().used - before
		assert retained < 4096, '${retained} retained by empty rendering checks'
	}
}

@[heap]
struct RenderingStorageObservation {
mut:
	documents []&dom.Document
	created &dom.Element = unsafe { nil }
}

fn test_rendering_hooks_keep_durable_snapshots_and_allocate_outside_retired_storage() {
	mut owner := EventLoop.create(.window)
	mut document, _, page_ := storage_rendering_document()
	defer { document.finalize() }
	owner.register_document(document)
	state := &RenderingStorageObservation{}
	owner.set_rendering_hook(fn [state] (documents []&dom.Document, _ f64) {
		mut observation := unsafe { &RenderingStorageObservation(state) }
		observation.documents = documents
		mut target := unsafe { &dom.Document(documents[0]) }
		observation.created = target.create_element_ns('http://www.w3.org/1999/xhtml', 'aside') or { panic(err) }
	})
	owner.update_the_rendering()
	assert state.documents.len == 1
	assert voidptr(state.documents[0]) == voidptr(document)
	assert state.created.local_name() == 'aside'
	assert owner.rendering_scheduler_counters().paints == 1
	owner.set_rendering_hook(none)
	mut client := page_.client()
	client.rendering_opportunity(2_000_000, 16)
	owner.update_the_rendering()
	assert state.documents.len == 1
	assert voidptr(state.documents[0]) == voidptr(document)
	assert state.created.local_name() == 'aside'
	assert owner.rendering_scheduler_counters().paints == 2
}
