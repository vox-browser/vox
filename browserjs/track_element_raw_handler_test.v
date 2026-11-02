module browserjs

import dom
import html
import json2
import page

@[heap]
struct TrackRawFixture {
	runtime &Runtime
	wheel &ElementWheelHost
	media &MediaElementHost
	owner &page.Page
	document &dom.Document
	settings &html.EnvironmentSettingsObject
}

const track_raw_body = r'nrtRuns++;nrtChecks.push(this===nrtExpected&&arguments.length===1&&event===arguments[0]&&event===nrtEvent&&event.target===this&&event.currentTarget===this&&event instanceof Event&&window.event===event&&__nrtContext());return false;'

fn track_raw_fixture(install_media bool, install_document bool) !&TrackRawFixture {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://track-raw.example/base/'}
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<form id="form"><track id="track" onload="${track_raw_body}" onerror="${track_raw_body}"><track data-probe="lazy" onload="${track_raw_body}" onerror="return ("><track data-probe="invalid" onload="return ("><track data-probe="generic" onload="return false;"></form><div id="ordinary" onload="return false;"></div><video id="video" onload="return false;"></video>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut wheel := ElementWheelHost.create(document)!
	wheel.install(mut runtime)!
	mut media := MediaElementHost.create(document, none)!
	if install_media { media.install(mut runtime)! }
	runtime.evaluate_host('globalThis.window=globalThis;globalThis.document={scopeKey:"document"};globalThis.scopeKey="global";globalThis.nrtRuns=0;globalThis.nrtChecks=[];globalThis.nrtResolverCalls=0;globalThis.nrtBefore=null;globalThis.nrtResolverResult="normal";globalThis.nrtSpecs={};globalThis.nrtFacades={};0')!
	runtime.install_window_event_handler_binding()!
	runtime.install_window_current_event_binding()!
	handle := voidptr(runtime)
	runtime.define_value_host_function('__nrtContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		current := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(current.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0 && current.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	runtime.evaluate_host(r'
globalThis.nrtResolve=function(key){if(nrtFacades[key])return nrtFacades[key];const spec=nrtSpecs[key];if(!spec)return null;
 const o={addEventListener(){},removeEventListener(){}};
 if(spec.tag==="track"){
  if(typeof __ladybirdTrackElementBind!=="function")return null;
  nrtResolverCalls++;if(nrtBefore)nrtBefore(key);if(nrtResolverResult==="null")return null;if(nrtResolverResult==="throw")throw "unavailable track resolver";
  __ladybirdTrackElementBind(o,key);
 }else if(spec.tag!=="video")__ladybirdElementWheelBind(o,key,spec.tag,spec.namespace);else return null;
 nrtFacades[key]=o;return o;
};__ladybirdElementWheelSetResolver(nrtResolve);0')!
	for key, element in wheel.elements_for_binding() {
		runtime.evaluate_host('nrtSpecs[${json2.encode(key)}]=${json2.encode({'tag':element.local_name(),'namespace':element.namespace_uri() or { '' }})};0')!
		id := element.get_attribute_value('id')
		if id != '' { runtime.evaluate_host('globalThis[${json2.encode(id)}]=nrtResolve(${json2.encode(key)});0')! }
	}
	runtime.evaluate_host('nrtResolverCalls=0;0')!
	if install_document { runtime.install_document_window_event_binding(document, runtime.evaluate_host_value('document')!)! }
	return &TrackRawFixture{runtime:runtime,wheel:wheel,media:media,owner:owner,document:document,settings:settings}
}

fn track_raw_marked(fixture &TrackRawFixture, marker string) &dom.Element {
	for _, element in fixture.wheel.elements_for_binding() {
		if element.get_attribute_value('data-probe') == marker { return element }
	}
	panic('Missing track raw fixture ${marker}')
}

fn track_raw_balanced(fixture &TrackRawFixture, exceptions int) {
	assert fixture.settings.realm().reported_exceptions.len == exceptions
	assert fixture.settings.realm().script_execution_depth == 0 && fixture.settings.realm().callback_execution_depth == 0
	assert !fixture.runtime.libjs_vm().has_running_execution_context()
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0 && fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_track_raw_parsed_created_lazy_scopes_identity_and_one_event_error_signature() {
	$if !darwin { return }
	f := track_raw_fixture(true, true)!
	mut runtime := f.runtime
	defer { runtime.close();mut owned_document := f.document;owned_document.finalize() }
	lazy := track_raw_marked(f, 'lazy')
	target := unsafe { &dom.EventTarget(lazy) }
	checkpoint := f.settings.realm().microtask_checkpoint_count
	assert target.get_current_value_of_event_handler('load') != none
	assert f.settings.realm().microtask_checkpoint_count == checkpoint
	assert runtime.evaluate_host('nrtResolverCalls===1')! == 'true'
	assert unsafe { &dom.HTMLTrackElement(lazy) }.track_element_model_ == unsafe { nil }
	assert target.data.event_handler('error')?.value.kind == .string
	wrapper := runtime.javascript_event_target(target, none)!
	runtime.define_value_host_function('__nrtLazy', fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	runtime.evaluate_host('globalThis.lazy=__nrtLazy();globalThis.created={};__ladybirdTrackElementBind(created,"__created_nrt");0')!
	for owner in ['track','lazy','created'] {
		actual := runtime.native_event_target(runtime.evaluate_host_value(owner)!)!
		mut element := unsafe { &dom.Element(actual) }
		for name in ['load','error'] {
			if owner != 'track' { element.set_attribute_value('on' + name, track_raw_body) }
			slot := actual.data.event_handler(name)?
			listener := slot.listener?
			callback := actual.get_current_value_of_event_handler(name)?
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${track_raw_body}\n}'
			assert voidptr(actual.get_current_value_of_event_handler(name)?) == voidptr(callback)
			assert voidptr(slot.listener?) == voidptr(listener)
			assert runtime.evaluate_host('nrtExpected=${owner};nrtEvent=new Event("${name}",{cancelable:true});${owner}.on${name}.name==="on${name}"&&${owner}.on${name}.length===1&&Object.hasOwn(${owner}.on${name},"prototype")&&!${owner}.dispatchEvent(nrtEvent)&&nrtEvent.defaultPrevented&&nrtEvent.currentTarget===null')! == 'true'
		}
	}
	mut element := f.document.get_element_by_id('track')?
	actual := unsafe { &dom.EventTarget(element) }
	element.set_attribute_value('onwheel','return false;')
	assert actual.get_current_value_of_event_handler('wheel') != none
	assert !actual.dispatch_event(dom.Event.create('wheel',dom.EventInit{cancelable:true}))
	runtime.evaluate_host('Object.defineProperty(form,"scopeKey",{get(){throw "ancestor form scope"}});track.scopeKey="element";track.event=1;document.event=2;0')!
	element.set_attribute_value('onload', r'nrtChecks.push(scopeKey==="element");delete this.scopeKey;nrtChecks.push(scopeKey==="document");delete document.scopeKey;nrtChecks.push(scopeKey==="global"&&event===arguments[0]&&arguments.length===1&&new.target===undefined&&typeof __scopes==="undefined");return false;')
	assert runtime.evaluate_host('nrtEvent=new Event("load");!track.dispatchEvent(nrtEvent)&&nrtChecks.every(Boolean)&&nrtRuns===6')! == 'true'
	error_event := dom.ErrorEvent.create('error', dom.ErrorEventInit{EventInit:dom.EventInit{cancelable:true},message:'track failure',filename:'track.js',lineno:4,colno:9})
	error_wrapper := runtime.javascript_event(unsafe { &dom.Event(error_event) })!
	runtime.define_value_host_function('__nrtError', fn [error_wrapper] (_ voidptr, _ []voidptr) !voidptr { return error_wrapper })!
	assert runtime.evaluate_host('nrtExpected=track;nrtEvent=__nrtError();!track.dispatchEvent(nrtEvent)&&nrtChecks.every(Boolean)&&nrtRuns===7')! == 'true'
	element.set_attribute_value('onerror', 'return true;')
	assert actual.dispatch_event(dom.Event.create('error', dom.EventInit{cancelable:true}))
	track_raw_balanced(f, 0)
}

fn test_track_raw_parse_csp_and_owner_availability_preserve_or_null_only_the_requested_slot() {
	$if !darwin { return }
	f := track_raw_fixture(true, true)!
	mut runtime := f.runtime
	defer { runtime.close();mut owned_document := f.document;owned_document.finalize() }
	mut invalid := track_raw_marked(f, 'invalid')
	target := unsafe { &dom.EventTarget(invalid) }
	for body in ['return (','"use strict";let event;','}},globalThis.nrtRuns++,{onload:function(event){'] {
		invalid.set_attribute_value('onload', body)
		slot := target.data.event_handler('load')?
		listener := slot.listener?
		assert target.get_current_value_of_event_handler('load') == none && target.get_current_value_of_event_handler('load') == none
		assert slot.value.kind == .null_ && voidptr(slot.listener?) == voidptr(listener)
		assert runtime.evaluate_host('nrtResolverCalls===0&&nrtRuns===0')! == 'true'
		assert unsafe { &dom.HTMLTrackElement(invalid) }.track_element_model_ == unsafe { nil }
	}
	invalid.set_attribute_value('onload', 'return false;')
	slot := target.data.event_handler('load')?
	mut wheel := f.wheel
	resolver := wheel.resolver;wheel.resolver = unsafe { nil }
	assert target.get_current_value_of_event_handler('load') == none && slot.value.kind == .string
	wheel.resolver = resolver
	for result in ['null','throw'] {
		runtime.evaluate_host('nrtResolverResult=${json2.encode(result)};0')!
		assert target.get_current_value_of_event_handler('load') == none && slot.value.kind == .string
		track_raw_balanced(f, 0)
	}
	runtime.evaluate_host('nrtResolverResult="normal";0')!
	assert target.get_current_value_of_event_handler('load') != none
	assert unsafe { &dom.HTMLTrackElement(invalid) }.track_element_model_ == unsafe { nil }
	generic := unsafe { &dom.EventTarget(track_raw_marked(f,'generic')) }
	runtime.bind_event_target(runtime.evaluate_host_value('Object.create(EventTarget.prototype)')!, generic)!
	assert generic.get_current_value_of_event_handler('load') == none && generic.data.event_handler('load')?.value.kind == .string
	for id in ['ordinary','video'] {
		other := unsafe { &dom.EventTarget(f.document.get_element_by_id(id)?) }
		assert other.get_current_value_of_event_handler('load') == none && other.data.event_handler('load')?.value.kind == .string
	}
	mut element := f.document.get_element_by_id('track')?
	actual := unsafe { &dom.EventTarget(element) }
	callback := actual.get_current_value_of_event_handler('load')?
	mut document := f.document
	document.set_csp_hook(dom.DocumentCSPHook{inline_check:fn (_ voidptr,_ &dom.Element,kind string,_ string) bool { return kind=='script-attribute' }})
	element.set_attribute_value('onload','return (')
	assert voidptr(actual.get_current_value_of_event_handler('load')?) == voidptr(callback)
	assert element.get_attribute_value('onload') == 'return ('
	element.set_attribute_value('onstalled','return false;')
	assert actual.get_current_value_of_event_handler('stalled') == none
	track_raw_balanced(f, 0)
}

fn test_track_raw_missing_hosts_document_resolver_reentry_and_adoption_remain_recoverable() {
	$if !darwin { return }
	for missing_media in [true,false] {
		f := track_raw_fixture(!missing_media, missing_media)!
		mut runtime := f.runtime
		element := f.document.get_element_by_id('track')?
		target := unsafe { &dom.EventTarget(element) }
		assert target.get_current_value_of_event_handler('load') == none && target.data.event_handler('load')?.value.kind == .string
		if missing_media { mut media := f.media;media.install(mut runtime)! }
		else { runtime.install_document_window_event_binding(f.document,runtime.evaluate_host_value('document')!)! }
		assert target.get_current_value_of_event_handler('load') != none
		track_raw_balanced(f,0);runtime.close();mut owned_document := f.document;owned_document.finalize()
	}
	f := track_raw_fixture(true,true)!
	mut runtime := f.runtime
	defer { runtime.close();mut owned_document := f.document;owned_document.finalize() }
	mut lazy := track_raw_marked(f,'lazy')
	target := unsafe { &dom.EventTarget(lazy) }
	undefined := runtime.evaluate_host_value('undefined')!
	runtime.define_value_host_function('__nrtReplace',fn [lazy,undefined] (_ voidptr,_ []voidptr) !voidptr {
		mut element := unsafe { &dom.Element(lazy) };element.set_attribute_value('onload','globalThis.nrtRuns+=10;');return undefined
	})!
	runtime.evaluate_host('nrtBefore=()=>{nrtBefore=null;__nrtReplace()};0')!
	assert target.get_current_value_of_event_handler('load') == none
	assert target.data.event_handler('load')?.value.kind == .string && target.data.event_handler('load')?.value.string_data == 'globalThis.nrtRuns+=10;'
	assert target.get_current_value_of_event_handler('load') != none
	assert target.dispatch_event(dom.Event.create('load',dom.EventInit{}))
	assert runtime.evaluate_host('nrtRuns===10')! == 'true'
	url := dom.URL{value:'https://adopted-track-raw.example/'}
	mut adopted := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
	defer { adopted.finalize() }
	adopted.adopt_node(lazy.as_node())
	assert target.get_current_value_of_event_handler('load') != none
	lazy.set_attribute_value('onload','globalThis.nrtRuns+=100;')
	assert target.get_current_value_of_event_handler('load') == none && target.data.event_handler('load')?.value.kind == .string
	track_raw_balanced(f,0)
}

fn test_track_raw_scripting_gate_strict_exceptions_and_close_keep_callback_ownership() {
	$if !darwin { return }
	f := track_raw_fixture(true,true)!
	mut runtime := f.runtime
	defer { runtime.close();mut owned_document := f.document;owned_document.finalize() }
	mut owner := f.owner
	mut element := f.document.get_element_by_id('track')?
	target := unsafe { &dom.EventTarget(element) }
	runtime.evaluate_host('globalThis.nrtThrown={};globalThis.nrtLater=0;globalThis.nrtStrict=false;EventTarget.prototype.addEventListener.call(track,"error",()=>nrtLater++);0')!
	owner.set_is_scripting_enabled(false)
	element.set_attribute_value('onerror',r'"use strict";nrtRuns++;nrtStrict=this===globalThis.track&&track===this.track&&arguments.length===1&&event===arguments[0]&&__nrtContext();throw nrtThrown;')
	assert target.get_current_value_of_event_handler('error') == none && target.data.event_handler('error')?.value.kind == .string
	assert target.dispatch_event(dom.Event.create('error',dom.EventInit{}))
	owner.set_is_scripting_enabled(true)
	callback := target.get_current_value_of_event_handler('error')?
	assert target.dispatch_event(dom.Event.create('error',dom.EventInit{}))
	assert runtime.evaluate_host('nrtRuns===1&&nrtLater===1&&nrtStrict&&window.event===undefined')! == 'true'
	assert runtime.actual_webidl_value(f.settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('nrtThrown')!
	assert voidptr(target.get_current_value_of_event_handler('error')?) == voidptr(callback)
	track_raw_balanced(f,1)
	element.set_attribute_value('onerror','return false;')
	runtime.close()
	assert target.get_current_value_of_event_handler('error') == none && target.data.event_handler('error')?.value.kind == .string
	assert f.media.closed && f.wheel.closed && runtime.protected_values_.len == 0
	track_raw_balanced(f,1)
}
