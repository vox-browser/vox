// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fetch
import html
import requestserver

enum FetchWrapperKind {
	headers
	request
	response
}

struct FetchOptionalBody {
	value ?fetch.BodyInit
}

struct FetchOptionalString {
	value ?string
}

@[heap]
struct FetchHostRecord {
	kind   FetchWrapperKind
	native voidptr
	object voidptr
}

@[heap]
struct FetchHostOperation {
	host       &FetchHost
	request    &fetch.RequestObject
	capability JavaScriptPromiseCapability
mut:
	controller      &fetch.FetchController = unsafe { nil }
	response        ?&fetch.ResponseObject
	abort_algorithm ?u64
	settled         bool
	finished        bool
}

// FetchMethod.cpp and Request/Response/Headers generated bindings share the
// actual Fetch records, transport, abort signals and owning HTML event loop.
@[heap]
pub struct FetchHost {
	settings  &html.EnvironmentSettingsObject
	transport &fetch.FetchHost
mut:
	runtime        &Runtime = unsafe { nil }
	connection     ?&requestserver.CurlConnection
	prototypes     map[FetchWrapperKind]voidptr
	by_wrapper     map[voidptr]&FetchHostRecord
	by_native      map[voidptr]voidptr
	operations     []&FetchHostOperation
	header_pairs   voidptr
	to_string      voidptr
	json_parse     voidptr
	json_serialize voidptr
	closed         bool
}

pub fn FetchHost.create(document &dom.Document, transport &fetch.FetchHost) !&FetchHost {
	mut settings := document.relevant_settings_object()
	if settings == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
		settings = document.relevant_settings_object()
	}
	return &FetchHost{ settings: unsafe { &html.EnvironmentSettingsObject(settings) }, transport: transport }
}

pub fn FetchHost.create_native(document &dom.Document) !&FetchHost {
	mut connection := requestserver.CurlConnection.create()!
	mut host := FetchHost.create(document, connection.fetch_host()) or {
		connection.close()
		return err
	}
	host.connection = connection
	return host
}

pub fn (mut host FetchHost) close() {
	if host.closed { return }
	host.closed = true
	for mut operation in host.operations {
		mut signal := operation.request.signal()
		if id := operation.abort_algorithm { signal.remove_abort_algorithm(id) }
		if operation.controller != unsafe { nil } { operation.controller.stop_fetch() }
	}
	if mut connection := host.connection { connection.close() }
	host.operations = []
	host.by_wrapper = {}
	host.by_native = {}
}
