// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn media_fixture() !(&Host, &libjs.VM, &dom.Document) {
	address := dom.URL{value: 'https://libjs-media.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm, document
}

fn media_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-media-query.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_match_media_uses_actual_native_queries_viewport_and_event_target_prototype_graph() {
	mut host, mut vm, mut document := media_fixture()!
	defer { host.close() }
	assert media_eval(mut vm, 'var q=matchMedia("(min-width: 600px)");q instanceof MediaQueryList&&q instanceof EventTarget&&q.matches&&q.media==="(min-width: 600px)"&&matchMedia(q.media)!==q&&Object.getPrototypeOf(MediaQueryList)===EventTarget&&Object.getPrototypeOf(MediaQueryList.prototype)===EventTarget.prototype&&Object.prototype.toString.call(q)==="[object MediaQueryList]"&&matchMedia.length===1&&!matchMedia("not a valid query").matches&&matchMedia("").matches')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('q'))!
	native := host.media_queries[voidptr(value.as_object())] or { panic('Missing native media query') }
	assert voidptr(native.document_) == voidptr(document)
	document.set_viewport_rect(dom.Rect{0, 0, 500, 600})
	document.evaluate_media_queries_and_report_changes()
	assert media_eval(mut vm, 'q.matches===false')!.as_bool()
}

fn test_native_media_query_changes_share_legacy_modern_and_attribute_listeners_and_event_identity() {
	mut host, mut vm, mut document := media_fixture()!
	defer { host.close() }
	media_eval(mut vm, 'var q=matchMedia("(min-width: 600px)"),calls=0,attribute=0,identity=false,last;function listener(e){calls++;last=e;identity=this===q&&e.target===q&&e.currentTarget===q&&e instanceof MediaQueryListEvent&&e instanceof Event&&e.type==="change"&&e.media===q.media&&e.matches===q.matches}q.addListener(listener);q.addEventListener("change",listener);q.onchange=function(e){attribute++;if(e!==last)throw 1}')!
	document.evaluate_media_queries_and_report_changes()
	assert media_eval(mut vm, 'calls===0&&attribute===0')!.as_bool()
	document.set_viewport_rect(dom.Rect{0, 0, 500, 600})
	document.evaluate_media_queries_and_report_changes()
	assert media_eval(mut vm, 'calls===1&&attribute===1&&identity&&!last.matches&&last.currentTarget===null&&Object.prototype.toString.call(last)==="[object MediaQueryListEvent]"')!.as_bool()
	media_eval(mut vm, 'q.removeListener(listener);q.onchange=42;var objectCalls=0,object={handleEvent(e){if(this===object&&e.target===q)objectCalls++}};q.addListener(object)')!
	document.set_viewport_rect(dom.Rect{0, 0, 900, 600})
	document.evaluate_media_queries_and_report_changes()
	assert media_eval(mut vm, 'calls===1&&attribute===1&&objectCalls===1&&q.onchange===null')!.as_bool()
	media_eval(mut vm, 'q.removeEventListener("change",object)')!
	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	document.evaluate_media_queries_and_report_changes()
	assert media_eval(mut vm, 'objectCalls===1')!.as_bool()
}

fn test_media_query_event_native_constructor_subclasses_dictionary_order_and_utf16() {
	mut host, mut vm, _ := media_fixture()!
	defer { host.close() }
	assert media_eval(mut vm, 'var order="",type={toString(){order+="t";return "change"}},options={get bubbles(){order+="b";return true},get cancelable(){order+="c";return true},get composed(){order+="o";return true},get matches(){order+="m";return 1},get media(){order+="s";return "\\ud800"}};class E extends MediaQueryListEvent{answer=42}var event=new E(type,options);event instanceof E&&event instanceof MediaQueryListEvent&&event instanceof Event&&event.answer===42&&event.bubbles&&event.cancelable&&event.composed&&event.matches&&event.media.charCodeAt(0)===55296&&order==="tbcoms"&&Object.getPrototypeOf(MediaQueryListEvent)===Event')!.as_bool()
	assert media_eval(mut vm, 'var q=matchMedia("all"),seen=false;q.addListener(e=>{seen=e===event});q.dispatchEvent(event)&&seen&&!event.isTrusted')!.as_bool()
}

fn test_match_media_and_media_query_members_validate_required_arguments_native_brands_and_throws() {
	mut host, mut vm, _ := media_fixture()!
	defer { host.close() }
	assert media_eval(mut vm, 'var q=matchMedia("all"),count=0,coercions=0,marker={},same=false;for(var run of [()=>matchMedia(),()=>matchMedia(Symbol()),()=>matchMedia.call({},{toString(){coercions++;return "all"}}),()=>new MediaQueryList(),()=>MediaQueryList(),()=>q.addListener(),()=>q.addListener(42),()=>q.removeListener(),()=>MediaQueryList.prototype.addListener.call({},null),()=>MediaQueryListEvent(),()=>new MediaQueryListEvent(),()=>Object.getOwnPropertyDescriptor(MediaQueryListEvent.prototype,"matches").get.call(new Event("change"))])try{run()}catch(e){if(e instanceof TypeError)count++}try{matchMedia({toString(){throw marker}})}catch(e){same=e===marker}q.addListener(null);q.removeListener(undefined);count===12&&coercions===0&&same')!.as_bool()
}

fn test_cached_media_query_listener_runs_on_native_viewport_change_and_is_removed_at_close() {
	directory := os.join_path(os.temp_dir(), 'vox-media-query-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, mut document := media_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		media_eval(mut vm, 'var calls=0;var query=matchMedia("(min-width: 600px)");query.addListener(function(e){if(!e.matches)calls++})')!
		document.set_viewport_rect(dom.Rect{0, 0, 500, 600})
		document.evaluate_media_queries_and_report_changes()
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 1
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
		document.set_viewport_rect(dom.Rect{0, 0, 900, 600})
		document.evaluate_media_queries_and_report_changes()
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 1
	}
}
