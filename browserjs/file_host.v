// Copyright (c) 2022-2024, Kenneth Myhra <kennethmyhra@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fileapi
import html

@[heap]
struct FileHostRecord {
	host   &FileHost
	file   &fileapi.File
	object voidptr
}

// File.h::File : Blob owns one embedded Blob record and one native wrapper.
@[heap]
pub struct FileHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime     &Runtime  = unsafe { nil }
	blobs       &BlobHost = unsafe { nil }
	prototype   voidptr
	constructor voidptr
	records     map[voidptr]&FileHostRecord
	by_wrapper  map[voidptr]&FileHostRecord
	closed      bool
}

pub fn FileHost.create(document &dom.Document) !&FileHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return FileHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn FileHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&FileHost {
	_ := settings.window_or_worker_global_scope()!
	return &FileHost{ settings: settings }
}

pub fn (mut host FileHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.by_wrapper = {}
}
