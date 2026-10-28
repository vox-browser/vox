// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html

enum QueuingStrategyHostKind {
	count
	byte_length
}

@[heap]
struct QueuingStrategyHostRecord {
	host   &QueuingStrategyHost
	kind   QueuingStrategyHostKind
	native voidptr
mut:
	object voidptr
}

@[heap]
pub struct QueuingStrategyHost {
	settings &html.EnvironmentSettingsObject
mut:
	scope              &html.WindowOrWorkerGlobalScopeMixin
	runtime            &Runtime = unsafe { nil }
	records            map[voidptr]&QueuingStrategyHostRecord
	prototypes         map[QueuingStrategyHostKind]voidptr
	functions          map[voidptr]voidptr
	byte_length_get_v_ voidptr
	closed             bool
}

pub fn QueuingStrategyHost.create(document &dom.Document) !&QueuingStrategyHost {
	mut settings := unsafe { document.relevant_settings_object() }
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return QueuingStrategyHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })!
}

// Constructor state belongs to the actual Window or Worker environment.
pub fn QueuingStrategyHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&QueuingStrategyHost {
	return &QueuingStrategyHost{ settings: settings, scope: settings.window_or_worker_global_scope()! }
}

pub fn (mut host QueuingStrategyHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.prototypes = {}
	host.functions = {}
}
