module browserjs

import dom
import fetch
import html
import http
import platform

@[heap]
struct WorkerScriptTestState {
mut:
	sources map[string]string
	requests []string
	mime string = 'text/javascript'
	muted bool
}

@[heap]
struct WorkerScriptErrors {
mut:
	values []dom.JSValue
}

fn worker_script_fixture() !(&Runtime, &WorkerScriptHost, &WorkerScriptTestState) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	url := dom.URL{value: 'https://worker-script.test/agents/map.js'}
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{}, realm)
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{
			creation_url: url
			api_base_url: url
			origin: url.origin()
			global: html.SerializedWorkerGlobalScope{relevant_settings_object_is_secure_context: true}
		}, 12)
	mut runtime := Runtime.create_for_worker()
	mut global := WorkerGlobalHost.create(environment)!
	global.install(mut runtime)!
	state := &WorkerScriptTestState{}
	state_ptr := voidptr(state)
	settings := environment.settings
	mut host := WorkerScriptHost.create(environment, fn [state_ptr, settings] (request &fetch.Request, top html.TopLevelModule) !&fetch.Response {
		assert top == .yes
		assert (request.destination or { panic("Missing script destination") }) == fetch.Destination.script
		assert (request.parser_metadata or { panic("Missing parser metadata") }) == fetch.ParserMetadata.not_parser_inserted
		assert request.use_url_credentials
		assert request.client_present
		assert !request.client_is_window
		assert (request.client_creation_url or { panic("Missing client creation URL") }) == settings.fetch_request_client_creation_url()
		mut state := unsafe { &WorkerScriptTestState(state_ptr) }
		url := request.current_url()
		state.requests << url.serialize()
		source := state.sources[url.serialize()] or { return error('NetworkError: missing imported script') }
		mut response := fetch.Response.create()
		response.url_list = [url]
		response.response_type = if state.muted { .opaque } else { .default }
		response.header_list.append(http.Header{name: 'Content-Type', value: state.mime})
		response.set_body_bytes(source.bytes())
		return response
	})!
	host.install(mut runtime)!
	return runtime, host, state
}

fn test_worker_import_scripts_executes_nested_sources_in_its_actual_realm_and_source_context() {
	mut runtime, mut host, mut state := worker_script_fixture()!
	defer { runtime.close() }
	state.sources['https://worker-script.test/agents/one.js'] = 'order.push("one");__checkScript("https://worker-script.test/agents/one.js");importScripts("nested.js");'
	state.sources['https://worker-script.test/agents/nested.js'] = 'order.push("Санкт-Петербург 😀");__checkScript("https://worker-script.test/agents/nested.js");'
	state.sources['https://worker-script.test/two.js'] = 'order.push("two");__checkScript("https://worker-script.test/two.js");'
	settings := host.environment.settings
	context := runtime.context
	owner := voidptr(runtime)
	runtime.define_value_host_function('__checkScript', fn [settings, context, owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		script := settings.realm().active_classic_script_ or { panic('Missing active imported script') }
		assert script.filename() == runtime.binding_dom_string(args[0])!
		assert settings.realm().script_execution_depth >= 2
		return C.vox_jsc_JSValueMakeBoolean(context, true)
	})!
	host.run('globalThis.order=[];importScripts("one.js","/two.js");order.push("done");', host.environment.global_scope.url(), .yes)!
	assert runtime.evaluate_host('order.join() === "one,Санкт-Петербург 😀,two,done"&&typeof document==="undefined"&&typeof window==="undefined"')! == 'true'
	assert state.requests == ['https://worker-script.test/agents/one.js', 'https://worker-script.test/agents/nested.js', 'https://worker-script.test/two.js']
	assert settings.realm().active_classic_script_ == none
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().reported_exceptions.len == 0
}

