// BrowsingContext.cpp and Document.cpp: actual Window/realm/settings precede
// the new Document, whose FontFaceSet uses that existing relevant global.
module html

import dom
import platform

fn document_lifecycle_hook(window &WindowModel) dom.DocumentLifecycleHook {
	return dom.DocumentLifecycleHook{
		target:                           voidptr(window)
		register_document:                document_register_with_event_loop
		unregister_document:              document_unregister_from_event_loop
		document_navigable_did_change:    document_navigable_did_change
		remove_tasks_for_document:        document_remove_tasks_from_event_loop
		increment_termination_nesting:    document_increment_event_loop_termination_nesting
		decrement_termination_nesting:    document_decrement_event_loop_termination_nesting
		set_execution_ready:              document_set_execution_ready
		relevant_settings_object:         document_relevant_settings_object
		settings_scripting_enabled:       document_settings_scripting_enabled
		settings_has_cross_site_ancestor:  document_settings_has_cross_site_ancestor
		structured_deserialize:           document_structured_deserialize
		queue_intersection_observer_task: document_queue_intersection_observer_task
		queue_selectionchange_event_task: document_queue_selectionchange_event_task
		queue_an_element_task:            document_queue_an_element_task
		run_unloading_cleanup_steps:      document_run_unloading_cleanup_steps
		timer_visibility_state_changed:   document_timer_visibility_state_changed
		timer_audio_play_state_changed:   document_timer_audio_play_state_changed
	}
}

fn create_window_global_before_document(context &BrowsingContextModel, creation_url dom.URL, origin dom.Origin, top_level_creation_url dom.URL, top_level_origin dom.Origin) &WindowModel {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut window := &WindowModel{
		browsing_context_: context
		animation_driver_: &AnimationFrameCallbackDriver{}
		global_scope_:     WindowOrWorkerGlobalScopeMixin.create(origin, false, false)
		scripting_realm_:  &ScriptingRealm{}
	}
	window.Window.data.kind = .window
	mut realm := window.scripting_realm_
	_ = WindowEnvironmentSettingsObject.setup(window, creation_url, mut realm, none,
		top_level_creation_url, top_level_origin)
	return window
}

fn construct_document_in_global(window &WindowModel, context &BrowsingContextModel, creation_url dom.URL, origin dom.Origin) !&dom.Document {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	temporary_context := dom.DocumentTemporaryExecutionContextHook{
		target: voidptr(window)
		begin:  document_begin_temporary_execution_context
		end:    document_end_temporary_execution_context
	}
	mut document := if owner := context.page() {
		dom.Document.create_with_page_and_relevant_global(owner, creation_url,
			unsafe { &dom.Window(window) }, document_lifecycle_hook(window), temporary_context)
	} else {
		dom.Document.create_with_relevant_global(creation_url,
			unsafe { &dom.Window(window) }, document_lifecycle_hook(window), temporary_context)
	}
	document.set_origin(origin)
	// A navigation retains its actual browsing-context and navigable identities.
	// Source association occurs after construction, without changing the new
	// document's already-created font set or the owning global's realm.
	if previous := context.active_document() {
		if host := previous.get_browsing_context() {
			document.set_browsing_context(host)
			mut mutable_host := unsafe { &dom.BrowsingContext(host) }
			mutable_host.active_document_ = document
		}
		if host := previous.cached_navigable() {
			document.set_cached_navigable(host)
			mut mutable_host := unsafe { &dom.Navigable(host) }
			mutable_host.set_active_document(document)
			// The replacement becomes active here rather than through activate
			// history entry, so take that algorithm's initial visibility from
			// the navigable's traversable.
			if model := navigable_model_for_host(host) {
				document.set_initial_visibility_state(model.system_visibility_state())
			}
		}
		// This compact constructor activates the replacement directly. Perform
		// the outgoing document's activation cleanup as history traversal does,
		// before a reused Window is retargeted to the replacement document.
		mut mutable_previous := unsafe { &dom.Document(previous) }
		mutable_previous.did_stop_being_active_document_in_navigable()
	}
	_ = WindowModel.create_with_global(document, context, window)!
	return document
}

// Document::create_and_initialize steps 5–10, at the compact navigation host's
// existing boundary. The initial same-origin about:blank document retains its
// actual Window; other replacement documents acquire a fresh owner realm.
pub fn create_navigation_document(creation_url dom.URL, origin dom.Origin, previous ?&dom.Document) !&dom.Document {
	return create_navigation_document_with_optional_page(creation_url, origin, previous, none)
}

pub fn create_navigation_document_for_page(creation_url dom.URL, origin dom.Origin, previous ?&dom.Document, page &dom.Page) !&dom.Document {
	return create_navigation_document_with_optional_page(creation_url, origin, previous, page)
}

fn create_navigation_context(page ?&dom.Page) &BrowsingContextModel {
	if owner := page { return BrowsingContextModel.create_for_page(owner, none, '') }
	return BrowsingContextModel.create(none, none, '')
}

fn create_navigation_document_with_optional_page(creation_url dom.URL, origin dom.Origin, previous ?&dom.Document, page ?&dom.Page) !&dom.Document {
	mut owner := page
	if prior := previous {
		if prior.has_page() { owner = prior.page() }
	}
	context := if prior := previous {
		if host := prior.cached_navigable() {
			if model := navigable_model_for_host(host) {
				model.active_browsing_context() or { create_navigation_context(owner) }
			} else {
				create_navigation_context(owner)
			}
		} else {
			create_navigation_context(owner)
		}
	} else {
		create_navigation_context(owner)
	}
	if active := context.active_document() {
		if active.get_is_initial_about_blank() && active.origin().is_same_origin_domain(origin) {
			if window := context.active_window() {
				return construct_document_in_global(window, context, creation_url, origin)
			}
		}
	}
	mut top_level_creation_url := creation_url
	mut top_level_origin := origin
	if parent := context.parent() {
		if parent_document := parent.active_document() {
			settings := unsafe { &EnvironmentSettingsObject(parent_document.relevant_settings_object()) }
			if settings != unsafe { nil } {
				top_level_creation_url = settings.environment_.top_level_creation_url or {
					creation_url
				}

				top_level_origin = settings.environment_.top_level_origin or { origin }
			}
		}
	}
	window := create_window_global_before_document(context, creation_url, origin,
		top_level_creation_url, top_level_origin)
	return construct_document_in_global(window, context, creation_url, origin)
}

fn create_initial_document(context &BrowsingContextModel, origin dom.Origin, embedder ?&dom.Element) !&dom.Document {
	mut top_level_creation_url := dom.url_about_blank()
	mut top_level_origin := origin
	if element := embedder {
		settings := unsafe { &EnvironmentSettingsObject(element.document().relevant_settings_object()) }
		if settings != unsafe { nil } {
			top_level_creation_url = settings.environment_.top_level_creation_url or {
				dom.url_about_blank()
			}

			// Pinned BrowsingContext.cpp step 12 uses the embedder's origin.
			top_level_origin = settings.origin()
		}
	}
	window := create_window_global_before_document(context, dom.url_about_blank(), origin,
		top_level_creation_url, top_level_origin)
	return construct_document_in_global(window, context, dom.url_about_blank(), origin)
}
