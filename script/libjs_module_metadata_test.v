module main

import dom
import adblock
import browserjs
import fetch
import html
import http
import time

fn testsuite_begin() { adblock.set_enabled(false) }

fn test_libjs_module_metadata_uses_the_fetch_response_base_and_owning_import_map() {
	address := dom.URL{value:'https://metadata.test/page'}
	mut document := html.create_navigation_document(address,address.origin(),none)!
	mut runtime := browserjs.Runtime.create_with_engine(.libjs)
	defer { runtime.close();document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut scope := settings.universal_global_scope()
	map_ := html.parse_import_map_string('{"imports":{"named":"/actual/chunk.js"}}',address)!
	scope.set_import_map(&map_)
	mut host := browserjs.ModuleHost.create(settings,&fetch.FetchHost{perform:fn (request &fetch.Request) !&fetch.Response {
		mut response := fetch.Response.create()
		response.url_list=request.url_list.clone()
		if request.current_url().serialize()=='https://metadata.test/dep.js' {
			response.status=302
			response.header_list.append(http.Header{name:'Location',value:'/redirected/dep.js'})
			response.set_body_bytes([])
			return response
		}
		response.header_list.append(http.Header{name:'Content-Type',value:'text/javascript'})
		response.set_body_bytes('export const url=import.meta.url;export const relative=import.meta.resolve("./next.js");export const named=import.meta.resolve("named");export function same(){return import.meta===import.meta}'.bytes())
		return response
	}})
	host.install(mut runtime)!
	assert runtime.run_document_scripts_collect_errors([browserjs.ScriptSource{source_type:.module,url:'https://metadata.test/main.js',code:'import {url,relative,named,same} from "./dep.js";globalThis.metadata=url+"|"+relative+"|"+named+"|"+same();globalThis.rootMeta=import.meta.url;'}])==[]string{}
	deadline := time.sys_mono_now()+5*time.second
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [runtime,deadline] () bool { return !runtime.has_pending_module_scripts() || time.sys_mono_now()>=deadline })
	assert !runtime.has_pending_module_scripts()
	assert host.errors()==[]string{},host.errors().str()
	actual := runtime.evaluate('metadata')!
	assert actual == 'https://metadata.test/redirected/dep.js|https://metadata.test/redirected/next.js|https://metadata.test/actual/chunk.js|true',actual
	assert runtime.evaluate('rootMeta')! == 'https://metadata.test/main.js'
	assert !runtime.native_context_initialized()
	assert runtime.libjs_vm().execution_context_stack().len==0
}
