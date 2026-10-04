// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Source Window.cpp activation consumption and LocalNavigable.cpp active
// browsing-context/Window accessors on their actual native identity records.
module dom

import math

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#window-navigable
pub fn (window &Window) navigable() ?&Navigable {
	document := window.associated_document() or { return none }
	return document.navigable()
}

// LocalNavigable::active_browsing_context.
pub fn (navigable &Navigable) active_browsing_context() ?&BrowsingContext {
	document := navigable.active_document() or { return none }
	return document.get_browsing_context()
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#nav-wp
pub fn (navigable &Navigable) active_window_proxy() ?&WindowProxy {
	context := navigable.active_browsing_context() or { return none }
	return context.window_proxy()
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#nav-window
pub fn (navigable &Navigable) active_window() ?&Window {
	proxy := navigable.active_window_proxy() or { return none }
	return proxy.window()
}

pub fn (mut window Window) set_last_history_action_activation_timestamp(timestamp DOMHighResTimeStamp) {
	window.last_history_action_activation_timestamp = timestamp
}

// https://html.spec.whatwg.org/multipage/interaction.html#history-action-activation
pub fn (window &Window) has_history_action_activation() bool {
	return window.last_history_action_activation_timestamp != window.last_activation_timestamp
}

// Window.cpp consumes the active Windows of the local top-level traversable's
// active Document inclusive descendants. The explicit local-document source
// precondition remains here; each navigable owns its active Window lookup.
fn (window &Window) activation_consumption_windows() []&Window {
	navigable := window.navigable() or { return [] }
	top := navigable.top_level_traversable()
	document := top.active_document() or { panic('Window activation requires a local active top-level Document') }
	navigables := document.inclusive_descendant_navigables()
	mut windows := []&Window{cap: navigables.len}
	for descendant in navigables {
		windows << descendant.active_window() or { panic('Window activation requires an active descendant Window') }
	}
	return windows
}

// https://html.spec.whatwg.org/multipage/interaction.html#consume-user-activation
pub fn (window &Window) consume_user_activation() {
	for active_window in window.activation_consumption_windows() {
		if active_window.last_activation_timestamp != math.inf(1) {
			mut native := unsafe { &Window(active_window) }
			native.set_last_activation_timestamp(math.inf(-1))
		}
	}
}

// https://html.spec.whatwg.org/multipage/interaction.html#consume-history-action-user-activation
pub fn (window &Window) consume_history_action_user_activation() {
	for active_window in window.activation_consumption_windows() {
		mut native := unsafe { &Window(active_window) }
		native.set_last_history_action_activation_timestamp(active_window.last_activation_timestamp)
	}
}
