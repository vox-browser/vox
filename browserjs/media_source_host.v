// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import mediasourceextensions

@[heap]
struct MediaSourceHostRecord {
	host   &MediaSourceHost
	source &mediasourceextensions.MediaSource
mut:
	object voidptr
}

enum MediaBufferHostKind {
	buffer
	list
}

fn (kind MediaBufferHostKind) webidl_name() string {
	return if kind == .buffer { 'SourceBuffer' } else { 'SourceBufferList' }
}

@[heap]
struct MediaBufferHostRecord {
	kind   MediaBufferHostKind
	native voidptr
	object voidptr
}

// Native MediaSource, buffer and list identity for this actual Window owner.
// Algorithms and live storage remain in the translated media records.
@[heap]
pub struct MediaSourceHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime           &Runtime = unsafe { nil }
	prototype         voidptr
	constructor       voidptr
	to_dom_string     voidptr
	to_number         voidptr
	records           map[voidptr]&MediaSourceHostRecord
	by_wrapper        map[voidptr]&MediaSourceHostRecord
	buffer_prototype  voidptr
	list_wrap         voidptr
	buffer_validation voidptr
	buffer_copy       voidptr
	buffer_records    map[voidptr]&MediaBufferHostRecord
	buffer_by_wrapper map[voidptr]&MediaBufferHostRecord
	closed            bool
}

pub fn MediaSourceHost.create(document &dom.Document) !&MediaSourceHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	owner := unsafe { &html.EnvironmentSettingsObject(settings) }
	if !owner.fetch_request_client_is_window() {
		return error('MediaSource native startup requires its actual Window owner')
	}
	return &MediaSourceHost{
		settings: owner
	}
}

pub fn (mut host MediaSourceHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.by_wrapper = {}
	host.buffer_records = {}
	host.buffer_by_wrapper = {}
}
