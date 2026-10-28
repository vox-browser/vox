// Source WindowOrWorkerGlobalScope timers, exposed to the compact engine.
module browserjs

import dom
import html
import webidl

@[heap]
pub struct TimerHost {
	settings &html.EnvironmentSettingsObject
	scope &html.WindowOrWorkerGlobalScopeMixin
mut:
	runtime &Runtime = unsafe { nil }
	global_this_value_ webidl.Value
	ids map[i32][]voidptr
	closed bool
}

pub fn TimerHost.create(document &dom.Document) !&TimerHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return TimerHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn TimerHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&TimerHost {
	return &TimerHost{settings: settings, scope: settings.window_or_worker_global_scope()!}
}

pub fn (mut host TimerHost) close() {
	if host.closed { return }
	host.closed = true
	mut scope := unsafe { &html.WindowOrWorkerGlobalScopeMixin(host.scope) }
	for id in host.ids.keys() { scope.clear_timeout(id) }
	host.ids = {}
	scope.set_timer_classic_script_evaluator(none)
	scope.set_timer_compilation_exception_value_converter(none)
	scope.set_timer_removed_handler(none)
}
