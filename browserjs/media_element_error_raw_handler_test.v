module browserjs

import dom
import html
import json2
import page

@[heap]
struct MediaErrorRawFixture {
	runtime        &Runtime
	wheel_host     &ElementWheelHost
	media_host     &MediaElementHost
	owner          &page.Page
	document       &dom.Document
	settings       &html.EnvironmentSettingsObject
	resolver_probe &MediaErrorRawResolverProbe
}

@[heap]
struct MediaErrorRawResolverProbe {
mut:
	calls                  int
	without_html_execution int
	owner_contexts         bool = true
}

const media_error_raw_body = r'mediaErrorRawRuns++;mediaErrorRawChecks.push(ended===false&&networkState===0&&readyState===0&&paused===true&&currentTime===0&&currentTime===mediaErrorRawCurrentTimeGetter.call(this)&&this===mediaErrorRawExpected&&arguments.length===1&&event===arguments[0]&&event===mediaErrorRawExpectedEvent&&event instanceof Event&&event.target===this&&event.currentTarget===this&&event.isTrusted===mediaErrorRawTrusted&&window.event===event&&__mediaErrorRawContext());return false;'

fn media_error_raw_fixture(name string, install_media bool, install_document bool) !&MediaErrorRawFixture {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-media-error-raw.example.test/' }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<form id="mediaErrorRawForm"><video id="video" on${name}="${media_error_raw_body}"></video><audio id="audio" on${name}="${media_error_raw_body}"></audio><video data-raw-error="lazy" on${name}="${media_error_raw_body}" onwheel="return (" onplay="return ("></video><audio data-raw-error="invalid" on${name}="return ("></audio><audio data-raw-error="generic" on${name}="return false;"></audio></form><div id="ordinary" on${name}="return false;"></div>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut wheel_host := ElementWheelHost.create(document)!
	wheel_host.install(mut runtime)!
	mut media_host := MediaElementHost.create(document, none)!
	if install_media { media_host.install(mut runtime)! }
	runtime.evaluate_host('globalThis.window=globalThis;0')!
	runtime.install_window_event_handler_binding()!
	runtime.install_window_current_event_binding()!
	mut resolver_probe := &MediaErrorRawResolverProbe{}
	handle := voidptr(runtime)
	probe_handle := voidptr(resolver_probe)
	runtime.define_value_host_function('__mediaErrorRawRawResolverContext', fn [handle, probe_handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		mut probe := unsafe { &MediaErrorRawResolverProbe(probe_handle) }
		probe.calls++
		probe.owner_contexts = probe.owner_contexts && runtime.libjs_vm().has_running_execution_context()
			&& voidptr(runtime.libjs_vm().running_execution_context()) == voidptr(runtime.realm_context)
		if settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0 {
			probe.without_html_execution++
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	runtime.evaluate_host(r'
globalThis.mediaErrorRawRawSpecs=Object.create(null);globalThis.mediaErrorRawRawFacades=Object.create(null);
globalThis.mediaErrorRawResolverBefore=null;globalThis.mediaErrorRawResolverResult="normal";
globalThis.mediaErrorRawRawResolve=function(key){
 if(mediaErrorRawRawFacades[key])return mediaErrorRawRawFacades[key];
 const spec=mediaErrorRawRawSpecs[key];if(!spec)return null;
 const wrapper={addEventListener(){},removeEventListener(){}};
 if(spec.tag==="audio"||spec.tag==="video"){
  if(typeof __ladybirdMediaElementBind!=="function")return null;
  __mediaErrorRawRawResolverContext();
  if(typeof mediaErrorRawResolverBefore==="function")mediaErrorRawResolverBefore(key);
  if(mediaErrorRawResolverResult==="null")return null;
  if(mediaErrorRawResolverResult==="throw")throw "resolver owner unavailable";
  __ladybirdMediaElementBind(wrapper,key,spec.tag);
 }else __ladybirdElementWheelBind(wrapper,key,spec.tag,spec.namespace);
 mediaErrorRawRawFacades[key]=wrapper;return wrapper;
};
__ladybirdElementWheelSetResolver(mediaErrorRawRawResolve);0')!
	for key, element in wheel_host.elements_for_binding() {
		spec := json2.encode({
			'tag':       element.local_name()
			'namespace': element.namespace_uri() or { '' }
		})
		runtime.evaluate_host('mediaErrorRawRawSpecs[${json2.encode(key)}]=${spec};0')!
		id := element.get_attribute_value('id')
		if id != '' {
			runtime.evaluate_host('globalThis[${json2.encode(id)}]=mediaErrorRawRawResolve(${json2.encode(key)});0')!
		}
	}
	resolver_probe.calls = 0
	resolver_probe.without_html_execution = 0
	resolver_probe.owner_contexts = true
	runtime.define_value_host_function('__mediaErrorRawContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	runtime.evaluate_host('globalThis.document={scopeKey:"document",networkState:99,readyState:99,currentTime:99,paused:false,ended:true};globalThis.scopeKey="global";globalThis.networkState=123;globalThis.readyState=123;globalThis.currentTime=123;globalThis.paused=false;globalThis.ended=true;globalThis.mediaErrorRawCurrentTimeGetter=typeof HTMLMediaElement==="function"?Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"currentTime").get:null;globalThis.mediaErrorRawRuns=0;globalThis.mediaErrorRawChecks=[];0')!
	if install_document {
		runtime.install_document_window_event_binding(document,
			runtime.evaluate_host_value('document')!)!
	}
	return &MediaErrorRawFixture{ runtime: runtime, wheel_host: wheel_host, media_host: media_host,
		owner: owner, document: document, settings: settings, resolver_probe: resolver_probe }
}

fn media_error_raw_element_by_marker(fixture &MediaErrorRawFixture, marker string) &dom.Element {
	for _, element in fixture.wheel_host.elements_for_binding() {
		if element.get_attribute_value('data-raw-error') == marker { return element }
	}
	panic('missing marked raw media ${marker}')
}

fn media_error_raw_event(name string) &dom.Event {
	// Binding probes dispatch native Events directly. Browser owner fixtures
	// exercise the actual media failure algorithms separately.
	mut event := dom.Event.create(name, dom.EventInit{})
	event.set_is_trusted(true)
	return event
}

fn media_error_raw_assert_contexts(fixture &MediaErrorRawFixture) {
	assert fixture.settings.realm().script_execution_depth == 0
	assert fixture.settings.realm().callback_execution_depth == 0
	assert !fixture.runtime.libjs_vm().has_running_execution_context()
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_raw_media_error_parsed_created_and_lazy_handlers_take_one_event_with_native_scopes() {
	$if !darwin { return }
	fixture := media_error_raw_fixture('error', true, true)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	lazy_element := media_error_raw_element_by_marker(fixture, 'lazy')
	lazy_target := unsafe { &dom.EventTarget(lazy_element) }
	assert unsafe { &dom.HTMLVideoElement(lazy_element) }.media_element_model_ == unsafe { nil }
	checkpoint := fixture.settings.realm().microtask_checkpoint_count
	assert lazy_target.get_current_value_of_event_handler('error') != none
	assert fixture.resolver_probe.calls == 1 && fixture.resolver_probe.owner_contexts
	assert fixture.resolver_probe.without_html_execution == 1
	assert fixture.settings.realm().microtask_checkpoint_count == checkpoint
	assert unsafe { &dom.HTMLVideoElement(lazy_element) }.media_element_model_ != unsafe { nil }
	for name in ['wheel', 'play'] {
		slot := lazy_target.data.event_handler(name) or { panic('independent raw slot') }
		assert slot.value.kind == .string && slot.value.string_data == 'return ('
	}
	lazy_wrapper := runtime.javascript_event_target(lazy_target, none)!
	runtime.define_value_host_function('__mediaErrorRawLazy', fn [lazy_wrapper] (_ voidptr, _ []voidptr) !voidptr { return lazy_wrapper })!
	runtime.evaluate_host(r'globalThis.lazyVideo=__mediaErrorRawLazy();globalThis.createdVideo={};__ladybirdMediaElementBind(createdVideo,"__created_mediaErrorRawVideo","video");globalThis.createdAudio={};__ladybirdMediaElementBind(createdAudio,"__created_mediaErrorRawAudio","audio");0')!
	for wrapper_name in ['video', 'audio', 'createdVideo', 'createdAudio', 'lazyVideo'] {
		wrapper := runtime.evaluate_host_value(wrapper_name)!
		target := runtime.native_event_target(wrapper)!
		mut element := unsafe { &dom.Element(target) }
		if wrapper_name.starts_with('created') { element.set_attribute_value('onerror', media_error_raw_body) }
		slot := target.data.event_handler('error') or { panic('raw error slot') }
		listener := slot.listener or { panic('raw error listener') }
		callback := target.get_current_value_of_event_handler('error') or { panic('raw error callback') }
		assert callback.compiled_source_text_ == 'function onerror(event) {\n${media_error_raw_body}\n}'
		assert voidptr(target.get_current_value_of_event_handler('error') or { panic('cached error callback') }) == voidptr(callback)
		assert voidptr(slot.listener or { panic('retained error listener') }) == voidptr(listener)
		assert runtime.javascript_event_handler(target, 'error')! == runtime.evaluate_host_value('${wrapper_name}.onerror')!
		assert runtime.evaluate_host('${wrapper_name}.onerror.name==="onerror"&&${wrapper_name}.onerror.length===1&&Object.hasOwn(${wrapper_name}.onerror,"prototype")&&Object.getPrototypeOf(${wrapper_name})===(${wrapper_name} instanceof HTMLVideoElement?HTMLVideoElement.prototype:HTMLAudioElement.prototype)')! == 'true'
		assert runtime.evaluate_host('(()=>{const p=HTMLMediaElement.prototype;return ["networkState","readyState","paused","ended"].every(name=>{const d=Object.getOwnPropertyDescriptor(p,name);return !Object.hasOwn(${wrapper_name},name)&&d.set===undefined&&d.enumerable&&d.configurable&&d.get.length===0&&d.get.name==="get "+name&&Function.prototype.toString.call(d.get).includes("[native code]")})})()')! == 'true'
		assert runtime.evaluate_host('mediaErrorRawExpected=${wrapper_name};mediaErrorRawTrusted=false;(()=>{for(const cancelable of [true,false]){mediaErrorRawExpectedEvent=new Event("error",{cancelable});if(${wrapper_name}.dispatchEvent(mediaErrorRawExpectedEvent)!==false||!mediaErrorRawExpectedEvent.defaultPrevented||mediaErrorRawExpectedEvent.currentTarget!==null)return false}return true})()')! == 'true'
		event := media_error_raw_event('error')
		event_wrapper := runtime.javascript_event(event)!
		export_name := '__mediaErrorRawNative_${wrapper_name}'
		runtime.define_value_host_function(export_name, fn [event_wrapper] (_ voidptr, _ []voidptr) !voidptr { return event_wrapper })!
		runtime.evaluate_host('mediaErrorRawExpectedEvent=${export_name}();mediaErrorRawTrusted=true;0')!
		assert !target.dispatch_event(event)
		assert event.is_trusted() && event.default_prevented() && event.current_target() == none
		media_error_raw_assert_contexts(fixture)
	}
	assert runtime.evaluate_host('mediaErrorRawRuns===15&&mediaErrorRawChecks.length===15&&mediaErrorRawChecks.every(Boolean)&&window.event===undefined')! == 'true'
	// Genuine ErrorEvent objects also take the ordinary one-Event path on media.
	error_event := dom.ErrorEvent.create('error', dom.ErrorEventInit{
		EventInit: dom.EventInit{ cancelable: true }
		message: 'decoder failure'
		filename: 'media.js'
		lineno: 7
		colno: 9
	})
	error_wrapper := runtime.javascript_event(unsafe { &dom.Event(error_event) })!
	runtime.define_value_host_function('__mediaErrorRawErrorEvent', fn [error_wrapper] (_ voidptr, _ []voidptr) !voidptr { return error_wrapper })!
	assert runtime.evaluate_host('mediaErrorRawExpected=audio;mediaErrorRawExpectedEvent=__mediaErrorRawErrorEvent();mediaErrorRawTrusted=false;audio.dispatchEvent(mediaErrorRawExpectedEvent)===false&&mediaErrorRawRuns===16&&mediaErrorRawChecks.every(Boolean)')! == 'true'
	assert error_event.default_prevented()
	mut video_element := fixture.document.get_element_by_id('video')?
	video_target := unsafe { &dom.EventTarget(video_element) }
	// A media false return cancels; true does not acquire Window.onerror's rule.
	video_element.set_attribute_value('onerror', 'return true;')
	true_event := dom.Event.create('error', dom.EventInit{ cancelable: true })
	assert video_target.dispatch_event(true_event) && !true_event.default_prevented()
	// Element -> Document -> global scopes; a media element has no form owner.
	runtime.evaluate_host(r'Object.defineProperty(mediaErrorRawForm,"scopeKey",{get(){throw "wrong form scope"}});video.scopeKey="element";video.event={sentinel:true};0')!
	video_element.set_attribute_value('onerror', 'mediaErrorRawChecks.push(scopeKey==="element");delete this.scopeKey;mediaErrorRawChecks.push(scopeKey==="document");delete document.scopeKey;mediaErrorRawChecks.push(scopeKey==="global");this.onerror=null;mediaErrorRawChecks.push(onerror===null&&arguments.length===1&&event===arguments[0]&&new.target===undefined&&typeof __scopes==="undefined"&&typeof __body==="undefined");return false;')
	assert !video_target.dispatch_event(media_error_raw_event('error'))
	assert runtime.evaluate_host('mediaErrorRawChecks.length===20&&mediaErrorRawChecks.every(Boolean)&&video.onerror===null&&window.event===undefined')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 0
	media_error_raw_assert_contexts(fixture)
}

fn test_raw_media_error_replacements_csp_function_body_and_unavailable_owners_preserve_slots() {
	$if !darwin { return }
	fixture := media_error_raw_fixture('error', true, true)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut audio_element := fixture.document.get_element_by_id('audio')?
	target := unsafe { &dom.EventTarget(audio_element) }
	first := target.get_current_value_of_event_handler('error') or { panic('first raw callback') }
	slot := target.data.event_handler('error') or { panic('first raw slot') }
	listener := slot.listener or { panic('first raw listener') }
	raw_body := 'mediaErrorRawRuns+=10;return false;'
	audio_element.set_attribute_value('onerror', raw_body)
	second := target.get_current_value_of_event_handler('error') or { panic('replacement raw callback') }
	assert voidptr(first) != voidptr(second)
	assert voidptr(slot.listener or { panic('replacement retained listener') }) == voidptr(listener)
	assert !target.dispatch_event(media_error_raw_event('error'))
	runtime.evaluate_host('globalThis.mediaErrorRawAssigned=function(event){mediaErrorRawRuns+=100;return false;};audio.onerror=mediaErrorRawAssigned;0')!
	assert runtime.evaluate_host('audio.onerror===mediaErrorRawAssigned')! == 'true'
	assert audio_element.get_attribute_value('onerror') == raw_body
	assert !target.dispatch_event(media_error_raw_event('error'))
	audio_element.set_attribute_value('onerror', raw_body)
	third := target.get_current_value_of_event_handler('error') or { panic('raw write after IDL') }
	assert voidptr(third) != voidptr(second)
	assert !target.dispatch_event(media_error_raw_event('error'))
	audio_element.remove_attribute('onerror')
	assert !target.data.has_event_handler('error')
	assert target.get_current_value_of_event_handler('error') == none
	assert target.dispatch_event(media_error_raw_event('error'))
	assert runtime.evaluate_host('mediaErrorRawRuns===120&&audio.onerror===null')! == 'true'
	// Blocked writes leave an already installed callback intact.
	audio_element.set_attribute_value('onerror', 'return false;')
	csp_callback := target.get_current_value_of_event_handler('error') or { panic('CSP raw callback') }
	mut document := fixture.document
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, type_ string, _ string) bool { return type_ == 'script-attribute' }
	})
	audio_element.set_attribute_value('onerror', 'return (')
	assert audio_element.get_attribute_value('onerror') == 'return ('
	assert voidptr(target.get_current_value_of_event_handler('error') or { panic('CSP preserved callback') }) == voidptr(csp_callback)
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, _ string, _ string) bool { return false }
	})
	mut invalid_element := media_error_raw_element_by_marker(fixture, 'invalid')
	invalid_target := unsafe { &dom.EventTarget(invalid_element) }
	resolver_calls := fixture.resolver_probe.calls
	for body in ['return (', '"use strict";let event;', '}},globalThis.mediaErrorRawRuns++,{onerror:function(event){'] {
		invalid_element.set_attribute_value('onerror', body)
		invalid_slot := invalid_target.data.event_handler('error') or { panic('invalid raw slot') }
		invalid_listener := invalid_slot.listener or { panic('invalid raw listener') }
		assert invalid_target.get_current_value_of_event_handler('error') == none
		assert invalid_target.get_current_value_of_event_handler('error') == none
		assert invalid_slot.value.kind == .null_
		assert voidptr(invalid_slot.listener or { panic('invalid listener retained') }) == voidptr(invalid_listener)
		assert invalid_element.get_attribute_value('onerror') == body
		assert fixture.resolver_probe.calls == resolver_calls
		assert unsafe { &dom.HTMLAudioElement(invalid_element) }.media_element_model_ == unsafe { nil }
	}
	invalid_element.set_attribute_value('onerror', 'return false;')
	available_slot := invalid_target.data.event_handler('error') or { panic('unavailable raw slot') }
	available_listener := available_slot.listener or { panic('unavailable raw listener') }
	mut wheel_host := fixture.wheel_host
	resolver := wheel_host.resolver
	wheel_host.resolver = unsafe { nil }
	assert invalid_target.get_current_value_of_event_handler('error') == none
	wheel_host.resolver = resolver
	for result in ['null', 'throw'] {
		runtime.evaluate_host('mediaErrorRawResolverResult=${json2.encode(result)};0')!
		assert invalid_target.get_current_value_of_event_handler('error') == none
		assert available_slot.value.kind == .string
		assert voidptr(available_slot.listener or { panic('unavailable listener retained') }) == voidptr(available_listener)
		assert unsafe { &dom.HTMLAudioElement(invalid_element) }.media_element_model_ == unsafe { nil }
		media_error_raw_assert_contexts(fixture)
	}
	runtime.evaluate_host('mediaErrorRawResolverResult="normal";0')!
	assert invalid_target.get_current_value_of_event_handler('error') != none
	assert voidptr(available_slot.listener or { panic('resolved listener retained') }) == voidptr(available_listener)
	assert fixture.resolver_probe.owner_contexts
	generic_element := media_error_raw_element_by_marker(fixture, 'generic')
	generic_target := unsafe { &dom.EventTarget(generic_element) }
	runtime.bind_event_target(runtime.evaluate_host_value('Object.create(EventTarget.prototype)')!, generic_target)!
	assert generic_target.get_current_value_of_event_handler('error') == none
	assert (generic_target.data.event_handler('error') or { panic('generic raw') }).value.kind == .string
	ordinary_target := unsafe { &dom.EventTarget(fixture.document.get_element_by_id('ordinary')?) }
	assert ordinary_target.get_current_value_of_event_handler('error') == none
	assert (ordinary_target.data.event_handler('error') or { panic('ordinary raw error unsupported') }).value.kind == .string
	audio_element.set_attribute_value('onstalled', 'globalThis.mediaErrorRawRuns++;')
	assert target.get_current_value_of_event_handler('stalled') == none
	assert (target.data.event_handler('stalled') or { panic('unsupported media raw name') }).value.kind == .string
	// Missing document and media owners are recoverable, retaining raw source.
	no_document := media_error_raw_fixture('error', true, false)!
	mut document_runtime := no_document.runtime
	defer { document_runtime.close() }
	document_target := unsafe { &dom.EventTarget(no_document.document.get_element_by_id('video')?) }
	assert document_target.get_current_value_of_event_handler('error') == none
	assert (document_target.data.event_handler('error') or { panic('missing Document raw') }).value.kind == .string
	document_runtime.install_document_window_event_binding(no_document.document, document_runtime.evaluate_host_value('document')!)!
	assert document_target.get_current_value_of_event_handler('error') != none
	no_media := media_error_raw_fixture('error', false, true)!
	mut media_runtime := no_media.runtime
	defer { media_runtime.close() }
	media_target := unsafe { &dom.EventTarget(no_media.document.get_element_by_id('audio')?) }
	assert media_target.get_current_value_of_event_handler('error') == none
	assert (media_target.data.event_handler('error') or { panic('missing MediaElementHost raw') }).value.kind == .string
	mut late_host := no_media.media_host
	late_host.install(mut media_runtime)!
	assert media_target.get_current_value_of_event_handler('error') != none
	assert runtime.evaluate_host('mediaErrorRawRuns===120')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 0
	media_error_raw_assert_contexts(fixture)
	media_error_raw_assert_contexts(no_document)
	media_error_raw_assert_contexts(no_media)
}

