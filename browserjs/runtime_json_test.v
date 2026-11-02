module browserjs

import dom
import html
import platform

@[heap]
struct JSONInitializationTurn {
mut:
	factory_called bool
	job_saw_initialized_state bool
}

fn test_host_json_initialization_preserves_data_and_bypasses_replaced_json_parser() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host('JSON.parse=function(){throw "author parser"};globalThis.calls=0')!
	roots_before := runtime.protected_values_.len
	runtime.initialize_host_from_json('(function(data){globalThis.actual=data;++calls})',
		r'{"__proto__":{"own":"data"},"text":"quote\"slash\\\u0000日本語😀","nested":[true,null,17]}')!
	assert runtime.evaluate_host('calls===1&&Object.hasOwn(actual,"__proto__")&&actual.__proto__.own==="data"&&Object.getPrototypeOf(actual)===Object.prototype')! == 'true'
	assert runtime.evaluate_host('actual.text==="quote\\\"slash\\\\"+String.fromCharCode(0)+"日本語😀"')! == 'true'
	assert runtime.evaluate_host('actual.nested[0]===true&&actual.nested[1]===null&&actual.nested[2]===17')! == 'true'
	assert runtime.protected_values_.len == roots_before
}

fn test_host_json_initialization_releases_roots_after_invalid_data_or_thrown_factory() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	roots_before := runtime.protected_values_.len
	if _ := runtime.initialize_host_from_json('(function(){globalThis.unexpected=true})', '{invalid}') {
		assert false, 'invalid JSON was accepted'
	}
	assert runtime.evaluate_host('typeof unexpected')! == 'undefined'
	assert runtime.protected_values_.len == roots_before
	if _ := runtime.initialize_host_from_json('(function(){throw "factory failed"})', '{}') {
		assert false, 'factory exception was swallowed'
	} else {
  assert err is JavaScriptValueException
  if err is JavaScriptValueException { assert js_string_to_v(runtime.context, err.value)! == 'factory failed' }
 }
	// Thrown JavaScript values remain retained by the existing exception bridge.
	runtime.close()
	assert runtime.protected_values_.len == 0
	if _ := runtime.initialize_host_from_json('(function(){})', '{}') {
		assert false, 'closed runtime was accepted'
	}
}

fn test_host_json_factory_and_data_installation_share_one_html_script_turn() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://json-initialization.test/'}
	document := &dom.Document{url: url, origin_: url.origin()}
	window := html.WindowModel.create_top_level(document, none, 'json-initialization')!
	settings := unsafe { &html.EnvironmentSettingsObject(window.associated_document().relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut seen := &JSONInitializationTurn{}
	owner := voidptr(runtime)
	runtime.define_value_host_function('__initialized', fn [owner, settings, mut seen] (_ voidptr, _ []voidptr) !voidptr {
		assert settings.realm().script_execution_depth == 1
		seen.factory_called = true
		return C.vox_jsc_JSValueMakeUndefined(unsafe { &Runtime(owner) }.context)
	})!
	mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	event_loop.enqueue_microtask(html.Task.create(.microtask, none, fn [settings, mut seen] () {
		assert settings.realm().script_execution_depth == 0
		seen.job_saw_initialized_state = seen.factory_called
	}))
	runtime.initialize_host_from_json('(function(data){__initialized(data)})', '{"ready":true}')!
	assert seen.factory_called
	assert seen.job_saw_initialized_state
	assert event_loop.microtask_queue_empty()
}

fn test_host_json_initialization_copies_temporary_factory_and_json_input() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut input := platform.begin_thread_scratch('host JSON input')
	factory := '(function(data){globalThis.retained=data;globalThis.readRetained=function(){return retained.text}})'.clone()
	json := r'{"text":"temporary 日本語😀","values":[1,2,3]}'.clone()
	input.leave()
	runtime.initialize_host_from_json(factory, json)!
	input.finish()
	gc_collect()
	assert runtime.evaluate_host('readRetained()')! == 'temporary 日本語😀'
	assert runtime.evaluate_host('retained.values.join(",")')! == '1,2,3'
}
