module libjs

import os

struct DeferredGraphImport {
	referrer ImportedModuleReferrer
	request ModuleRequest
	payload ImportedModulePayload
}

@[heap]
struct ModuleGraphFixture {
mut:
	vm &VM
	realm &Realm
	sources map[string]string
	modules map[string]&SourceTextModule
	requests map[string]int
	pending []DeferredGraphImport
	deferred bool
}

fn new_module_graph_fixture(sources map[string]string) !&ModuleGraphFixture {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut fixture := &ModuleGraphFixture{vm:vm,realm:vm.realm(),sources:sources}
	for filename,source in sources {
		fixture.modules[filename]=SourceTextModule.parse(source,fixture.realm,filename,unsafe { nil })!
	}
	vm.host_load_imported_module=fn [fixture] (referrer ImportedModuleReferrer,request ModuleRequest,_ voidptr,payload ImportedModulePayload) {
		mut owner := unsafe { &ModuleGraphFixture(fixture) }
		key := os.clean_path(os.join_path(os.dir(referrer.filename()),request.module_specifier.str()))
		owner.requests[key]=(owner.requests[key] or { 0 })+1
		operation := DeferredGraphImport{referrer,request,payload}
		if owner.deferred { owner.pending << operation } else { owner.complete(operation) }
	}
	return fixture
}

fn (mut fixture ModuleGraphFixture) complete(operation DeferredGraphImport) {
	key := os.clean_path(os.join_path(os.dir(operation.referrer.filename()),operation.request.module_specifier.str()))
	result := if target := fixture.modules[key] { ModuleLoadResult.from_module(Module(target)) } else {
		ModuleLoadResult.from_error(fixture.vm.throw_error(.syntax_error,'Missing fixture module ${key}'))
	}
	finish_loading_imported_module(operation.referrer,operation.request,operation.payload,result)
}

fn (mut fixture ModuleGraphFixture) load_and_link(filename string) !&SourceTextModule {
	mut entry := fixture.modules[filename] or { return error('Missing entry') }
	capability := entry.load_requested_modules(mut fixture.vm,unsafe { nil })
	if capability.promise.state==.rejected { return throw_completion(capability.promise.result) }
	assert capability.promise.state==.fulfilled
	entry.link(mut fixture.vm)!
	return entry
}

fn test_module_graph_imports_and_reexports_retain_live_binding_identity() {
	mut fixture := new_module_graph_fixture({
		'/a.js':'export let n=1;export function inc(){n++}'
		'/bridge.js':'export {n as value,inc} from "./a.js";export * from "./a.js";'
		'/main.js':'import {value,inc} from "./bridge.js";export function current(){return value}inc();export default value;'
	})!
	mut entry := fixture.load_and_link('/main.js')!
	assert entry.evaluate(mut fixture.vm)!.promise.state==.fulfilled
	assert entry.export_value(mut fixture.vm,utf16_string('default'))!.number==2
	function := entry.export_value(mut fixture.vm,utf16_string('current'))!
	assert call(mut fixture.vm,function,js_undefined(),[])!.number==2
	a := fixture.modules['/a.js']!
	call(mut fixture.vm,a.export_value(mut fixture.vm,utf16_string('inc'))!,js_undefined(),[])!
	assert call(mut fixture.vm,function,js_undefined(),[])!.number==3
	assert entry.export_value(mut fixture.vm,utf16_string('default'))!.number==2
	assert fixture.requests['/a.js']==1
	assert fixture.vm.execution_context_stack().len==1
	assert fixture.vm.interpreter_stack().depth()==0
}

fn test_module_graph_cycles_hoist_functions_and_preserve_lexical_tdz() {
	mut fixture := new_module_graph_fixture({
		'/a.js':'import {readB} from "./b.js";export let a=1;export function readA(){return a}export const total=readB();'
		'/b.js':'import {readA} from "./a.js";export function readB(){return 2}export const seen=typeof readA;'
	})!
	mut entry := fixture.load_and_link('/a.js')!
	assert entry.evaluate(mut fixture.vm)!.promise.state==.fulfilled
	assert entry.export_value(mut fixture.vm,utf16_string('total'))!.number==2
	b := fixture.modules['/b.js']!
	assert b.export_value(mut fixture.vm,utf16_string('seen'))!.as_string().str()=='function'
	mut failure := new_module_graph_fixture({
		'/a.js':'import {b} from "./b.js";export const a=1;'
		'/b.js':'import {a} from "./a.js";globalThis.attempts=(globalThis.attempts||0)+1;export const b=a;'
	})!
	mut root := failure.load_and_link('/a.js')!
	first := root.evaluate(mut failure.vm)!
	assert first.promise.state==.rejected
	assert first.promise.result.as_object().error_kind()?==.reference_error
	assert voidptr(root.evaluate(mut failure.vm)!)==voidptr(first)
	mut failed_child := failure.modules['/b.js']!
	assert failed_child.evaluate(mut failure.vm)!.promise.state==.rejected
	mut global := failure.realm.global_object_record()
	assert global.get(mut failure.vm,PropertyName.from_str('attempts'))!.number==1
}