fn test_worker_import_scripts_converts_all_arguments_then_validates_all_urls_before_fetching() {
	mut runtime, mut host, mut state := worker_script_fixture()!
	defer { runtime.close() }
	state.sources['https://worker-script.test/agents/good.js'] = 'globalThis.loaded=true;'
	host.run(r'
 globalThis.loaded=false;globalThis.converted=[];globalThis.marker={};
 let preserved=false;try{importScripts({toString(){converted.push(1);return "good.js"}},{toString(){converted.push(2);throw marker}},{toString(){converted.push(3);return "never.js"}})}catch(error){preserved=error===marker}
 let syntax=false;try{importScripts("good.js","http://[")}catch(error){syntax=error instanceof DOMException&&error.name==="SyntaxError"}
 globalThis.validated=preserved&&syntax&&converted.join()==="1,2"&&!loaded;
 ', host.environment.global_scope.url(), .yes)!
	assert runtime.evaluate_host('validated')! == 'true'
	assert state.requests.len == 0
	assert runtime.evaluate_host(r'
 let errors=0;for(const call of [()=>importScripts(Symbol()),()=>importScripts.call({},"good.js"),()=>importScripts.call(new EventTarget(),"good.js"),()=>new importScripts()])try{call()}catch(error){if(error instanceof TypeError)errors++}
 errors===4&&importScripts()===undefined&&importScripts.call(null)===undefined&&importScripts.call(undefined)===undefined&&importScripts.name==="importScripts"&&importScripts.length===0&&!("prototype" in importScripts)&&Function.prototype.toString.call(importScripts).includes("[native code]");
 ')! == 'true'
	assert state.requests.len == 0
}

fn test_worker_import_scripts_preserves_thrown_values_stops_fetching_and_reports_network_failures() {
	mut runtime, mut host, mut state := worker_script_fixture()!
	defer { runtime.close() }
	state.sources['https://worker-script.test/agents/throw.js'] = 'throw marker;'
	state.sources['https://worker-script.test/agents/later.js'] = 'globalThis.later=true;'
	host.run(r'
 globalThis.marker={name:"tile decode failed"};globalThis.later=false;
 globalThis.original=false;try{importScripts("throw.js","later.js")}catch(error){original=error===marker}
 globalThis.network=false;try{importScripts("missing.js")}catch(error){network=error instanceof DOMException&&error.name==="NetworkError"}
 ', host.environment.global_scope.url(), .yes)!
	assert runtime.evaluate_host('original&&network&&!later')! == 'true'
	assert state.requests == ['https://worker-script.test/agents/throw.js', 'https://worker-script.test/agents/missing.js']
	assert host.environment.settings.realm().reported_exceptions.len == 0
	state.mime = 'text/plain'
	assert runtime.evaluate_host('try{importScripts("later.js");false}catch(error){error instanceof DOMException&&error.name==="NetworkError"&&!later}')! == 'true'
	state.mime = 'text/javascript'
	state.muted = true
	assert runtime.evaluate_host('try{importScripts("throw.js");false}catch(error){error instanceof DOMException&&error.name==="NetworkError"&&error!==marker}')! == 'true'
}

fn test_worker_import_scripts_preserves_module_rejection_and_performs_domstring_conversion_first() {
	mut runtime, mut host, state := worker_script_fixture()!
	defer { runtime.close() }
	mut scope := unsafe { &html.WorkerGlobalScope(host.environment.global_scope) }
	scope.worker_type = .module_
	assert runtime.evaluate_host(r'
 globalThis.converted=false;globalThis.marker={};let original=false,empty=false,one=false;
 try{importScripts({toString(){converted=true;throw marker}})}catch(error){original=error===marker}
 try{importScripts()}catch(error){empty=error instanceof TypeError}
 try{importScripts("one.js")}catch(error){one=error instanceof TypeError}
 original&&converted&&empty&&one;
 ')! == 'true'
	assert state.requests.len == 0
}

fn test_worker_classic_scripts_report_original_entry_errors_and_restore_nested_script_state() {
	mut runtime, mut host, mut state := worker_script_fixture()!
	defer { runtime.close() }
	observed := &WorkerScriptErrors{}
	host.environment.global_scope.this_impl().add_event_listener_without_options('error',
		dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [observed] (base_event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut errors := unsafe { observed }
				event := unsafe { &dom.ErrorEvent(base_event) }
				errors.values << event.error()
				return dom.js_undefined()
			}
		}))
	state.sources['https://worker-script.test/agents/broken.js'] = 'const = ;'
	host.run('globalThis.syntax=false;try{importScripts("broken.js")}catch(error){syntax=error instanceof SyntaxError}', host.environment.global_scope.url(), .yes)!
	assert runtime.evaluate_host('syntax')! == 'true'
	runtime.evaluate_host('globalThis.marker={message:"entry failed"};')!
	if _ := host.run('throw marker;', host.environment.global_scope.url(), .no) { assert false }
	settings := host.environment.settings
	assert settings.realm().reported_exceptions.len == 0
	assert observed.values.len == 1
	assert settings.realm().active_classic_script_ == none
	assert settings.realm().script_execution_depth == 0
	actual := runtime.actual_webidl_value(observed.values[0].native_value_ or { panic('Missing actual entry exception') })!
	assert runtime.call_engine_function(runtime.value_same_intrinsic_, [actual, runtime.evaluate_host_value('marker')!])! == C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
}

fn test_worker_script_adapter_keeps_retained_state_across_scratch_resets_and_closes_its_registration() {
	mut caller := platform.begin_thread_scratch('worker script caller')
	mut runtime, mut host, mut state := worker_script_fixture()!
	persistent := platform.enter_persistent()
	state.sources['https://worker-script.test/agents/retain.js'] = 'globalThis.retained=()=>"Санкт-Петербург 😀";'
	platform.leave_persistent(persistent)
	host.run('importScripts("retain.js");', host.environment.global_scope.url(), .yes)!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker script delivery')
	assert runtime.evaluate_host('retained()')! == 'Санкт-Петербург 😀'
	host.install(mut runtime)!
	mut duplicate := WorkerScriptHost.create(host.environment, none)!
	if _ := duplicate.install(mut runtime) { assert false }
	mut another := Runtime.create()
	if _ := host.install(mut another) { assert false }
	another.close()
	delivery.finish()
	runtime.close()
	assert voidptr(runtime) !in worker_script_bindings_
	assert runtime.protected_values_.len == 0
	if _ := host.run('true', host.environment.global_scope.url(), .yes) { assert false }
}
