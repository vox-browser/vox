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
	host   &WritableStreamHost
	kind   WritableStreamHostKind
	native voidptr
mut:
	object voidptr
}

@[heap]
pub struct WritableStreamHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime    &Runtime = unsafe { nil }
	records    map[voidptr]&WritableStreamHostRecord
	prototypes map[WritableStreamHostKind]voidptr
	to_number_ voidptr
	closed     bool
}

pub fn WritableStreamHost.create(document &dom.Document) !&WritableStreamHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return WritableStreamHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })!
}

// Constructor state belongs to the actual Window or Worker environment.
pub fn WritableStreamHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&WritableStreamHost {
	_ = settings.window_or_worker_global_scope()!
	return &WritableStreamHost{ settings: settings }
}

pub fn (mut host WritableStreamHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.prototypes = {}
}
