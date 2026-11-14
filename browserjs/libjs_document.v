module browserjs

import dom
import html
import libjsdom

// The opt-in backend binds translated values directly to native DOM owners.
// It never initializes the compact JavaScriptCore bootstrap or a JSC context.
pub fn (mut runtime Runtime) install_libjs_document(document &dom.Document) ! {
	if runtime.closed { return error('JavaScript runtime is closed') }
	if runtime.engine != .libjs {
		return error('Native LibJS DOM bindings require the LibJS backend')
	}
	if runtime.libjs_document_host_ != none { return }
	owner := voidptr(&runtime)
	host := libjsdom.Host.create(runtime.agent_vm, runtime.realm, document, libjsdom.Hooks{
		can_run_callback: fn [owner] () bool {
			runtime := unsafe { &Runtime(owner) }
			if runtime.closed { return false }
			if settings := runtime.scripting_settings_ {
				return html.can_run_script_for_settings(settings) == .run
			}
			return true
		}
		before_callback:  fn [owner] () {
			mut runtime := unsafe { &Runtime(owner) }
			settings := runtime.callback_settings()
			runtime.libjs_callback_settings_ << settings
			runtime.prepare_html_callback(settings)
		}
		after_callback:   fn [owner] () {
			mut runtime := unsafe { &Runtime(owner) }
			settings := runtime.libjs_callback_settings_.pop()
			runtime.clean_up_html_callback(settings)
		}
		changed:          fn [owner] () {
			mut runtime := unsafe { &Runtime(owner) }
			runtime.mark_document_state_dirty()
		}
		console:          fn [owner] (message string) {
			mut runtime := unsafe { &Runtime(owner) }
			runtime.libjs_messages_ << message.clone()
			runtime.mark_document_state_dirty()
		}
		exception:        fn [owner] (message string) {
			mut runtime := unsafe { &Runtime(owner) }
			runtime.libjs_messages_ << 'JavaScript (LibJS): ' + message.clone()
			runtime.mark_document_state_dirty()
		}
	})!
	runtime.libjs_document_host_ = host
	runtime.add_close_handler(fn [host] () {
		mut owner := unsafe { &libjsdom.Host(host) }
		owner.close()
	})
}

pub fn (mut runtime Runtime) take_libjs_messages() []string {
	messages := runtime.libjs_messages_
	runtime.libjs_messages_ = []
	return messages
}

pub fn (runtime &Runtime) dispatch_libjs_event(name string, element &dom.Element) !bool {
	if runtime.closed || runtime.libjs_document_host_ == none {
		return error('LibJS document runtime is unavailable')
	}
	event := dom.Event.create(name, dom.EventInit{ bubbles: true, cancelable: true })
	target := unsafe { &dom.EventTarget(element) }
	target.dispatch_event(event)
	return event.default_prevented()
}
