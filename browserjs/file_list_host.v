// Copyright (c) 2022, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fileapi
import html

@[heap]
struct FileListHostRecord {
	host   &FileListHost
	list   &fileapi.FileList
	object voidptr
}

// Generated FileListWrapper owns the actual live FileAPI::FileList record.
@[heap]
pub struct FileListHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime       &Runtime  = unsafe { nil }
	files         &FileHost = unsafe { nil }
	prototype     voidptr
	constructor   voidptr
	wrap_function voidptr
	records       map[voidptr]&FileListHostRecord
	by_wrapper    map[voidptr]&FileListHostRecord
	closed        bool
}

pub fn FileListHost.create(document &dom.Document) !&FileListHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return FileListHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn FileListHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&FileListHost {
	_ := settings.window_or_worker_global_scope()!
	return &FileListHost{ settings: settings }
}

pub fn (mut host FileListHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.by_wrapper = {}
}
