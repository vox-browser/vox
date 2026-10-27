// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

enum ReadableStreamHostKind {
	stream
	default_reader
	default_controller
	byte_controller
	byob_reader
}

@[heap]
struct ReadableStreamHostRecord {
	host   &ReadableStreamHost
	kind   ReadableStreamHostKind
	native voidptr
mut:
	object voidptr
}

// The owning-realm binding for source ReadableStream/default-reader methods.
// JS chunks, functions, controllers and capabilities use actual engine values
// and native records; the bridge never serializes them into JSON handles.
@[heap]
pub struct ReadableStreamHost {
	settings &html.EnvironmentSettingsObject
mut:
	runtime             &Runtime = unsafe { nil }
	records             map[voidptr]&ReadableStreamHostRecord
	prototypes          map[ReadableStreamHostKind]voidptr
	read_loop_byte_copy voidptr
	closed              bool
}

pub fn ReadableStreamHost.create(document &dom.Document) !&ReadableStreamHost {
	mut settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return ReadableStreamHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })!
}

// Constructor state belongs to the actual Window or Worker environment.
pub fn ReadableStreamHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&ReadableStreamHost {
	_ = settings.window_or_worker_global_scope()!
	return &ReadableStreamHost{ settings: settings }
}

pub fn (mut host ReadableStreamHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.prototypes = {}
}
