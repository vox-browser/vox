// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import domurl
import html

@[heap]
struct URLSearchParamsHostRecord {
	host   &URLSearchParamsHost
	params &domurl.URLSearchParams
mut:
	object voidptr
}

@[heap]
struct URLSearchParamsIteratorHostRecord {
	iterator &domurl.URLSearchParamsIterator
	kind     domurl.URLSearchParamsIteratorKind
}

// The wrapper table owns genuine DOMURL query and iterator records in the
// current HTML environment. Engine values remain protected until Runtime.close.
@[heap]
pub struct URLSearchParamsHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime            &Runtime = unsafe { nil }
	prototype          voidptr
	iterator_prototype voidptr
	constructor        voidptr
	to_dom_string      voidptr
	iterator_result    voidptr
	records            map[voidptr]&URLSearchParamsHostRecord
	by_wrapper         map[voidptr]&URLSearchParamsHostRecord
	iterators          map[voidptr]&URLSearchParamsIteratorHostRecord
	closed             bool
}

pub fn URLSearchParamsHost.create(document &dom.Document) !&URLSearchParamsHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return URLSearchParamsHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn URLSearchParamsHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&URLSearchParamsHost {
	_ := settings.window_or_worker_global_scope()!
	return &URLSearchParamsHost{
		settings: settings
	}
}

pub fn (mut host URLSearchParamsHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.by_wrapper = {}
	host.iterators = {}
}
