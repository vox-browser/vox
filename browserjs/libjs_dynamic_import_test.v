// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import fetch
import html
import http
import libjs
import time

@[heap]
struct LibJSDynamicImportObservation {
mut:
	urls []string
	finished bool
	answer int
	current_script_null bool
	same_namespace bool
}

fn test_libjs_dynamic_import_uses_document_transport_import_map_and_native_microtasks() {
	address := dom.URL{value: 'https://libjs-imports.test/page'}
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut scope := settings.universal_global_scope()
	import_map := html.parse_import_map_string('{"imports":{"named":"/dep.js"}}', address)!
	scope.set_import_map(&import_map)
	mut seen := &LibJSDynamicImportObservation{}
	sources := {
		'https://libjs-imports.test/dep.js': 'import {value} from "./leaf.js";export {value};'
		'https://libjs-imports.test/leaf.js': 'export const value=42;'
	}
	transport := &fetch.FetchHost{perform: fn [sources, seen] (request &fetch.Request) !&fetch.Response {
		mut state := unsafe { &LibJSDynamicImportObservation(seen) }
		key := request.current_url().serialize(); state.urls << key
		assert request.mode == .cors && request.credentials_mode == .same_origin
		assert (request.destination or { panic('Missing module destination') }) == .script
		mut response := fetch.Response.create(); response.url_list = request.url_list.clone()
		response.header_list.append(http.Header{name: 'Content-Type', value: 'text/javascript'})
		response.set_body_bytes((sources[key] or { return error('Unexpected module request: ${key}') }).bytes())
		return response
	}}
	mut vm := runtime.agent_vm
	complete := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype, fn [seen] (mut vm libjs.VM) !libjs.Value {
		mut state := unsafe { &LibJSDynamicImportObservation(seen) }
		state.answer = int(vm.argument(0).number)
		state.current_script_null = vm.argument(1).as_bool()
		state.same_namespace = vm.argument(2).as_bool()
		state.finished = true
		return libjs.js_undefined()
	}, 3, libjs.PropertyName.from_str('complete'), none)
	mut global := runtime.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('complete'), libjs.Value.from_object(complete.object), 0)
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	mut host := ModuleHost.create(settings, transport); host.install(mut runtime)!
	assert runtime.run_document_scripts_collect_errors([ScriptSource{
		url: 'https://libjs-imports.test/entry.js'
		code: 'var first;import("named").then(ns=>{first=ns;return import("named")}).then(ns=>complete(ns.value,document.currentScript===null,first===ns));'
	}]) == []string{}
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := settings.responsible_event_loop()
	// Native event-loop progress only: an evaluate() poll would conceal a job
	// left in the standalone VM queue by an asynchronous fetch completion.
	loop.spin_until(fn [seen, deadline] () bool { return seen.finished || time.sys_mono_now() >= deadline })
	assert seen.finished && seen.answer == 42 && seen.current_script_null && seen.same_namespace
	assert seen.urls == ['https://libjs-imports.test/dep.js', 'https://libjs-imports.test/leaf.js']
	assert host.errors() == []string{} && runtime.take_libjs_messages() == []string{}
	assert !runtime.native_context_initialized() && !vm.has_running_execution_context()
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}
