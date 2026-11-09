module html

import dom

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#unload-a-document
// Unloading with intendToStoreInBfcache: the document stays salvageable, so
// it receives pagehide with persisted true and becomes hidden, but neither an
// unload event nor destruction follows. Its tasks stay queued and become
// runnable again once the document is fully active; its timers stay frozen
// until then.
pub fn suspend_document_for_back_forward_cache(document &dom.Document) {
	mut suspended := unsafe { &dom.Document(document) }
	// Keep its layout tree when it stops being active, as WebKit keeps a cached
	// page's render tree, so showing it again needs no layout.
	suspended.retains_layout_while_inactive = true
	defer { freeze_document_timers(suspended) }
	if !suspended.document_page_showing() { return }
	suspended.set_page_showing(false)
	if window := suspended.get_window() {
		model := unsafe { &WindowModel(window) }
		model.fire_a_page_transition_event(event_pagehide, true)
	}
	suspended.update_the_visibility_state(.hidden)
}

// Timers installed by pagehide handlers freeze with the rest.
fn freeze_document_timers(document &dom.Document) {
	window := document.get_window() or { return }
	model := unsafe { &WindowModel(window) }
	if model.global_scope_ == unsafe { nil } { return }
	mut scope := model.global_scope_
	scope.freeze_timers()
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#reactivate-a-document
// Make a document kept in the back/forward cache the active document of the
// navigable it was shown in, retargeting the browsing context and WindowProxy
// to its own Window. The navigable's previous document stops being active, as
// it does when a navigation installs a new document.
pub fn can_reactivate_back_forward_cached_document(document &dom.Document) bool {
	if document.has_been_destroyed() { return false }
	window := document.get_window() or { return false }
	return unsafe { &WindowModel(window) }.browsing_context_ != unsafe { nil }
}

// The caller checks can_reactivate_back_forward_cached_document first. A page
// left before its load event finished gets that event when its queued tasks
// run, rather than pageshow now.
pub fn reactivate_back_forward_cached_document(document &dom.Document, navigable &dom.Navigable, page_was_showing bool) {
	window_pointer := document.get_window() or { return }
	mut window := unsafe { &WindowModel(window_pointer) }
	mut context := window.browsing_context_
	outgoing := navigable.active_document()
	mut host := unsafe { &dom.Navigable(navigable) }
	host.set_active_document(document)
	if previous := outgoing {
		if voidptr(previous) != voidptr(document) {
			mut retiring := unsafe { &dom.Document(previous) }
			retiring.did_stop_being_active_document_in_navigable()
		}
	}
	context.set_active_document(document)
	if window.window_proxy_ != unsafe { nil } {
		context.set_window_proxy(window.window_proxy_)
	}
	context.set_active_window(window)
	mut restored := unsafe { &dom.Document(document) }
	// Its next deactivation notifies observers (media, animated images) again
	// and, unless it is cached again, tears down its layout.
	restored.has_fired_document_became_inactive = false
	restored.retains_layout_while_inactive = false
	restored.make_active()
	if window.global_scope_ != unsafe { nil } {
		mut scope := window.global_scope_
		scope.thaw_timers()
	}
	visibility := if model := navigable_model_for_host(host) {
		model.system_visibility_state()
	} else {
		dom.VisibilityState.visible
	}
	restored.update_the_visibility_state(visibility)
	if page_was_showing {
		restored.set_page_showing(true)
		window.fire_a_page_transition_event('pageshow', true)
	}
}
