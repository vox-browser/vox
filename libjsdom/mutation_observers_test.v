// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

@[heap]
struct MutationObservations {
mut:
	errors []string
}

fn mutation_fixture() !(&Host, &libjs.VM, &dom.Document, &MutationObservations) {
	document := html.parse_document('<body><div id="target" value="before"><span id="child"></span></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	seen := &MutationObservations{}
	mut host := Host.create(vm, vm.realm(), document, Hooks{exception: fn [seen] (message string) {
		mut state := unsafe { &MutationObservations(seen) }; state.errors << message
	}})!
	return host, vm, document, seen
}

fn mutation_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-mutation-observer.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_native_mutation_observers_batch_attribute_records_and_share_promise_fifo() {
	mut host, mut vm, _, seen := mutation_fixture()!
	defer { host.close() }
	mutation_eval(mut vm, 'var order="",records,identity=false,count=0,target=document.getElementById("target");class O extends MutationObserver{value=42};var observer=new O(function(list,self){order+="m";records=list;identity=this===observer&&self===observer;count++;if(count===1)target.setAttribute("value","again")});observer.observe(target,{attributeOldValue:true});Promise.resolve().then(()=>{order+="a"});target.setAttribute("value","after");Promise.resolve().then(()=>{order+="b"});order+="s"')!
	assert mutation_eval(mut vm, 'order==="sambm"&&count===2&&identity&&observer instanceof O&&observer instanceof MutationObserver&&observer.value===42&&Array.isArray(records)&&records.length===1&&records[0] instanceof MutationRecord&&records[0].target===target&&records[0].type==="attributes"&&records[0].attributeName==="value"&&records[0].attributeNamespace===null&&records[0].oldValue==="after"')!.as_bool()
	assert seen.errors.len == 0
}

fn test_native_mutation_records_preserve_added_removed_nodes_and_take_records() {
	mut host, mut vm, _, seen := mutation_fixture()!
	defer { host.close() }
	assert mutation_eval(mut vm, 'var called=0,target=document.getElementById("target"),child=document.getElementById("child"),o=new MutationObserver(()=>{called++});o.observe(target,{childList:true});var added=document.createElement("b");target.append(added);var a=o.takeRecords();target.removeChild(child);var r=o.takeRecords();o.disconnect();target.append(child);a.length===1&&a[0].type==="childList"&&a[0].addedNodes instanceof NodeList&&a[0].addedNodes===a[0].addedNodes&&a[0].addedNodes[0]===added&&a[0].removedNodes.length===0&&a[0].previousSibling===child&&a[0].nextSibling===null&&a[0].oldValue===null&&r[0].removedNodes[0]===child&&r[0].addedNodes.length===0&&o.takeRecords().length===0')!.as_bool()
	assert mutation_eval(mut vm, 'called===0')!.as_bool()
	assert seen.errors.len == 0
}

fn test_mutation_record_node_lists_materialize_independently_on_access() {
	mut host, mut vm, _, _ := mutation_fixture()!
	defer { host.close() }
	mutation_eval(mut vm, 'var record;var o=new MutationObserver(r=>record=r[0]);var target=document.getElementById("target");o.observe(target,{attributes:true});target.setAttribute("value","after")')!
	attribute := mutation_eval(mut vm, 'record.attributeName')!
	assert attribute.as_string().str() == 'value'
	record := mutation_eval(mut vm, 'record')!.as_object()
	binding := host.mutation_records[voidptr(record)] or { panic('missing MutationRecord binding') }
	assert binding.added == none && binding.removed == none
	assert mutation_eval(mut vm, 'record.addedNodes instanceof NodeList&&record.addedNodes===record.addedNodes&&record.addedNodes.length===0')!.as_bool()
	assert binding.added != none && binding.removed == none
	assert mutation_eval(mut vm, 'record.removedNodes===record.removedNodes&&record.removedNodes!==record.addedNodes')!.as_bool()
	assert binding.removed != none
}

fn test_mutation_observer_options_dictionary_order_original_exceptions_and_brands() {
	mut host, mut vm, _, seen := mutation_fixture()!
	defer { host.close() }
	assert mutation_eval(mut vm, 'var o=new MutationObserver(function(){}),target=document.getElementById("target"),order="",options={get attributeFilter(){order+="f";return [{toString(){order+="s";return "value"}}]},get attributeOldValue(){order+="o";return true},get attributes(){order+="a";return true},get characterData(){order+="c";return false},get characterDataOldValue(){order+="d";return false},get childList(){order+="l";return true},get subtree(){order+="t";return true}};o.observe(target,options);order==="fsoacdlt"&&MutationObserver.length===1&&MutationObserver.prototype.observe.length===1')!.as_bool()
	assert mutation_eval(mut vm, 'var marker={},caught=false;try{o.observe(target,{get attributeFilter(){throw marker}})}catch(e){caught=e===marker}var n=0;for(var action of [()=>MutationObserver(function(){}),()=>new MutationObserver({}),()=>o.observe(),()=>o.observe(target),()=>o.observe(target,{attributes:false,attributeOldValue:true}),()=>o.observe(target,{attributeFilter:null}),()=>MutationObserver.prototype.disconnect.call({}),()=>new MutationRecord(),()=>Object.getOwnPropertyDescriptor(MutationRecord.prototype,"type").get.call({})])try{action()}catch(e){if(e instanceof TypeError)n++}caught&&n===9')!.as_bool()
	assert seen.errors.len == 0
}

fn test_mutation_observer_native_writes_checkpoint_through_html_microtasks_and_filters() {
	mut host, mut vm, document, seen := mutation_fixture()!
	defer { host.close() }
	mutation_eval(mut vm, 'var called=0,last;var o=new MutationObserver(function(records){called++;last=records});o.observe(document.getElementById("target"),{subtree:true,attributeFilter:["value"],attributeOldValue:true})')!
	mut child := unsafe { &dom.Element(document.get_element_by_id('child')?) }
	child.set_attribute_value('ignored', 'no')
	child.set_attribute_value('value', 'yes')
	assert vm.promise_job_count() == 1
	html.perform_a_microtask_checkpoint()
	assert mutation_eval(mut vm, 'called===1&&last.length===1&&last[0].target===document.getElementById("child")&&last[0].oldValue===null&&last[0].attributeName==="value"')!.as_bool()
	assert seen.errors.len == 0
}

fn test_mutation_observer_callback_errors_are_reported_and_close_retires_native_delivery() {
	mut host, mut vm, document, seen := mutation_fixture()!
	mutation_eval(mut vm, 'var o=new MutationObserver(function(){throw new Error("observer callback failure")});o.observe(document.getElementById("target"),{attributes:true});document.getElementById("target").setAttribute("value","after")')!
	assert seen.errors.len == 1 && seen.errors[0].contains('observer callback failure')
	mut target := unsafe { &dom.Element(document.get_element_by_id('target')?) }
	target.set_attribute_value('value', 'queued')
	host.close()
	html.perform_a_microtask_checkpoint()
	host.mutation_queue.notify()
	target.set_attribute_value('value', 'closed')
	assert host.mutation_observers.len == 0 && seen.errors.len == 1
}

fn test_cached_mutation_observer_callback_runs_in_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-native-mutation-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, _, seen := mutation_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		mutation_eval(mut vm, 'var count=0;var o=new MutationObserver(function(records){count+=records.length});var target=document.getElementById("target");o.observe(target,{attributes:true});target.setAttribute("value","after")')!
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('count'))!.number == 1
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert seen.errors.len == 0
		vm.close_native_code()!
		host.close()
	}
}
