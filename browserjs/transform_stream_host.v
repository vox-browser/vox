// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

enum TransformStreamHostKind {
	stream
	default_controller
}

@[heap]
struct TransformStreamHostRecord {
	host   &TransformStreamHost
	kind   TransformStreamHostKind
	native voidptr
mut:
	object voidptr
}

@[heap]
pub struct TransformStreamHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime       &Runtime            = unsafe { nil }
	writable_host &WritableStreamHost = unsafe { nil }
	records       map[voidptr]&TransformStreamHostRecord
	prototypes    map[TransformStreamHostKind]voidptr
	closed        bool
}

pub fn TransformStreamHost.create(document &dom.Document) !&TransformStreamHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return TransformStreamHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })!
}

// Constructor state belongs to the actual Window or Worker environment.
pub fn TransformStreamHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&TransformStreamHost {
	_ = settings.window_or_worker_global_scope()!
	return &TransformStreamHost{ settings: settings }
}

pub fn (mut host TransformStreamHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.prototypes = {}
}
