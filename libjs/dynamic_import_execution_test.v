// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

struct PendingDynamicImport {
	referrer ImportedModuleReferrer
	request ModuleRequest
	payload ImportedModulePayload
}

@[heap]
struct DynamicImportFixture {
mut:
	vm &VM
	modules map[string]&SourceTextModule
	pending []PendingDynamicImport
	requests []PendingDynamicImport
	deferred bool
}

fn new_dynamic_import_fixture(sources map[string]string) !&DynamicImportFixture {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut fixture := &DynamicImportFixture{vm: vm}
	for filename, source in sources { fixture.modules[filename] = SourceTextModule.parse(source, vm.realm(), filename, unsafe { nil })! }
	vm.host_load_imported_module = fn [fixture] (referrer ImportedModuleReferrer, request ModuleRequest, _ voidptr, payload ImportedModulePayload) {
		mut state := unsafe { &DynamicImportFixture(fixture) }
		operation := PendingDynamicImport{referrer: referrer, request: request, payload: payload}
		state.requests << operation
		if state.deferred { state.pending << operation } else { state.complete(operation) }
	}
	return fixture
}

fn (mut fixture DynamicImportFixture) complete(operation PendingDynamicImport) {
	parent := if operation.referrer.kind == .realm { '/main.js' } else { operation.referrer.filename() }
	key := os.clean_path(os.join_path(os.dir(parent), operation.request.module_specifier.str()))
	result := if target := fixture.modules[key] { ModuleLoadResult.from_module(Module(target)) } else {
		ModuleLoadResult.from_error(fixture.vm.throw_error(.type_error, 'Missing fixture module ${key}'))
	}
	finish_loading_imported_module(operation.referrer, operation.request, operation.payload, result)
}

fn dynamic_import_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), '/main.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_dynamic_import_links_dependencies_once_and_resolves_live_stable_namespaces_as_jobs() {
	mut fixture := new_dynamic_import_fixture({
		'/dep.js': 'import {delta} from "./leaf.js";globalThis.order+="module;";globalThis.executions=(globalThis.executions||0)+1;export let value=40+delta;export function inc(){value++}'
		'/leaf.js': 'export const delta=2;'
	})!
	dynamic_import_eval(mut fixture.vm, 'var order="",first,second;var p=import("./dep.js");Promise.resolve().then(()=>order+="micro;");p.then(ns=>{first=ns;order+="then;"});order+="caller;"')!
	assert dynamic_import_eval(mut fixture.vm, 'order==="caller;module;micro;then;"&&first.value===42&&executions===1')!.as_bool()
	dynamic_import_eval(mut fixture.vm, 'import("./dep.js").then(ns=>{second=ns;ns.inc()})')!
	assert dynamic_import_eval(mut fixture.vm, 'first===second&&first.value===43&&executions===1&&Object.getPrototypeOf(first)===null&&!Object.isExtensible(first)')!.as_bool()
	assert fixture.requests[0].payload.kind == .promise_capability
	assert fixture.requests[0].payload.js_promise_capability != none
	assert fixture.requests[0].payload.promise_capability == none
	assert fixture.vm.take_promise_job_errors().len == 0
}

fn test_dynamic_import_waits_for_deferred_root_and_dependency_fetch_completion() {
	mut fixture := new_dynamic_import_fixture({
		'/dep.js': 'import {value} from "./leaf.js";export {value};'
		'/leaf.js': 'export const value=42;'
	})!
	fixture.deferred = true
	dynamic_import_eval(mut fixture.vm, 'var answer=0;import("./dep.js").then(ns=>answer=ns.value)')!
	assert fixture.pending.len == 1
	assert dynamic_import_eval(mut fixture.vm, 'answer')!.number == 0
	root := fixture.pending[0]; fixture.pending.delete(0); fixture.complete(root)
	fixture.vm.run_queued_promise_jobs()
	assert fixture.pending.len == 1
	assert dynamic_import_eval(mut fixture.vm, 'answer')!.number == 0
	leaf := fixture.pending[0]; fixture.pending.delete(0); fixture.complete(leaf)
	fixture.vm.run_queued_promise_jobs()
	assert dynamic_import_eval(mut fixture.vm, 'answer')!.number == 42
	assert fixture.vm.take_promise_job_errors().len == 0
}

