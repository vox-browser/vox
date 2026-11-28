// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn event_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'event-constructor.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_event_constructor_uses_native_event_flags_and_unforgeable_trust() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert event_eval(mut vm, 'var e=new Event("toggle",{bubbles:true,cancelable:true,composed:true});var d=Object.getOwnPropertyDescriptor(e,"isTrusted");e instanceof Event&&e.type==="toggle"&&e.bubbles&&e.cancelable&&e.composed&&!e.isTrusted&&e.target===null&&e.currentTarget===null&&e.eventPhase===Event.NONE&&typeof e.timeStamp==="number"&&Object.prototype.toString.call(e)==="[object Event]"&&d.enumerable&&!d.configurable&&typeof d.get==="function"&&d.set===undefined&&Event.length===1')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('e'))!
	mut native := host.events[voidptr(value.as_object())] or { panic('Missing native Event') }
	assert native.type_ == 'toggle' && native.bubbles() && native.cancelable() && !native.is_trusted()
	native.prevent_default()
	assert event_eval(mut vm, 'e.defaultPrevented')!.as_bool()
	assert event_eval(mut vm, 'var passive=new Event(undefined,null);passive.preventDefault();passive.type==="undefined"&&!passive.bubbles&&!passive.cancelable&&!passive.composed&&!passive.defaultPrevented&&Event.AT_TARGET===2&&Event.prototype.BUBBLING_PHASE===3')!.as_bool()
	assert event_eval(mut vm, 'new Event("\\ud800").type.charCodeAt(0)===55296')!.as_bool()
}

fn test_event_dictionary_order_exceptions_and_brand_validation() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert event_eval(mut vm, 'var order="",o={},t={toString:function(){order+="t";return "x"}};Object.defineProperty(o,"bubbles",{get:function(){order+="b";return 1}});Object.defineProperty(o,"cancelable",{get:function(){order+="c";return 0}});Object.defineProperty(o,"composed",{get:function(){order+="p";return true}});var e=new Event(t,o);order==="tbcp"&&e.bubbles&&!e.cancelable&&e.composed')!.as_bool()
	for source in ['Event("x")', 'new Event()', 'new Event("x",true)', 'new Event(Symbol())', 'Event.prototype.preventDefault.call({})'] {
		assert event_eval(mut vm, 'var caught=false;try{'+source+'}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	}
	assert event_eval(mut vm, 'var o={};Object.defineProperty(o,"bubbles",{get:function(){throw 42}});var caught=false;try{new Event("x",o)}catch(e){caught=e===42};caught')!.as_bool()
}

fn test_github_toggle_event_shape_constructs_through_native_cache_in_a_fresh_vm() {
	directory := os.join_path(os.temp_dir(), 'vox-event-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut document := html.parse_document('<body></body>')
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), document, Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert event_eval(mut vm, 'class Toggle extends Event{oldState;newState;constructor(type,{oldState:old="",newState:next="",...init}={}){super(type,init);this.oldState=String(old||"");this.newState=String(next||"")}}var e=new Toggle("toggle",{oldState:"closed",newState:"open",cancelable:true});e instanceof Event&&e instanceof Toggle&&e.oldState==="closed"&&e.newState==="open"&&e.cancelable&&!e.isTrusted')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
