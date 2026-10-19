// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Owning Window/Worker Crypto host; algorithms remain in the source DOM service.
module browserjs

import dom
import html

enum CryptoHostKind {
	crypto
	subtle
	key
}

@[heap]
struct CryptoHostRecord {
	host   &CryptoHost
	kind   CryptoHostKind
	native voidptr
mut:
	object voidptr
}

@[heap]
pub struct CryptoHost {
	settings &html.EnvironmentSettingsObject
	service  &html.GlobalScopeCrypto
mut:
	runtime             &Runtime = unsafe { nil }
	prototypes          map[CryptoHostKind]voidptr
	records             map[voidptr]&CryptoHostRecord
	by_wrapper          map[voidptr]&CryptoHostRecord
	array_is_view       voidptr
	view_validation     voidptr
	typed_array_witness voidptr
	buffer_validation   voidptr
	buffer_copy         voidptr
	to_dom_string       voidptr
	to_number           voidptr
	has_property        voidptr
	define_data         voidptr
	freeze_object       voidptr
	object_wrappers     map[u64]voidptr
	usage_sequence      voidptr
	string_sequence     voidptr
	prime_sequence      voidptr
	buffer_is_array     voidptr
	closed              bool
}

pub fn CryptoHost.create(document &dom.Document) !&CryptoHost {
	mut settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return CryptoHost.create_for_settings(unsafe { &html.EnvironmentSettingsObject(settings) })
}

pub fn CryptoHost.create_for_settings(settings &html.EnvironmentSettingsObject) !&CryptoHost {
	mut scope := settings.window_or_worker_global_scope()!
	return &CryptoHost{ settings: settings, service: scope.crypto() }
}

pub fn (mut host CryptoHost) close() {
	if host.closed { return }
	host.closed = true
	host.prototypes = {}
	host.records = {}
	host.by_wrapper = {}
	host.object_wrappers = {}
}
