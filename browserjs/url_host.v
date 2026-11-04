// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import domurl
import html

@[heap]
struct URLHostRecord {
	host &URLHost
	url  &domurl.DOMURL
mut:
	object voidptr
}

@[heap]
pub struct URLHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime       &Runtime = unsafe { nil }
	prototype     voidptr
	constructor   voidptr
	to_dom_string voidptr
	records       map[voidptr]&URLHostRecord
	by_wrapper    map[voidptr]&URLHostRecord
	base_parser   domurl.URLBaseParser
	closed        bool
}

pub fn URLHost.create(document &dom.Document) !&URLHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return URLHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn URLHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&URLHost {
	_ := settings.window_or_worker_global_scope()!
	return &URLHost{
		settings: settings
	}
}

pub fn (mut host URLHost) close() {
	if host.closed { return }
	host.closed = true
	host.base_parser.clear()
	host.records = {}
	host.by_wrapper = {}
}
