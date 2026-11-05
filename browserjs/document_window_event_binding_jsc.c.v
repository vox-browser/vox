module browserjs

import dom
import highresolutiontime


pub fn (mut runtime Runtime) install_document_window_event_binding(document &dom.Document, document_wrapper voidptr) ! {
	settings := runtime.scripting_settings_ or { return error('Document event binding requires its actual settings owner') }
	owner_document := settings.responsible_document() or { return error('Document event binding requires an actual Document') }
	if voidptr(document) != voidptr(owner_document) {
		return error('Document event binding belongs to another settings owner')
	}
	runtime.install_window_event_handler_binding()!
	runtime.bind_event_target(document_wrapper, unsafe { &dom.EventTarget(document) })!
	runtime.install_document_scrollend_handler(document_wrapper)!
	runtime.install_document_event_handlers(document_wrapper)!
	runtime.install_document_domain_attribute(document_wrapper)!
	factory := runtime.evaluate_host_value(document_window_event_method_factory())!
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(factory, global, [global, document_wrapper])!
}

// HTMLParser.cpp readiness event dispatch over the actual retained owner records.
// Compact loading still invokes this at its existing post-script phase; source
// parser task scheduling and parser-blocking execution remain a separate slice.
pub fn (runtime &Runtime) dispatch_document_readiness_event(name string) ! {
	settings := runtime.scripting_settings_ or { return error('Readiness event requires actual owning settings') }
	document := settings.responsible_document() or { return error('Readiness event requires an actual Document') }
	if name !in ['DOMContentLoaded', 'load'] { return error('Unknown document readiness event') }
	if mut host := runtime.module_host_ {
		waiting := if name == 'DOMContentLoaded' {
			host.executions.any(!it.finished && it.blocks_readiness)
		} else { host.pending_scripts > 0 }
		if waiting {
			if name !in host.deferred_readiness { host.deferred_readiness << name }
			return
		}
	}
	mut owner := unsafe { &dom.Document(document) }
	if !owner.claim_readiness_event(name) { return }
	event := dom.Event.create(name, dom.EventInit{ bubbles: name == 'DOMContentLoaded' })
	mut mutable_event := unsafe { &dom.Event(event) }
	mutable_event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
		time_origin:                      settings.time_origin()
		cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
	}))
	target := if name == 'load' {
		settings.global_object()
	} else {
		unsafe { &dom.EventTarget(document) }
	}
	target.dispatch_event(event)
}
