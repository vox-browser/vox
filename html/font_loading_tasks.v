// HTML host boundary for FontFace and FontFaceSet completion tasks.
module html

import dom
import webidl
import highresolutiontime

fn font_loading_event_time_stamp_for_document(document &dom.Document) f64 {
	settings_pointer := document.relevant_settings_object()
	if settings_pointer == unsafe { nil } { return dom.current_event_timestamp() }
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	return highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin:                      settings.time_origin()
		cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
	})
}

fn font_loading_promise_context_for_document(document &dom.Document) webidl.PromiseContext {
	settings_pointer := document.relevant_settings_object()
	if settings_pointer == unsafe { nil } { return webidl.PromiseContext{} }
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	// The existing MainThreadVM promise-job adapter supplies realm entry and
	// delivery on the settings object's responsible microtask queue.
	return settings.stream_promise_context()
}

fn font_loading_task_for_document(document &dom.Document, associate_document bool, steps fn ()) bool {
	if document.has_been_destroyed() { return true }
	settings_pointer := document.relevant_settings_object()
	if settings_pointer == unsafe { nil } { return false }
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	mut task_document := ?&dom.Document(none)
	if associate_document { task_document = document }
	queue_a_task_with_storage(.font_loading, settings.responsible_event_loop(), task_document, steps,
		document.native_storage())
	return true
}
