// Copyright (c) 2022-2024, Kenneth Myhra <kennethmyhra@serenityos.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fileapi
import html

@[heap]
struct BlobHostRecord {
	host &BlobHost
	blob &fileapi.Blob
mut:
	object voidptr
}

// Actual immutable FileAPI records retain their owning relevant HTML realm.
// Author-created compatibility objects do not enter this wrapper table.
@[heap]
pub struct BlobHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime           &Runtime            = unsafe { nil }
	readable          &ReadableStreamHost = unsafe { nil }
	prototype         voidptr
	records           map[voidptr]&BlobHostRecord
	by_wrapper        map[voidptr]&BlobHostRecord
	to_dom_string     voidptr
	constructor       voidptr
	parts_sequence    voidptr
	buffer_kind       voidptr
	buffer_validation voidptr
	buffer_copy       voidptr
	closed            bool
}

pub fn BlobHost.create(document &dom.Document) !&BlobHost {
	mut settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return BlobHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn BlobHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&BlobHost {
	_ := settings.window_or_worker_global_scope()!
	return &BlobHost{ settings: settings }
}

pub fn (mut host BlobHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.by_wrapper = {}
}
