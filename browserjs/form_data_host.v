// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import xhr

pub type FormDataBeforeConstructHook = fn (&Runtime) !

@[heap]
struct FormDataIteratorHostRecord {
	kind xhr.IteratorKind
mut:
	iterator xhr.FormDataIterator
}

// Genuine XHR/FormData records, with the same native File wrappers as Blob.
@[heap]
pub struct FormDataHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime            &Runtime  = unsafe { nil }
	blobs              &BlobHost = unsafe { nil }
	prototype          voidptr
	iterator_prototype voidptr
	iterator_result    voidptr
	by_wrapper         map[voidptr]&xhr.FormData
	wrappers           map[voidptr]voidptr
	iterators          map[voidptr]&FormDataIteratorHostRecord
	before_construct   ?FormDataBeforeConstructHook
	closed             bool
}

pub fn FormDataHost.create(document &dom.Document) !&FormDataHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return FormDataHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn FormDataHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&FormDataHost {
	_ := settings.window_or_worker_global_scope()!
	return &FormDataHost{ settings: settings }
}

pub fn (mut host FormDataHost) set_before_construct(hook ?FormDataBeforeConstructHook) {
	host.before_construct = hook
}

pub fn (mut host FormDataHost) close() {
	if host.closed { return }
	host.closed = true
	host.by_wrapper = {}
	host.wrappers = {}
	host.iterators = {}
	host.before_construct = none
}

fn serialize_native_form_data(data &xhr.FormData) html.SerializedFormData {
	mut entries := []html.FormDataEntry{cap: data.entries.len}
	for entry in data.entry_list() {
		entries << match entry.value {
			string { html.create_form_data_string_entry(entry.name, entry.value) }
			xhr.FormDataFile {
				html.create_form_data_native_file_entry(entry.name, entry.value.file)
			}
		}
	}
	return html.serialize_to_multipart_form_data(entries)
}
