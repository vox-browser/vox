module browserjs

import dom
import fetch
import html
import http
import time

@[heap]
struct ModuleTestRequests {
mut:
	urls []string
}

fn module_test_transport(sources map[string]string, seen &ModuleTestRequests) &fetch.FetchHost {
	return &fetch.FetchHost{
		perform: fn [sources, seen] (request &fetch.Request) !&fetch.Response {
			mut state := unsafe { &ModuleTestRequests(seen) }
			key := request.current_url().serialize()
			state.urls << key
			assert request.mode == .cors
			assert (request.destination or { panic('Missing module destination') }) == .script
			assert request.credentials_mode == .same_origin
			mut response := fetch.Response.create()
			response.url_list = request.url_list.clone()
			response.header_list.append(http.Header{ name: 'Content-Type', value: if key.ends_with('.txt') {
				'text/plain'
			} else {
				'text/javascript'
			} })
			if source := sources[key] {
				response.set_body_bytes(source.bytes())
			} else {
				response.status = 404
				response.set_body_bytes([])
			}
			return response
		}
	}
}

fn module_test_until(host &ModuleHost, runtime &Runtime, expression string) {
	deadline := time.sys_mono_now() + 5 * time.second
	mut loop := host.settings.responsible_event_loop()
	loop.spin_until(fn [runtime, expression, deadline] () bool {
		return runtime.evaluate_host(expression) or { 'false' } == 'true' || time.sys_mono_now() >= deadline
	})
	assert runtime.evaluate_host(expression) or { 'false' } == 'true', expression
}

fn test_native_modules_link_cycles_live_exports_import_maps_and_top_level_await() {
	$if !darwin {
		return
	}
	mut document := html.create_navigation_document(dom.URL{ value: 'https://modules.test/page' }, dom.URL{ value: 'https://modules.test/' }.origin(), none)!
	mut runtime := Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	owner := voidptr(runtime)
	runtime.define_value_host_function('__moduleHasOwner', fn [settings, owner] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		active := settings.realm().script_execution_depth > 0 && runtime.libjs_vm().has_running_execution_context()
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, active)
	})!
	mut scope := settings.universal_global_scope()
	map_ := html.parse_import_map_string('{"imports":{"counter":"/lib/counter.js","cycle":"/lib/cycle.js"}}', document.url)!
	scope.set_import_map(&map_)
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings, module_test_transport({
		'https://modules.test/lib/counter.js': "import {read} from 'cycle';export let count=40;export function increment(){count+=2;}export {read};globalThis.counterRuns=(globalThis.counterRuns||0)+1;"
		'https://modules.test/lib/cycle.js':   "import {count} from 'counter';export function read(){return count;}"
	}, seen))
	host.install(mut runtime)!
	runtime.evaluate_host('globalThis.console={error:message=>globalThis.moduleError=message}')!
	errors := runtime.run_document_scripts_collect_errors([ScriptSource{
		source_type: .module
		url:         'https://modules.test/main.js'
		code:        r'
import {count,increment,read} from "counter";
increment();globalThis.moduleOwnerBound=__moduleHasOwner();await Promise.resolve();globalThis.answer=count;globalThis.cycleValue=read();globalThis.metaURL=import.meta.url;
globalThis.imported=await import("counter");globalThis.metaResolved=import.meta.resolve("counter");globalThis.moduleDone=true;
'
	}])
	assert errors == []
	module_test_until(host, runtime, 'globalThis.moduleDone===true||globalThis.moduleError!==undefined')
	assert host.errors() == []string{}
	assert runtime.evaluate_host('answer===42&&cycleValue===42&&imported.count===42&&metaURL==="https://modules.test/main.js"&&metaResolved==="https://modules.test/lib/counter.js"&&counterRuns===1&&moduleOwnerBound')! == 'true'
	assert seen.urls.len == 2
	assert !runtime.has_pending_module_scripts()
	// Importing the same native module again must not re-evaluate its body.
	runtime.run_document_scripts_collect_errors([ScriptSource{ source_type: .module, url: 'https://modules.test/main.js', code: 'throw new Error("must stay cached")' }])
	module_test_until(host, runtime, 'globalThis.counterRuns===1&&!globalThis.moduleError')
	assert host.errors() == []string{}
}

