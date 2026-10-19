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
	host &QueuingStrategyHost
	kind QueuingStrategyHostKind
	native voidptr
mut:
	object voidptr
}

@[heap]
pub struct QueuingStrategyHost {
	document &dom.Document
	settings &html.EnvironmentSettingsObject
mut:
	scope &html.WindowOrWorkerGlobalScopeMixin
	runtime &Runtime = unsafe { nil }
	records map[voidptr]&QueuingStrategyHostRecord
	prototypes map[QueuingStrategyHostKind]voidptr
	functions map[voidptr]voidptr
	byte_length_get_v_ voidptr
	closed bool
}

pub fn QueuingStrategyHost.create(document &dom.Document) !&QueuingStrategyHost {
	mut settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	owner := unsafe { &html.EnvironmentSettingsObject(settings) }
	return &QueuingStrategyHost{document: document, settings: owner, scope: owner.window_or_worker_global_scope()!}
}

pub fn (mut host QueuingStrategyHost) close() {
	if host.closed { return }
	host.closed = true
	host.records = {}
	host.prototypes = {}
	host.functions = {}
}
