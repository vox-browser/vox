// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fetch
import html
import requestserver

struct BrowserModuleSource {
	base      string
	options   html.ScriptFetchOptions
	referrer  fetch.Referrer
	top_level html.TopLevelModule
	code      ?string
}

@[heap]
struct BrowserModuleOperation {
	key     string
	source  BrowserModuleSource
	resolve voidptr
	reject  voidptr
mut:
	controller ?&fetch.FetchController
	finished   bool
}

@[heap]
struct BrowserModuleExecution {
	key              string
	element          ?&dom.Element
	blocks_readiness bool
mut:
	delayer   ?dom.DocumentLoadEventDelayer
	evaluated bool
	finished  bool
}

struct BrowserModuleCurrentScript {
	script ?&dom.HTMLScriptElement
}

// The native module loader uses the document's Fetch client, module map and
// import map, rather than JavaScript fetch() or an independent network client.
@[heap]
pub struct ModuleHost {
	settings  &html.EnvironmentSettingsObject
	transport &fetch.FetchHost
mut:
	runtime            &Runtime = unsafe { nil }
	connection         ?&requestserver.CurlConnection
	native_loader      voidptr
	transform          voidptr
	lexer_status       voidptr
	lexer_reported     bool
	source_value_reported bool
	normalization_reported bool
	helper_name        string
	sources            map[string]BrowserModuleSource
	operations         []&BrowserModuleOperation
	in_flight          map[string][]&BrowserModuleOperation
	executions         []&BrowserModuleExecution
	current_scripts    []BrowserModuleCurrentScript
	next_inline        int
	pending_scripts    int
	deferred_readiness []string
	diagnostics        []string
	closed             bool
	worker_entry       ?&WorkerModuleEntryResult
}

pub fn ModuleHost.create(settings &html.EnvironmentSettingsObject, transport &fetch.FetchHost) &ModuleHost {
	return &ModuleHost{ settings: settings, transport: transport }
}

pub fn ModuleHost.create_native(settings &html.EnvironmentSettingsObject) !&ModuleHost {
	mut connection := requestserver.CurlConnection.create()!
	mut host := ModuleHost.create(settings, connection.fetch_host())
	host.connection = connection
	return host
}

pub fn (host &ModuleHost) errors() []string { return host.diagnostics.clone() }

pub fn (runtime &Runtime) has_pending_module_scripts() bool {
	if host := runtime.module_host_ { return host.pending_scripts > 0 }
	return false
}