fn test_module_graph_namespace_reads_are_live_readonly_and_have_stable_identity() {
	mut fixture := new_module_graph_fixture({
		'/a.js':'let ten=10,two=2;export {ten as "10",two as "2"};export let n=1;export function inc(){n++}'
		'/bridge.js':'export * as bag from "./a.js";'
		'/main.js':'import * as ns from "./a.js";import {bag} from "./bridge.js";export function current(){return ns.n+bag.n}export {ns};'
	})!
	mut entry := fixture.load_and_link('/main.js')!
	assert entry.evaluate(mut fixture.vm)!.promise.state==.fulfilled
	mut a := fixture.modules['/a.js']!
	mut namespace := a.get_module_namespace(mut fixture.vm)!
	assert voidptr(namespace)==voidptr(a.get_module_namespace(mut fixture.vm)!)
	assert namespace.internal_get_prototype_of()==none
	assert !namespace.internal_is_extensible()
	keys := namespace.own_property_keys()
	assert keys[0].equals(PropertyName.from_str('10'))
	assert keys[1].equals(PropertyName.from_str('2'))
	assert namespace.get(mut fixture.vm,PropertyName.from_str('n'))!.number==1
	assert !namespace.internal_set(mut fixture.vm,PropertyName.from_str('n'),Value.from_i32(9),Value.from_object(namespace))!
	call(mut fixture.vm,a.export_value(mut fixture.vm,utf16_string('inc'))!,js_undefined(),[])!
	assert namespace.get(mut fixture.vm,PropertyName.from_str('n'))!.number==2
	assert call(mut fixture.vm,entry.export_value(mut fixture.vm,utf16_string('current'))!,js_undefined(),[])!.number==4
	assert voidptr(entry.export_value(mut fixture.vm,utf16_string('ns'))!.as_object())==voidptr(namespace)
}

fn test_module_graph_ambiguous_stars_are_omitted_and_named_imports_fail_before_evaluation() {
	for source in ['import {x} from "./barrel.js";', 'export {x} from "./barrel.js";'] {
		mut fixture := new_module_graph_fixture({
			'/a.js':'export const x=1;'
			'/b.js':'export const x=2;'
			'/barrel.js':'export * from "./a.js";export * from "./b.js";'
			'/main.js':source
		})!
		fixture.load_and_link('/main.js') or {
			assert thrown_value(err).as_object().error_kind()?==.syntax_error
			assert fixture.modules['/main.js']!.module_status==.unlinked
			continue
		}
		assert false,'Ambiguous named exports must fail during linking'
	}
	mut fixture := new_module_graph_fixture({
		'/a.js':'export const x=1;'
		'/b.js':'export const x=2;'
		'/barrel.js':'export * from "./a.js";export * from "./b.js";'
		'/main.js':'import * as ns from "./barrel.js";export default ns.x;'
	})!
	mut root := fixture.load_and_link('/main.js')!
	assert root.evaluate(mut fixture.vm)!.promise.state==.fulfilled
	assert root.export_value(mut fixture.vm,utf16_string('default'))!.is_undefined()
}

fn test_module_graph_loading_can_complete_asynchronously_and_rejects_once() {
	mut fixture := new_module_graph_fixture({
		'/a.js':'import "./b.js";import "./c.js";'
		'/b.js':'import "./d.js";'
		'/c.js':'import "./d.js";'
		'/d.js':'globalThis.sharedRuns=(globalThis.sharedRuns||0)+1;'
	})!
	fixture.deferred=true
	mut root := fixture.modules['/a.js']!
	loading := root.load_requested_modules(mut fixture.vm,unsafe { nil })
	assert loading.promise.state==.pending
	for fixture.pending.len>0 { operation := fixture.pending[0];fixture.pending.delete(0);fixture.complete(operation) }
	assert loading.promise.state==.fulfilled
	root.link(mut fixture.vm)!
	assert root.evaluate(mut fixture.vm)!.promise.state==.fulfilled
	mut globals := fixture.realm.global_object_record()
	assert globals.get(mut fixture.vm,PropertyName.from_str('sharedRuns'))!.number==1
	mut failed := new_module_graph_fixture({'/main.js':'import "./missing.js";import "./late.js";','/late.js':'export const x=1;'})!
	failed.deferred=true
	mut entry := failed.modules['/main.js']!
	result := entry.load_requested_modules(mut failed.vm,unsafe { nil })
	for failed.pending.len>0 { operation := failed.pending[0];failed.pending.delete(0);failed.complete(operation) }
	assert result.promise.state==.rejected
	assert result.promise.result.as_object().error_kind()?==.syntax_error
}

fn test_module_graph_uses_one_execution_budget_for_all_dependency_bodies() {
	mut fixture := new_module_graph_fixture({
		'/b.js':'for(var i=0;i<60;i++){}export const n=1;'
		'/main.js':'import {n} from "./b.js";for(var i=0;i<60;i++){}globalThis.finished=n;'
	})!
	mut root := fixture.load_and_link('/main.js')!
	result := root.evaluate_with_limits(mut fixture.vm,ExecutionLimits{max_instructions:1000})!
	assert result.promise.state==.rejected
	assert result.promise.result.as_object().error_message()?.contains('instruction budget')
	mut later := Script.parse('6*7',fixture.realm,'later.js',unsafe { nil })!
	assert fixture.vm.run(mut later)!.number==42
}

fn test_import_bindings_reject_assignment_without_changing_the_exporter() {
    mut fixture := new_module_graph_fixture({
        '/a.js':'export let n=1;'
        '/main.js':'import {n} from "./a.js";n=9;'
    })!
    mut root := fixture.load_and_link('/main.js')!
    result := root.evaluate(mut fixture.vm)!
    assert result.promise.state==.rejected
    assert result.promise.result.as_object().error_kind()?==.type_error
    assert fixture.modules['/a.js']!.export_value(mut fixture.vm,utf16_string('n'))!.number==1
}

fn test_module_requests_deduplicate_attribute_sets_without_requiring_key_order() {
    mut vm := VM.create()
    create_simple_execution_context(mut vm)
    module_record := SourceTextModule.parse('import "./a.js" with {type:"json",mode:"x"};import "./a.js" with {mode:"x",type:"json"};',vm.realm(),'/main.js',unsafe { nil })!
    assert module_record.requested_module_requests().len==1
}