fn test_dynamic_import_preserves_specifier_options_order_and_rejects_conversion_failures() {
	mut fixture := new_dynamic_import_fixture({'/dep.js': 'export const value=42;'})!
	dynamic_import_eval(mut fixture.vm, 'var order="",answer=0;function spec(){order+="specifier;";return {toString(){order+="convert;";return "./dep.js"}}}function options(){order+="options;";return {get with(){order+="attributes;";return undefined}}}import(spec(),options()).then(ns=>answer=ns.value)')!
	assert dynamic_import_eval(mut fixture.vm, 'order==="specifier;options;convert;attributes;"&&answer===42')!.as_bool()
	dynamic_import_eval(mut fixture.vm, 'var marker={},same=false;import({toString(){throw marker}}).catch(e=>same=e===marker)')!
	assert dynamic_import_eval(mut fixture.vm, 'same')!.as_bool()
	assert fixture.requests.len == 1
	assert dynamic_import_eval(mut fixture.vm, 'var touched=0,synchronous=false;function fail(){throw marker}try{import(fail(),touched++)}catch(e){synchronous=e===marker}synchronous&&touched===0')!.as_bool()
}

fn test_dynamic_import_attributes_snapshot_values_validate_strings_and_keep_utf16_key_order() {
	mut fixture := new_dynamic_import_fixture({'/dep.js': 'export const value=42;'})!
	fixture.vm.host_get_supported_import_attributes = fn () []Utf16String { return [utf16_string('a'), utf16_string('z')] }
	dynamic_import_eval(mut fixture.vm, 'var attrs={z:"last",a:"first"};Object.defineProperty(attrs,Symbol("skip"),{enumerable:true,get(){throw 1}});import("./dep.js",{with:attrs})')!
	assert fixture.requests.len == 1
	assert fixture.requests[0].request.attributes[0].key.str() == 'a'
	assert fixture.requests[0].request.attributes[1].key.str() == 'z'
	dynamic_import_eval(mut fixture.vm, 'var log="",rejected=false;var bad={get a(){log+="a";return 1},get z(){log+="z";return "ok"}};import("./dep.js",{with:bad}).catch(e=>rejected=e instanceof TypeError)')!
	assert dynamic_import_eval(mut fixture.vm, 'rejected&&log==="az"')!.as_bool()
	for options in ['null', '1', '{with:null}', '{with:{unsupported:"value"}}'] {
		dynamic_import_eval(mut fixture.vm, 'var rejected=false;import("./dep.js",${options}).catch(e=>rejected=e instanceof TypeError)')!
		assert dynamic_import_eval(mut fixture.vm, 'rejected')!.as_bool()
	}
	assert fixture.requests.len == 1
}

fn test_dynamic_import_rejects_fetch_link_and_evaluation_failures_with_original_values() {
	mut fixture := new_dynamic_import_fixture({
		'/bad.js': 'throw globalThis.marker;'
		'/link.js': 'import {missing} from "./empty.js";export const value=1;'
		'/empty.js': 'export const present=1;'
	})!
	dynamic_import_eval(mut fixture.vm, 'var marker={},fetchError=false,linkError=false,same=false;import("./missing.js").catch(e=>fetchError=e instanceof TypeError);import("./link.js").catch(e=>linkError=e instanceof SyntaxError);import("./bad.js").catch(e=>same=e===marker)')!
	assert dynamic_import_eval(mut fixture.vm, 'fetchError&&linkError&&same')!.as_bool()
	assert fixture.vm.take_promise_job_errors().len == 0
}

fn test_dynamic_import_uses_intrinsic_promise_and_respects_the_default_filesystem_gate() {
	mut fixture := new_dynamic_import_fixture({'/dep.js': 'export const value=42;'})!
	dynamic_import_eval(mut fixture.vm, 'var Original=Promise,answer=0;Promise=function(){throw 1};var imported=import("./dep.js");imported.then(ns=>answer=ns.value);Promise=Original')!
	assert dynamic_import_eval(mut fixture.vm, 'answer===42&&imported instanceof Original')!.as_bool()
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	dynamic_import_eval(mut vm, 'var rejected=false;import("./never-read.js").catch(e=>rejected=true)')!
	assert dynamic_import_eval(mut vm, 'rejected')!.as_bool()
	assert !vm.dynamic_imports_allowed() && vm.loaded_modules.len == 0
	assert dynamic_import_eval(mut vm, 'var changed=1;false&&import("./not-requested.js");changed')!.number == 1
}

fn test_cached_dynamic_import_and_module_bodies_run_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-dynamic-import-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut fixture := new_dynamic_import_fixture({'/dep.js': 'export const value=42;'})!
		fixture.vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		fixture.vm.diagnose_native_code(true)!
		dynamic_import_eval(mut fixture.vm, 'var answer=0;import("./dep.js").then(ns=>answer=ns.value)')!
		assert fixture.vm.realm().global_object_record().get(mut fixture.vm, PropertyName.from_str('answer'))!.number == 42
		activity := fixture.vm.diagnose_native_code(false)!
		stats := fixture.vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		fixture.vm.close_native_code()!
	}
}
