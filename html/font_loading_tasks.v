// HTML host boundary for FontFace and FontFaceSet completion tasks.
module html

import dom

fn font_loading_task_for_document(document &dom.Document, associate_document bool, steps fn ()) bool {
	settings_pointer := document.relevant_settings_object()
	if settings_pointer == unsafe { nil } { return false }
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	mut task_document := ?&dom.Document(none)
	if associate_document { task_document = document }
	queue_a_task(.font_loading, settings.responsible_event_loop(), task_document, steps)
	return true
}