fn test_raw_media_error_strict_throw_and_scripting_gates_balance_native_owner_contexts() {
	$if !darwin { return }
	fixture := media_error_raw_fixture('error', true, true)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut owner := fixture.owner
	mut audio_element := fixture.document.get_element_by_id('audio')?
	target := unsafe { &dom.EventTarget(audio_element) }
	runtime.evaluate_host(r'globalThis.mediaErrorRawThrown={owner:true};globalThis.mediaErrorRawStrict=false;globalThis.mediaErrorRawLater=0;0')!
	owner.set_is_scripting_enabled(false)
	audio_element.set_attribute_value('onerror', r'"use strict";mediaErrorRawRuns++;mediaErrorRawStrict=this===audio&&arguments.length===1&&event===arguments[0]&&networkState===0&&readyState===0&&paused===true&&currentTime===mediaErrorRawCurrentTimeGetter.call(this);throw mediaErrorRawThrown;')
	assert target.get_current_value_of_event_handler('error') == none
	assert (target.data.event_handler('error') or { panic('disabled raw error') }).value.kind == .string
	assert target.dispatch_event(media_error_raw_event('error'))
	assert runtime.evaluate_host('mediaErrorRawRuns===0&&mediaErrorRawLater===0')! == 'true'
	owner.set_is_scripting_enabled(true)
	callback := target.get_current_value_of_event_handler('error') or { panic('strict raw error callback') }
	actual := runtime.javascript_event_handler(target, 'error')!
	runtime.evaluate_host(r'EventTarget.prototype.addEventListener.call(audio,"error",function(event){mediaErrorRawLater++;mediaErrorRawChecks.push(this===audio&&event.target===audio&&event.currentTarget===audio&&arguments.length===1)});0')!
	owner.set_is_scripting_enabled(false)
	assert target.dispatch_event(media_error_raw_event('error'))
	assert runtime.evaluate_host('mediaErrorRawRuns===0&&mediaErrorRawLater===0')! == 'true'
	owner.set_is_scripting_enabled(true)
	assert target.dispatch_event(media_error_raw_event('error'))
	assert runtime.evaluate_host('mediaErrorRawRuns===1&&mediaErrorRawStrict&&mediaErrorRawLater===1&&mediaErrorRawChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 1
	reported := fixture.settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mediaErrorRawThrown')!
	assert voidptr(target.get_current_value_of_event_handler('error') or { panic('strict callback cache') }) == voidptr(callback)
	assert runtime.javascript_event_handler(target, 'error')! == actual
	media_error_raw_assert_contexts(fixture)
	audio_element.set_attribute_value('onerror', 'return false;')
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	assert fixture.media_host.closed && fixture.media_host.records.len == 0
	assert fixture.wheel_host.closed && fixture.wheel_host.records.len == 0
	assert target.get_current_value_of_event_handler('error') == none
	assert (target.data.event_handler('error') or { panic('closed raw error') }).value.kind == .string
	assert target.dispatch_event(media_error_raw_event('error'))
	media_error_raw_assert_contexts(fixture)
}

