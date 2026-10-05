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

// Native identity and the MediaSource operations needed by the object-URL
// attachment path. SourceBuffer/List and worker exposure have separate owners.
@[heap]
pub struct MediaSourceHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime       &Runtime = unsafe { nil }
	prototype     voidptr
	constructor   voidptr
	to_dom_string voidptr
	to_number     voidptr
	records       map[voidptr]&MediaSourceHostRecord
	by_wrapper    map[voidptr]&MediaSourceHostRecord
	closed        bool
}

pub fn MediaSourceHost.create(document &dom.Document) !&MediaSourceHost {
	mut settings := document.relevant_settings_object()
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
	host.records.clear()
	host.by_wrapper.clear()
}
