// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

enum WritableStreamHostKind {
	stream
	default_writer
	default_controller
}

@[heap]
struct WritableStreamHostRecord {
	host &WritableStreamHost
	kind WritableStreamHostKind
	native voidptr
mut:
	object voidptr
}

@[heap]
pub struct WritableStreamHost {
	document &dom.Document
	settings &html.EnvironmentSettingsObject
mut:
	runtime &Runtime = unsafe { nil }
	records map[voidptr]&WritableStreamHostRecord
	prototypes map[WritableStreamHostKind]voidptr
	to_number_ voidptr
	closed bool
}

pub fn WritableStreamHost.create(document &dom.Document) !&WritableStreamHost {
	mut settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return &WritableStreamHost{document: document, settings: unsafe { &html.EnvironmentSettingsObject(settings) }}
}

pub fn (mut host WritableStreamHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.prototypes = {}
}
