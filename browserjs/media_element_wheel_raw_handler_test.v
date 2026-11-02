module browserjs

import dom
import html
import json2
import page

@[heap]
struct MediaRawWheelFixture {
	runtime        &Runtime
	wheel_host     &ElementWheelHost
	media_host     &MediaElementHost
	owner          &page.Page
	document       &dom.Document
	settings       &html.EnvironmentSettingsObject
	resolver_probe &MediaRawWheelResolverProbe
}

@[heap]
struct MediaRawWheelResolverProbe {
mut:
	calls                  int
	without_html_execution int
	owner_contexts         bool = true
}

const media_raw_wheel_body = r'mediaRawRuns++;mediaRawChecks.push(paused===true&&volume===0.5&&this===mediaRawExpected&&arguments.length===1&&event===arguments[0]&&event===mediaRawExpectedEvent&&event instanceof WheelEvent&&event.target===this&&event.currentTarget===this&&event.isTrusted===mediaRawTrusted&&window.event===event&&__mediaRawWheelContext());return false;'

fn media_raw_wheel_fixture(install_media bool, install_document bool) !&MediaRawWheelFixture {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-media-raw-wheel.example.test/' }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<form id="mediaRawForm"><video id="video" onwheel="${media_raw_wheel_body}"></video><audio id="audio" onwheel="${media_raw_wheel_body}"></audio><video data-raw-wheel="lazy" onwheel="${media_raw_wheel_body}"></video><audio data-raw-wheel="invalid" onwheel="return ("></audio><audio data-raw-wheel="generic" onwheel="return false;"></audio><audio data-raw-wheel="stale-assignment" onwheel="return false;"></audio><audio data-raw-wheel="stale-removal" onwheel="return false;"></audio><audio data-raw-wheel="stale-raw" onwheel="return false;"></audio></form>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut wheel_host := ElementWheelHost.create(document)!
	wheel_host.install(mut runtime)!
	mut media_host := MediaElementHost.create(document, none)!
	if install_media { media_host.install(mut runtime)! }
	runtime.evaluate_host('globalThis.window=globalThis;0')!
	runtime.install_window_event_handler_binding()!
	runtime.install_window_current_event_binding()!
	mut resolver_probe := &MediaRawWheelResolverProbe{}
	handle := voidptr(runtime)
	probe_handle := voidptr(resolver_probe)
	runtime.define_value_host_function('__mediaRawWheelResolverContext', fn [handle, probe_handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		mut probe := unsafe { &MediaRawWheelResolverProbe(probe_handle) }
		probe.calls++
		probe.owner_contexts = probe.owner_contexts && runtime.libjs_vm().has_running_execution_context()
			&& voidptr(runtime.libjs_vm().running_execution_context()) == voidptr(runtime.realm_context)
		if settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0 {
			probe.without_html_execution++
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	runtime.evaluate_host(r'
globalThis.mediaRawWheelSpecs=Object.create(null);globalThis.mediaRawWheelFacades=Object.create(null);
globalThis.mediaRawResolverBefore=null;globalThis.mediaRawResolverResult="normal";
globalThis.mediaRawWheelResolve=function(key){
 if(mediaRawWheelFacades[key])return mediaRawWheelFacades[key];
 const spec=mediaRawWheelSpecs[key];if(!spec)return null;
 const wrapper={addEventListener(){},removeEventListener(){}};
 if(spec.tag==="audio"||spec.tag==="video"){
  if(typeof __ladybirdMediaElementBind!=="function")return null;
  __mediaRawWheelResolverContext();
  if(typeof mediaRawResolverBefore==="function")mediaRawResolverBefore(key);
  if(mediaRawResolverResult==="null")return null;
  if(mediaRawResolverResult==="throw")throw "resolver owner unavailable";
  __ladybirdMediaElementBind(wrapper,key,spec.tag);
 }else __ladybirdElementWheelBind(wrapper,key,spec.tag,spec.namespace);
 mediaRawWheelFacades[key]=wrapper;return wrapper;
};
__ladybirdElementWheelSetResolver(mediaRawWheelResolve);0')!
	for key, element in wheel_host.elements_for_binding() {
		spec := json2.encode({
			'tag':       element.local_name()
			'namespace': element.namespace_uri() or { '' }
		})
		runtime.evaluate_host('mediaRawWheelSpecs[${json2.encode(key)}]=${spec};0')!
		id := element.get_attribute_value('id')
		if id != '' {
			runtime.evaluate_host('globalThis[${json2.encode(id)}]=mediaRawWheelResolve(${json2.encode(key)});0')!
		}
	}
	resolver_probe.calls = 0
	resolver_probe.without_html_execution = 0
	resolver_probe.owner_contexts = true
	runtime.define_value_host_function('__mediaRawWheelContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	runtime.evaluate_host('globalThis.document={scopeKey:"document"};globalThis.scopeKey="global";globalThis.mediaRawRuns=0;globalThis.mediaRawChecks=[];0')!
	if install_document {
		runtime.install_document_window_event_binding(document,
			runtime.evaluate_host_value('document')!)!
	}
	return &MediaRawWheelFixture{ runtime: runtime, wheel_host: wheel_host, media_host: media_host,
		owner: owner, document: document, settings: settings, resolver_probe: resolver_probe }
}

fn media_raw_wheel_element_by_marker(fixture &MediaRawWheelFixture, marker string) &dom.Element {
	for _, element in fixture.wheel_host.elements_for_binding() {
		if element.get_attribute_value('data-raw-wheel') == marker { return element }
	}
	panic('missing marked raw media ${marker}')
}

fn media_raw_wheel_event(fixture &MediaRawWheelFixture) &dom.Event {
	wheel := dom.WheelEvent.create_from_platform_event(voidptr(fixture.document.get_window() or {
		panic('missing raw media wheel owner Window')
	}), 'wheel', dom.CSSPixelPoint_{ x_: 30.5, y_: -40.75 },
		dom.CSSPixelPoint_{ x_: 13.75, y_: 24.625 }, dom.CSSPixelPoint_{ x_: 3.75, y_: 4.625 },
		dom.CSSPixelPoint_{ x_: 1.25, y_: 2.5 }, 2.5, -3.5, 2, 5,
		dom.modifier_ctrl | dom.modifier_alt)
	return unsafe { &dom.Event(wheel) }
}

fn media_raw_wheel_assert_contexts(fixture &MediaRawWheelFixture) {
	assert fixture.settings.realm().script_execution_depth == 0
	assert fixture.settings.realm().callback_execution_depth == 0
	assert !fixture.runtime.libjs_vm().has_running_execution_context()
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_raw_media_wheel_parsed_and_created_callbacks_cache_native_media_scopes_and_cancel() {
	$if !darwin { return }
	fixture := media_raw_wheel_fixture(true, true)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	lazy_element := media_raw_wheel_element_by_marker(fixture, 'lazy')
	lazy_target := unsafe { &dom.EventTarget(lazy_element) }
	assert unsafe { &dom.HTMLVideoElement(lazy_element) }.media_element_model_ == unsafe { nil }
	lazy_checkpoint := fixture.settings.realm().microtask_checkpoint_count
	assert lazy_target.get_current_value_of_event_handler('wheel') != none
	assert fixture.settings.realm().microtask_checkpoint_count == lazy_checkpoint
	assert fixture.resolver_probe.calls == 1 && fixture.resolver_probe.owner_contexts
	assert fixture.resolver_probe.without_html_execution == 1
	assert unsafe { &dom.HTMLVideoElement(lazy_element) }.media_element_model_ != unsafe { nil }
	lazy_wrapper := runtime.javascript_event_target(lazy_target, none)!
	runtime.define_value_host_function('__mediaRawLazyVideo', fn [lazy_wrapper] (_ voidptr, _ []voidptr) !voidptr { return lazy_wrapper })!
	runtime.evaluate_host('globalThis.lazyVideo=__mediaRawLazyVideo();0')!
	runtime.evaluate_host(r'globalThis.createdVideo={};__ladybirdMediaElementBind(createdVideo,"__created_mediaRawVideo","video");globalThis.createdAudio={};__ladybirdMediaElementBind(createdAudio,"__created_mediaRawAudio","audio");0')!
	for name in ['video', 'audio', 'createdVideo', 'createdAudio', 'lazyVideo'] {
		wrapper := runtime.evaluate_host_value(name)!
		target := runtime.native_event_target(wrapper)!
		mut element := unsafe { &dom.Element(target) }
		if name.starts_with('created') { element.set_attribute_value('onwheel', media_raw_wheel_body) }
		slot := target.data.event_handler('wheel') or { panic('media raw slot') }
		listener := slot.listener or { panic('media raw listener') }
		if name == 'lazyVideo' { assert slot.value.kind == .object } else { assert slot.value.kind == .string }
		checkpoint := fixture.settings.realm().microtask_checkpoint_count
		callback := target.get_current_value_of_event_handler('wheel') or { panic('media raw callback') }
		assert callback.compiled_source_text_ == 'function onwheel(event) {\n${media_raw_wheel_body}\n}'
		assert fixture.settings.realm().microtask_checkpoint_count == checkpoint
		assert voidptr(target.get_current_value_of_event_handler('wheel') or { panic('media callback cache') }) == voidptr(callback)
		assert voidptr(slot.listener or { panic('media listener retained') }) == voidptr(listener)
		assert runtime.javascript_event_handler(target, 'wheel')! == runtime.evaluate_host_value('${name}.onwheel')!
		assert runtime.evaluate_host('${name}.onwheel.name==="onwheel"&&${name}.onwheel.length===1&&Object.hasOwn(${name}.onwheel,"prototype")&&!Object.hasOwn(${name},"paused")&&!Object.hasOwn(${name},"volume")&&Object.getPrototypeOf(${name})===(${name} instanceof HTMLVideoElement?HTMLVideoElement.prototype:HTMLAudioElement.prototype)')! == 'true'
		assert runtime.evaluate_host('mediaRawExpected=${name};mediaRawTrusted=false;${name}.volume=0.5;(()=>{for(const cancelable of [true,false]){mediaRawExpectedEvent=new WheelEvent("wheel",{cancelable,deltaY:3.5});if(${name}.dispatchEvent(mediaRawExpectedEvent)!==false||!mediaRawExpectedEvent.defaultPrevented||mediaRawExpectedEvent.currentTarget!==null)return false}return true})()')! == 'true'
		event := media_raw_wheel_event(fixture)
		native_wrapper := runtime.javascript_event(event)!
		export_name := '__mediaRawNative_${name}'
		runtime.define_value_host_function(export_name, fn [native_wrapper] (_ voidptr, _ []voidptr) !voidptr { return native_wrapper })!
		runtime.evaluate_host('mediaRawExpectedEvent=${export_name}();mediaRawTrusted=true;0')!
		assert !target.dispatch_event(event)
		assert event.is_trusted() && event.default_prevented() && event.current_target() == none
		assert element.get_attribute_value('onwheel') == media_raw_wheel_body
		media_raw_wheel_assert_contexts(fixture)
	}
	assert runtime.evaluate_host('mediaRawRuns===15&&mediaRawChecks.length===15&&mediaRawChecks.every(Boolean)&&window.event===undefined')! == 'true'
	// Media is not form-associated: even a real ancestor form is not a scope.
	runtime.evaluate_host(r'Object.defineProperty(mediaRawForm,"scopeKey",{get(){throw "wrong form scope"}});video.scopeKey="element";video.event={sentinel:true};0')!
	mut video_element := fixture.document.get_element_by_id('video')?
	scope_body := r'mediaRawChecks.push(scopeKey==="element");delete this.scopeKey;mediaRawChecks.push(scopeKey==="document");delete document.scopeKey;mediaRawChecks.push(scopeKey==="global");this.onwheel=null;mediaRawChecks.push(onwheel===null&&arguments.length===1&&event===arguments[0]&&new.target===undefined&&typeof __scopes==="undefined"&&typeof __body==="undefined");return false;'
	video_element.set_attribute_value('onwheel', scope_body)
	video_target := unsafe { &dom.EventTarget(video_element) }
	assert !video_target.dispatch_event(media_raw_wheel_event(fixture))
	assert runtime.evaluate_host('mediaRawChecks.length===19&&mediaRawChecks.every(Boolean)&&video.onwheel===null&&window.event===undefined')! == 'true'
	// A later installed host must not erase the older facade's actual model owner.
	old_wrapper := runtime.evaluate_host_value('video')!
	mut later_host := MediaElementHost.create(fixture.document, none)!
	later_host.install(mut runtime)!
	assert runtime.media_element_hosts_.len == 2
	assert old_wrapper in fixture.media_host.records && old_wrapper !in later_host.records
	video_element.set_attribute_value('onwheel', 'return false;')
	assert video_target.get_current_value_of_event_handler('wheel') != none
	assert !video_target.dispatch_event(media_raw_wheel_event(fixture))
	assert fixture.settings.realm().reported_exceptions.len == 0
	media_raw_wheel_assert_contexts(fixture)
}

fn test_raw_media_wheel_function_body_csp_name_filter_and_unavailable_owners_preserve_slots() {
	$if !darwin { return }
	fixture := media_raw_wheel_fixture(true, true)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut audio_element := fixture.document.get_element_by_id('audio')?
	target := unsafe { &dom.EventTarget(audio_element) }
	mut unbound_element := media_raw_wheel_element_by_marker(fixture, 'invalid')
	unbound_target := unsafe { &dom.EventTarget(unbound_element) }
	resolver_calls := fixture.resolver_probe.calls
	for body in ['return (', '"use strict";let event;',
		'}},globalThis.mediaRawRuns++,{onwheel:function(event){'] {
		unbound_element.set_attribute_value('onwheel', body)
		slot := unbound_target.data.event_handler('wheel') or { panic('invalid media raw slot') }
		listener := slot.listener or { panic('invalid media raw listener') }
		assert unbound_target.get_current_value_of_event_handler('wheel') == none
		assert unbound_target.get_current_value_of_event_handler('wheel') == none
		assert runtime.evaluate_host('mediaRawRuns===0')! == 'true'
		assert slot.value.kind == .null_
		assert voidptr(slot.listener or { panic('invalid media listener retained') }) == voidptr(listener)
		assert unbound_element.get_attribute_value('onwheel') == body
		assert fixture.resolver_probe.calls == resolver_calls
		assert unsafe { &dom.HTMLAudioElement(unbound_element) }.media_element_model_ == unsafe { nil }
		assert voidptr(unbound_target) !in runtime.event_binding()!.target_wrappers
	}
	generic_element := media_raw_wheel_element_by_marker(fixture, 'generic')
	generic_target := unsafe { &dom.EventTarget(generic_element) }
	generic_wrapper := runtime.evaluate_host_value('Object.create(EventTarget.prototype)')!
	runtime.bind_event_target(generic_wrapper, generic_target)!
	assert generic_target.get_current_value_of_event_handler('wheel') == none
	assert (generic_target.data.event_handler('wheel') or { panic('generic wrapper raw') }).value.kind == .string
	assert fixture.resolver_probe.calls == resolver_calls
	assert unsafe { &dom.HTMLAudioElement(generic_element) }.media_element_model_ == unsafe { nil }
	// Missing, null and throwing resolvers are owner boundaries, retaining raw/listener.
	unbound_element.set_attribute_value('onwheel', 'return false;')
	availability_slot := unbound_target.data.event_handler('wheel') or { panic('unavailable resolver slot') }
	availability_listener := availability_slot.listener or { panic('unavailable resolver listener') }
	mut wheel_host := fixture.wheel_host
	resolver := wheel_host.resolver
	wheel_host.resolver = unsafe { nil }
	assert unbound_target.get_current_value_of_event_handler('wheel') == none
	wheel_host.resolver = resolver
	assert availability_slot.value.kind == .string
	assert fixture.resolver_probe.calls == resolver_calls
	for result in ['null', 'throw'] {
		runtime.evaluate_host('mediaRawResolverResult=${json2.encode(result)};0')!
		assert unbound_target.get_current_value_of_event_handler('wheel') == none
		assert availability_slot.value.kind == .string
		assert voidptr(availability_slot.listener or { panic('unavailable resolver listener retained') }) == voidptr(availability_listener)
		assert unsafe { &dom.HTMLAudioElement(unbound_element) }.media_element_model_ == unsafe { nil }
		assert voidptr(unbound_target) !in runtime.event_binding()!.target_wrappers
		media_raw_wheel_assert_contexts(fixture)
	}
	runtime.evaluate_host('mediaRawResolverResult="normal";0')!
	assert unbound_target.get_current_value_of_event_handler('wheel') != none
	assert voidptr(availability_slot.listener or { panic('resolved listener retained') }) == voidptr(availability_listener)
	assert fixture.resolver_probe.owner_contexts
	// Resolver reentrancy cannot overwrite a later IDL assignment, removal or raw body.
	runtime.evaluate_host('globalThis.mediaRawAssigned=function(event){mediaRawRuns+=100;return false;};0')!
	assigned := runtime.event_callback(runtime.evaluate_host_value('mediaRawAssigned')!, true)!
	for mode, marker in ['stale-assignment', 'stale-removal', 'stale-raw'] {
		stale_element := media_raw_wheel_element_by_marker(fixture, marker)
		stale_target := unsafe { &dom.EventTarget(stale_element) }
		stale_slot := stale_target.data.event_handler('wheel') or { panic('stale source slot') }
		stale_listener := stale_slot.listener or { panic('stale source listener') }
		function_name := '__mediaRawMutation_${mode}'
		target_handle := voidptr(stale_element)
		callback_handle := voidptr(assigned)
		runtime_handle := voidptr(runtime)
		runtime.define_value_host_function(function_name, fn [target_handle, callback_handle, runtime_handle, mode] (_ voidptr, _ []voidptr) !voidptr {
			mut element := unsafe { &dom.Element(target_handle) }
			target := unsafe { &dom.EventTarget(target_handle) }
			match mode {
				0 { target.set_event_handler_attribute('wheel', unsafe { &dom.CallbackType(callback_handle) }) }
				1 { element.remove_attribute('onwheel') }
				else { element.set_attribute_value('onwheel', 'mediaRawRuns+=10;return false;') }
			}
			runtime := unsafe { &Runtime(runtime_handle) }
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		})!
		runtime.evaluate_host('mediaRawResolverBefore=function(){${function_name}()};0')!
		assert stale_target.get_current_value_of_event_handler('wheel') == none
		match mode {
			0 {
				assert voidptr(stale_target.get_current_value_of_event_handler('wheel') or { panic('resolver assigned callback') }) == voidptr(assigned)
				assert voidptr(stale_slot.listener or { panic('resolver assigned listener') }) == voidptr(stale_listener)
			}
			1 {
				assert !stale_target.data.has_event_handler('wheel')
				assert stale_slot.listener == none && stale_slot.value.kind == .null_
			}
			else {
				assert stale_slot.value.kind == .string
				assert stale_slot.value.string_data == 'mediaRawRuns+=10;return false;'
				assert voidptr(stale_slot.listener or { panic('resolver changed raw listener') }) == voidptr(stale_listener)
			}
		}
		assert unsafe { &dom.HTMLAudioElement(stale_element) }.media_element_model_ != unsafe { nil }
		media_raw_wheel_assert_contexts(fixture)
	}
	runtime.evaluate_host('mediaRawResolverBefore=null;0')!
	assert runtime.evaluate_host('mediaRawRuns===0')! == 'true'
	audio_element.set_attribute_value('onstalled', 'globalThis.mediaRawRuns++;')
	assert target.get_current_value_of_event_handler('stalled') == none
	assert (target.data.event_handler('stalled') or { panic('unsupported media raw name') }).value.kind == .string
	audio_element.set_attribute_value('onwheel', 'return false;')
	callback := target.get_current_value_of_event_handler('wheel') or { panic('valid media raw callback') }
	mut document := fixture.document
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, type_ string, _ string) bool { return type_ == 'script-attribute' }
	})
	audio_element.set_attribute_value('onwheel', 'return (')
	assert voidptr(target.get_current_value_of_event_handler('wheel') or { panic('CSP preserved media callback') }) == voidptr(callback)
	assert audio_element.get_attribute_value('onwheel') == 'return ('
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, _ string, _ string) bool { return false }
	})
	// A native target record alone is insufficient without its matching media model.
	mut media_host := fixture.media_host
	video_wrapper := runtime.evaluate_host_value('video')!
	video_model := media_host.media_element_for_binding(video_wrapper)!
	audio_model := media_host.media_element_for_binding(runtime.evaluate_host_value('audio')!)!
	mut video_element := fixture.document.get_element_by_id('video')?
	video_target := unsafe { &dom.EventTarget(video_element) }
	video_element.set_attribute_value('onwheel', 'return false;')
	media_host.records[video_wrapper] = audio_model
	assert video_target.get_current_value_of_event_handler('wheel') == none
	assert (video_target.data.event_handler('wheel') or { panic('mismatched model raw') }).value.kind == .string
	media_host.records.delete(video_wrapper)
	assert video_target.get_current_value_of_event_handler('wheel') == none
	assert (video_target.data.event_handler('wheel') or { panic('missing model raw') }).value.kind == .string
	media_host.records[video_wrapper] = video_model
	assert video_target.get_current_value_of_event_handler('wheel') != none
	no_document := media_raw_wheel_fixture(true, false)!
	mut document_runtime := no_document.runtime
	defer { document_runtime.close() }
	missing_document_target := unsafe { &dom.EventTarget(no_document.document.get_element_by_id('video')?) }
	assert missing_document_target.get_current_value_of_event_handler('wheel') == none
	assert (missing_document_target.data.event_handler('wheel') or { panic('missing Document raw') }).value.kind == .string
	document_runtime.install_document_window_event_binding(no_document.document,
		document_runtime.evaluate_host_value('document')!)!
	assert missing_document_target.get_current_value_of_event_handler('wheel') != none
	no_media := media_raw_wheel_fixture(false, true)!
	mut media_runtime := no_media.runtime
	defer { media_runtime.close() }
	missing_media_element := no_media.document.get_element_by_id('audio')?
	_ = html.html_media_element_for_dom_element(missing_media_element) or { panic('cached missing-host media') }
	missing_media_target := unsafe { &dom.EventTarget(missing_media_element) }
	assert missing_media_target.get_current_value_of_event_handler('wheel') == none
	assert (missing_media_target.data.event_handler('wheel') or { panic('missing MediaElementHost raw') }).value.kind == .string
	mut late_host := no_media.media_host
	late_host.install(mut media_runtime)!
	assert missing_media_target.get_current_value_of_event_handler('wheel') != none
	assert fixture.settings.realm().reported_exceptions.len == 0
	media_raw_wheel_assert_contexts(fixture)
	media_raw_wheel_assert_contexts(no_document)
	media_raw_wheel_assert_contexts(no_media)
}

