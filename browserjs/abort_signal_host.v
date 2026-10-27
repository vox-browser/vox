// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

enum AbortSignalHostKind {
	signal
	controller
}

@[heap]
struct AbortSignalHostRecord {
	host   &AbortSignalHost
	kind   AbortSignalHostKind
	native voidptr
mut:
	object voidptr
}

@[heap]
pub struct AbortSignalHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime    &Runtime = unsafe { nil }
	records    map[voidptr]&AbortSignalHostRecord
	prototypes map[AbortSignalHostKind]voidptr
	closed     bool
}

pub fn AbortSignalHost.create(document &dom.Document) !&AbortSignalHost {
	mut settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return AbortSignalHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })!
}

// Constructor state belongs to the actual Window or Worker environment.
pub fn AbortSignalHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&AbortSignalHost {
	_ = settings.window_or_worker_global_scope()!
	return &AbortSignalHost{ settings: settings }
}

pub fn (mut host AbortSignalHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.prototypes = {}
}
