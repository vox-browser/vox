// SPDX-License-Identifier: BSD-2-Clause
// Navigator ID, language and system-state bindings for the owning Window.
module browserjs

import dom
import html
import loader

@[heap]
pub struct NavigatorHost {
	settings  &html.EnvironmentSettingsObject
	navigator &html.Navigator
mut:
	runtime          &Runtime = unsafe { nil }
	closed           bool
	wrapper          voidptr
	frozen_languages voidptr
	cached_languages []string
	freeze           voidptr
}

pub fn NavigatorHost.create(document &dom.Document) !&NavigatorHost {
	if !loader.is_initialized() { loader.initialize() }
	if document.relevant_settings_object() == unsafe { nil } {
		_ = html.WindowModel.create_top_level(document, none, '')!
	}
	window_pointer := document.get_window() or {
		return error('Navigator requires its owning Window')
	}
	window := unsafe { &html.WindowModel(window_pointer) }
	return &NavigatorHost{
		settings:  unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		navigator: window.navigator()
	}
}

pub fn (mut host NavigatorHost) close() {
	host.closed = true
}