fn test_raw_media_wheel_strict_exceptions_and_page_gate_keep_owner_contexts_balanced_after_close() {
	$if !darwin { return }
	fixture := media_raw_wheel_fixture(true, true)!
	mut runtime := fixture.runtime
	defer { runtime.close() }
	mut owner := fixture.owner
	mut audio_element := fixture.document.get_element_by_id('audio')?
	target := unsafe { &dom.EventTarget(audio_element) }
	runtime.evaluate_host('globalThis.mediaRawThrown={owner:true};globalThis.mediaRawStrict=false;0')!
	owner.set_is_scripting_enabled(false)
	audio_element.set_attribute_value('onwheel', r'"use strict";mediaRawRuns++;mediaRawStrict=this===audio&&arguments.length===1&&event===arguments[0]&&paused===true;throw mediaRawThrown;')
	assert target.get_current_value_of_event_handler('wheel') == none
	assert (target.data.event_handler('wheel') or { panic('disabled media raw') }).value.kind == .string
	assert target.dispatch_event(media_raw_wheel_event(fixture))
	assert runtime.evaluate_host('mediaRawRuns===0')! == 'true'
	owner.set_is_scripting_enabled(true)
	callback := target.get_current_value_of_event_handler('wheel') or { panic('strict media raw callback') }
	actual := runtime.javascript_event_handler(target, 'wheel')!
	owner.set_is_scripting_enabled(false)
	assert target.dispatch_event(media_raw_wheel_event(fixture))
	assert runtime.evaluate_host('mediaRawRuns===0')! == 'true'
	owner.set_is_scripting_enabled(true)
	assert target.dispatch_event(media_raw_wheel_event(fixture))
	assert runtime.evaluate_host('mediaRawRuns===1&&mediaRawStrict&&window.event===undefined')! == 'true'
	assert fixture.settings.realm().reported_exceptions.len == 1
	reported := fixture.settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mediaRawThrown')!
	assert voidptr(target.get_current_value_of_event_handler('wheel') or { panic('strict media callback cache') }) == voidptr(callback)
	assert runtime.javascript_event_handler(target, 'wheel')! == actual
	media_raw_wheel_assert_contexts(fixture)
	audio_element.set_attribute_value('onwheel', 'return false;')
	runtime.close()
	assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
	assert fixture.media_host.closed && fixture.media_host.records.len == 0
	assert fixture.wheel_host.closed && fixture.wheel_host.records.len == 0
	assert target.get_current_value_of_event_handler('wheel') == none
	assert (target.data.event_handler('wheel') or { panic('closed media raw') }).value.kind == .string
	assert target.dispatch_event(media_raw_wheel_event(fixture))
	media_raw_wheel_assert_contexts(fixture)
}