fn test_native_dynamic_import_preserves_arguments_nested_imports_and_rejections() {
	$if !darwin {
		return
	}
	mut document := html.create_navigation_document(dom.URL{ value: 'https://dynamic.test/page' }, dom.URL{ value: 'https://dynamic.test/' }.origin(), none)!
	mut runtime := Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings, module_test_transport({
		'https://dynamic.test/value.js':   'export default 42;'
		'https://dynamic.test/name.js':    'export default "/value.js";'
		'https://dynamic.test/not-js.txt': 'globalThis.mimeExecuted=true;'
	}, seen))
	host.install(mut runtime)!
	assert runtime.run_document_scripts_collect_errors([ScriptSource{
		url:  document.url.serialize()
		code: r'
globalThis.results=[];globalThis.order=[];
const name={toString(){order.push("coerce");return "/value.js";}};
function options(){order.push("options");return {};}
const normal=import(name,options()).then(value=>results.push(value.default));
const nested=import((awaitName=>awaitName)("/name.js")).then(async ns=>{const value=await import(ns.default);results.push(value.default);});
const recursive=import(import("/name.js").then(ns=>ns.default)).catch(reason=>results.push(reason instanceof TypeError));
const unknown=import("missing-bare-name").catch(reason=>results.push(reason instanceof TypeError));
const symbol=import(Symbol()).catch(reason=>results.push(reason instanceof TypeError));
const mime=import("/not-js.txt").catch(reason=>results.push(reason instanceof TypeError));
Promise.all([normal,nested,recursive,unknown,symbol,mime]).then(()=>globalThis.dynamicDone=true);
'
	}]) == []
	module_test_until(host, runtime, 'globalThis.dynamicDone===true')
	assert runtime.evaluate_host('results.filter(x=>x===42).length===2&&results.filter(x=>x===true).length===4&&order.join() === "options,coerce"&&!globalThis.mimeExecuted')! == 'true'
	// Rewriting must leave these syntax errors for JavaScriptCore to reject.
	for invalid in ['import(...[])', 'import("/value.js",{},3)'] {
		assert runtime.run_document_scripts_collect_errors([ScriptSource{ code: invalid }]).len == 1
	}
	assert seen.urls.len == 3, seen.urls.str()
}

fn test_module_readiness_does_not_wait_for_top_level_await_and_close_releases_delayers() {
	$if !darwin {
		return
	}
	url := dom.URL{ value: 'https://readiness.test/page' }
	mut document := html.create_navigation_document(url, url.origin(), none)!
	mut runtime := Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut host := ModuleHost.create(settings, module_test_transport({}, &ModuleTestRequests{}))
	host.install(mut runtime)!
	script := document.create_element('script')!
	assert runtime.run_document_scripts_collect_errors([ScriptSource{
		source_type: .module
		url:         url.serialize()
		element:     script
		code:        'globalThis.inlineMeta=import.meta.url;await new Promise(resolve=>globalThis.releaseModule=resolve);globalThis.afterAwait=true;'
	}]) == []
	assert !document.claim_readiness_event('DOMContentLoaded')
	mut loop := settings.responsible_event_loop()
	loop.spin_until(fn [host] () bool { return host.pending_scripts == 0 })
	assert document.claim_readiness_event('DOMContentLoaded')
	assert !document.anything_is_delaying_the_load_event()
	assert runtime.evaluate_host('inlineMeta==="https://readiness.test/page"&&!globalThis.afterAwait&&typeof releaseModule==="function"')! == 'true'
	runtime.evaluate_host('releaseModule()')!
	assert runtime.evaluate_host('afterAwait')! == 'true'
	assert host.errors() == []string{}
	runtime.close()
	assert host.closed && host.native_loader == unsafe { nil }
}


fn test_classic_import_identifier_filter_preserves_execution_and_real_imports() {
	$if !darwin { return }
	mut document := html.create_navigation_document(dom.URL{value:'https://modules.test/page'}, dom.URL{value:'https://modules.test/'}.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	seen := &ModuleTestRequests{}
	mut host := ModuleHost.create(settings, module_test_transport({'https://modules.test/value.js':'export default 42;'}, seen))
	host.install(mut runtime)!
	plain := ScriptSource{url:'https://modules.test/plain.js',code:'globalThis.important="!important";function importer(){return 42}globalThis.importIdentifierValue=importer();'}
	plain_transform := host.transform_classic(plain)!
	assert plain_transform.code == plain.code
	assert runtime.run_document_scripts_collect_errors([plain]) == []string{}
	assert runtime.evaluate_host('importIdentifierValue===42&&important==="!important"')! == 'true'
	assert seen.urls.len == 0
	actual := ScriptSource{url:'https://modules.test/actual.js',code:'globalThis.importer=0;import /* still a token */ ("./value.js").then(ns=>globalThis.filteredImportValue=ns.default);'}
	actual_transform := host.transform_classic(actual)!
	assert actual_transform.code != actual.code
	assert runtime.run_document_scripts_collect_errors([actual]) == []string{}
	module_test_until(host, runtime, 'globalThis.filteredImportValue===42')
	assert seen.urls == ['https://modules.test/value.js']
}
