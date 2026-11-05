// Window.cpp requestIdleCallback/cancelIdleCallback binding. The owning Window
// and HTML event loop own idle periods and timeouts; this adapter only retains
// the actual JSC callbacks.
module browserjs

import dom
import html

@[heap]
struct IdleCallbackHostRecord {
	function voidptr
mut:
	handle u32
}

@[heap]
pub struct IdleCallbackHost {
	window   &html.WindowModel
	settings &html.EnvironmentSettingsObject
	replay   ?AnimationFrameReplayHook
mut:
	runtime   &Runtime = unsafe { nil }
	records   map[u32]&IdleCallbackHostRecord
	installed bool
	closed    bool
}

pub fn IdleCallbackHost.create(document &dom.Document, replay ?AnimationFrameReplayHook) !&IdleCallbackHost {
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	window_pointer := document.get_window() or {
		return error('requestIdleCallback requires its owning Window')
	}
	return &IdleCallbackHost{
		window:   unsafe { &html.WindowModel(window_pointer) }
		settings: settings
		replay:   replay
	}
}

pub fn (mut host IdleCallbackHost) close() {
	if host.closed { return }
	host.closed = true
	mut window := unsafe { &html.WindowModel(host.window) }
	for handle, record in host.records {
		window.cancel_idle_callback(handle)
		host.runtime.release_javascript_value(record.function)
	}
	host.records = {}
}
