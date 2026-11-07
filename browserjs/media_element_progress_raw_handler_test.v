module browserjs

import dom
import html
import json2
import page

@[heap]
struct MediaProgressRawFixture {
	runtime        &Runtime
	wheel_host     &ElementWheelHost
	media_host     &MediaElementHost
	owner          &page.Page
	document       &dom.Document
	settings       &html.EnvironmentSettingsObject
	resolver_probe &MediaProgressRawResolverProbe
}

@[heap]
struct MediaProgressRawResolverProbe {
mut:
	calls                  int
	without_html_execution int
	owner_contexts         bool = true
}

const media_progress_raw_body = r'mediaProgressRuns++;mediaProgressChecks.push(networkState===0&&readyState===0&&paused===true&&currentTime===0&&currentTime===mediaProgressCurrentTimeGetter.call(this)&&this===mediaProgressExpected&&arguments.length===1&&event===arguments[0]&&event===mediaProgressExpectedEvent&&event instanceof Event&&event.target===this&&event.currentTarget===this&&event.isTrusted===mediaProgressTrusted&&window.event===event&&__mediaProgressRawContext());return false;'

fn media_progress_raw_fixture(name string, install_media bool, install_document bool) !&MediaProgressRawFixture {
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://native-media-progress-raw.example.test/' }
	mut document := html.create_navigation_document_for_page(url, url.origin(), none,
		unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<form id="mediaProgressForm"><video id="video" on${name}="${media_progress_raw_body}"></video><audio id="audio" on${name}="${media_progress_raw_body}"></audio><video data-raw-progress="lazy" on${name}="${media_progress_raw_body}" onwheel="return (" onplay="return ("></video><audio data-raw-progress="invalid" on${name}="return ("></audio><audio data-raw-progress="generic" on${name}="return false;"></audio><audio data-raw-progress="stale-assignment" on${name}="return false;"></audio><audio data-raw-progress="stale-removal" on${name}="return false;"></audio><audio data-raw-progress="stale-raw" on${name}="return false;"></audio></form><fieldset id="ordinary" on${name}="return false;"></fieldset>')
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	mut wheel_host := ElementWheelHost.create(document)!
	wheel_host.install(mut runtime)!
	mut media_host := MediaElementHost.create(document, none)!
	if install_media { media_host.install(mut runtime)! }
	runtime.evaluate_host('globalThis.window=globalThis;0')!
	runtime.install_window_event_handler_binding()!
	runtime.install_window_current_event_binding()!
	mut resolver_probe := &MediaProgressRawResolverProbe{}
	handle := voidptr(runtime)
	probe_handle := voidptr(resolver_probe)
	runtime.define_value_host_function('__mediaProgressRawResolverContext', fn [handle, probe_handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		mut probe := unsafe { &MediaProgressRawResolverProbe(probe_handle) }
		probe.calls++
		probe.owner_contexts = probe.owner_contexts && runtime.libjs_vm().has_running_execution_context()
			&& voidptr(runtime.libjs_vm().running_execution_context()) == voidptr(runtime.realm_context)
		if settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0 {
			probe.without_html_execution++
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	runtime.evaluate_host(r'
globalThis.mediaProgressRawSpecs=Object.create(null);globalThis.mediaProgressRawFacades=Object.create(null);
globalThis.mediaProgressResolverBefore=null;globalThis.mediaProgressResolverResult="normal";
globalThis.mediaProgressRawResolve=function(key){
 if(mediaProgressRawFacades[key])return mediaProgressRawFacades[key];
 const spec=mediaProgressRawSpecs[key];if(!spec)return null;
 const wrapper={addEventListener(){},removeEventListener(){}};
 if(spec.tag==="audio"||spec.tag==="video"){
  if(typeof __ladybirdMediaElementBind!=="function")return null;
  __mediaProgressRawResolverContext();
  if(typeof mediaProgressResolverBefore==="function")mediaProgressResolverBefore(key);
  if(mediaProgressResolverResult==="null")return null;
  if(mediaProgressResolverResult==="throw")throw "resolver owner unavailable";
  __ladybirdMediaElementBind(wrapper,key,spec.tag);
 }else __ladybirdElementWheelBind(wrapper,key,spec.tag,spec.namespace);
 mediaProgressRawFacades[key]=wrapper;return wrapper;
};
__ladybirdElementWheelSetResolver(mediaProgressRawResolve);0')!
	for key, element in wheel_host.elements_for_binding() {
		spec := json2.encode({
			'tag':       element.local_name()
			'namespace': element.namespace_uri() or { '' }
		})
		runtime.evaluate_host('mediaProgressRawSpecs[${json2.encode(key)}]=${spec};0')!
		id := element.get_attribute_value('id')
		if id != '' {
			runtime.evaluate_host('globalThis[${json2.encode(id)}]=mediaProgressRawResolve(${json2.encode(key)});0')!
		}
	}
	resolver_probe.calls = 0
	resolver_probe.without_html_execution = 0
	resolver_probe.owner_contexts = true
	runtime.define_value_host_function('__mediaProgressRawContext', fn [handle, settings] (_ voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(handle) }
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, settings.realm().script_execution_depth > 0
			&& settings.realm().callback_execution_depth > 0
			&& runtime.libjs_vm().has_running_execution_context()
			&& voidptr(html.current_principal_settings_object()) == voidptr(settings)
			&& voidptr(html.incumbent_settings_object()) == voidptr(settings))
	})!
	runtime.evaluate_host('globalThis.document={scopeKey:"document",networkState:99,readyState:99,currentTime:99,paused:false};globalThis.scopeKey="global";globalThis.networkState=123;globalThis.readyState=123;globalThis.currentTime=123;globalThis.paused=false;globalThis.mediaProgressCurrentTimeGetter=typeof HTMLMediaElement==="function"?Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"currentTime").get:null;globalThis.mediaProgressRuns=0;globalThis.mediaProgressChecks=[];0')!
	if install_document {
		runtime.install_document_window_event_binding(document,
			runtime.evaluate_host_value('document')!)!
	}
	return &MediaProgressRawFixture{ runtime: runtime, wheel_host: wheel_host, media_host: media_host,
		owner: owner, document: document, settings: settings, resolver_probe: resolver_probe }
}

fn media_progress_raw_element_by_marker(fixture &MediaProgressRawFixture, marker string) &dom.Element {
	for _, element in fixture.wheel_host.elements_for_binding() {
		if element.get_attribute_value('data-raw-progress') == marker { return element }
	}
	panic('missing marked raw media ${marker}')
}

fn media_progress_raw_event(name string) &dom.Event {
	// Binding probes use a native Event directly. Browser owner fixtures exercise
	// the actual progress and suspend media tasks separately.
	mut event := dom.Event.create(name, dom.EventInit{})
	event.set_is_trusted(true)
	return event
}

fn media_progress_raw_assert_contexts(fixture &MediaProgressRawFixture) {
	assert fixture.settings.realm().script_execution_depth == 0
	assert fixture.settings.realm().callback_execution_depth == 0
	assert !fixture.runtime.libjs_vm().has_running_execution_context()
	assert fixture.runtime.libjs_vm().execution_context_stack().len == 0
	assert fixture.runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_raw_media_progress_parsed_and_created_callbacks_cache_native_media_scopes_and_cancel() {
	$if !darwin { return }
	for name in ['progress', 'suspend'] {
		fixture := media_progress_raw_fixture(name, true, true)!
		mut runtime := fixture.runtime
		defer { runtime.close() }
		lazy_element := media_progress_raw_element_by_marker(fixture, 'lazy')
		lazy_target := unsafe { &dom.EventTarget(lazy_element) }
		assert unsafe { &dom.HTMLVideoElement(lazy_element) }.media_element_model_ == unsafe { nil }
		lazy_checkpoint := fixture.settings.realm().microtask_checkpoint_count
		assert lazy_target.get_current_value_of_event_handler(name) != none
		wheel_slot := lazy_target.data.event_handler('wheel') or { panic('independent wheel slot') }
		assert wheel_slot.value.kind == .string && wheel_slot.value.string_data == 'return ('
		play_slot := lazy_target.data.event_handler('play') or { panic('independent malformed play slot') }
		assert play_slot.value.kind == .string && play_slot.value.string_data == 'return ('
		assert fixture.settings.realm().microtask_checkpoint_count == lazy_checkpoint
		assert fixture.resolver_probe.calls == 1 && fixture.resolver_probe.owner_contexts
		assert fixture.resolver_probe.without_html_execution == 1
		assert unsafe { &dom.HTMLVideoElement(lazy_element) }.media_element_model_ != unsafe { nil }
		lazy_wrapper := runtime.javascript_event_target(lazy_target, none)!
		mut lazy_dom_element := unsafe { &dom.Element(lazy_element) }
		other_name := if name == 'progress' { 'suspend' } else { 'progress' }
		lazy_dom_element.set_attribute_value('on${other_name}', 'return false;')
		first_callback := lazy_target.get_current_value_of_event_handler(name) or { panic('first progress cache') }
		other_callback := lazy_target.get_current_value_of_event_handler(other_name) or { panic('other progress cache') }
		assert voidptr(first_callback) != voidptr(other_callback)
		assert voidptr(lazy_target.get_current_value_of_event_handler(name) or { panic('first cache preserved') }) == voidptr(first_callback)
		runtime.define_value_host_function('__mediaProgressLazyVideo', fn [lazy_wrapper] (_ voidptr, _ []voidptr) !voidptr { return lazy_wrapper })!
		runtime.evaluate_host('globalThis.lazyVideo=__mediaProgressLazyVideo();0')!
		runtime.evaluate_host(r'globalThis.createdVideo={};__ladybirdMediaElementBind(createdVideo,"__created_mediaProgressVideo","video");globalThis.createdAudio={};__ladybirdMediaElementBind(createdAudio,"__created_mediaProgressAudio","audio");0')!
		for wrapper_name in ['video', 'audio', 'createdVideo', 'createdAudio', 'lazyVideo'] {
			wrapper := runtime.evaluate_host_value(wrapper_name)!
			target := runtime.native_event_target(wrapper)!
			mut element := unsafe { &dom.Element(target) }
			if wrapper_name.starts_with('created') { element.set_attribute_value('on${name}', media_progress_raw_body) }
			slot := target.data.event_handler(name) or { panic('media raw slot') }
			listener := slot.listener or { panic('media raw listener') }
			if wrapper_name == 'lazyVideo' { assert slot.value.kind == .object } else { assert slot.value.kind == .string }
			checkpoint := fixture.settings.realm().microtask_checkpoint_count
			callback := target.get_current_value_of_event_handler(name) or { panic('media raw callback') }
			assert callback.compiled_source_text_ == 'function on${name}(event) {\n${media_progress_raw_body}\n}'
			assert fixture.settings.realm().microtask_checkpoint_count == checkpoint
			assert voidptr(target.get_current_value_of_event_handler(name) or { panic('media callback cache') }) == voidptr(callback)
			assert voidptr(slot.listener or { panic('media listener retained') }) == voidptr(listener)
			assert runtime.javascript_event_handler(target, name)! == runtime.evaluate_host_value('${wrapper_name}.on${name}')!
			assert runtime.evaluate_host('${wrapper_name}.on${name}.name==="on${name}"&&${wrapper_name}.on${name}.length===1&&Object.hasOwn(${wrapper_name}.on${name},"prototype")&&!Object.hasOwn(${wrapper_name},"networkState")&&!Object.hasOwn(${wrapper_name},"paused")&&!Object.hasOwn(${wrapper_name},"readyState")&&!Object.hasOwn(${wrapper_name},"currentTime")&&Object.getPrototypeOf(${wrapper_name})===(${wrapper_name} instanceof HTMLVideoElement?HTMLVideoElement.prototype:HTMLAudioElement.prototype)')! == 'true'
			assert runtime.evaluate_host('(()=>{const p=HTMLMediaElement.prototype,n=Object.getOwnPropertyDescriptor(p,"networkState"),t=Object.getOwnPropertyDescriptor(p,"currentTime"),a=Object.getOwnPropertyDescriptor(p,"paused"),r=Object.getOwnPropertyDescriptor(p,"readyState");return n.set===undefined&&a.set===undefined&&r.set===undefined&&n.get.name==="get networkState"&&a.get.name==="get paused"&&r.get.name==="get readyState"&&t.get===mediaProgressCurrentTimeGetter&&t.get.name==="get currentTime"&&t.get.length===0&&[n.get,t.get,a.get,r.get].every(fn=>Function.prototype.toString.call(fn).includes("[native code]"))&&n.get.call(${wrapper_name})===0&&t.get.call(${wrapper_name})===0&&a.get.call(${wrapper_name})===true&&r.get.call(${wrapper_name})===0})()')! == 'true'
			// These probes read native properties and dispatch Events directly.
			// Browser owner fixtures exercise the media algorithms and task queue.
			assert runtime.evaluate_host('mediaProgressExpected=${wrapper_name};mediaProgressTrusted=false;(()=>{for(const cancelable of [true,false]){mediaProgressExpectedEvent=new Event("${name}",{cancelable});if(${wrapper_name}.dispatchEvent(mediaProgressExpectedEvent)!==false||!mediaProgressExpectedEvent.defaultPrevented||mediaProgressExpectedEvent.currentTarget!==null)return false}return true})()')! == 'true'
			event := media_progress_raw_event(name)
			native_wrapper := runtime.javascript_event(event)!
			export_name := '__mediaProgressNative_${wrapper_name}'
			runtime.define_value_host_function(export_name, fn [native_wrapper] (_ voidptr, _ []voidptr) !voidptr { return native_wrapper })!
			runtime.evaluate_host('mediaProgressExpectedEvent=${export_name}();mediaProgressTrusted=true;0')!
			assert !target.dispatch_event(event)
			assert event.is_trusted() && event.default_prevented() && event.current_target() == none
			assert element.get_attribute_value('on${name}') == media_progress_raw_body
			media_progress_raw_assert_contexts(fixture)
		}
		assert runtime.evaluate_host('mediaProgressRuns===15&&mediaProgressChecks.length===15&&mediaProgressChecks.every(Boolean)&&window.event===undefined')! == 'true'
		// Both progress names use the native media scope; the actual ancestor form is absent.
		runtime.evaluate_host(r'Object.defineProperty(mediaProgressForm,"scopeKey",{get(){throw "wrong form scope"}});video.scopeKey="element";video.event={sentinel:true};0')!
		mut video_element := fixture.document.get_element_by_id('video')?
		scope_body := 'mediaProgressChecks.push(scopeKey==="element");delete this.scopeKey;mediaProgressChecks.push(scopeKey==="document");delete document.scopeKey;mediaProgressChecks.push(scopeKey==="global");this.on${name}=null;mediaProgressChecks.push(on${name}===null&&arguments.length===1&&event===arguments[0]&&new.target===undefined&&typeof __scopes==="undefined"&&typeof __body==="undefined");return false;'
		video_element.set_attribute_value('on${name}', scope_body)
		video_target := unsafe { &dom.EventTarget(video_element) }
		assert !video_target.dispatch_event(media_progress_raw_event(name))
		assert runtime.evaluate_host('mediaProgressChecks.length===19&&mediaProgressChecks.every(Boolean)&&video.on${name}===null&&window.event===undefined')! == 'true'
		// A later installed host must not erase the older facade's actual model owner.
		old_wrapper := runtime.evaluate_host_value('video')!
		mut later_host := MediaElementHost.create(fixture.document, none)!
		later_host.install(mut runtime)!
		assert runtime.media_element_hosts_.len == 2
		assert old_wrapper in fixture.media_host.records && old_wrapper !in later_host.records
		video_element.set_attribute_value('on${name}', 'return false;')
		assert video_target.get_current_value_of_event_handler(name) != none
		assert !video_target.dispatch_event(media_progress_raw_event(name))
		assert fixture.settings.realm().reported_exceptions.len == 0
		media_progress_raw_assert_contexts(fixture)
	}
}

fn test_raw_media_progress_function_body_csp_name_filter_and_unavailable_owners_preserve_slots() {
	$if !darwin { return }
	for name in ['progress', 'suspend'] {
		fixture := media_progress_raw_fixture(name, true, true)!
		mut runtime := fixture.runtime
		defer { runtime.close() }
		mut audio_element := fixture.document.get_element_by_id('audio')?
		target := unsafe { &dom.EventTarget(audio_element) }
		mut unbound_element := media_progress_raw_element_by_marker(fixture, 'invalid')
		unbound_target := unsafe { &dom.EventTarget(unbound_element) }
		resolver_calls := fixture.resolver_probe.calls
		for body in ['return (', '"use strict";let event;',
			'}},globalThis.mediaProgressRuns++,{on${name}:function(event){'] {
			unbound_element.set_attribute_value('on${name}', body)
			slot := unbound_target.data.event_handler(name) or { panic('invalid media raw slot') }
			listener := slot.listener or { panic('invalid media raw listener') }
			assert unbound_target.get_current_value_of_event_handler(name) == none
			assert unbound_target.get_current_value_of_event_handler(name) == none
			assert runtime.evaluate_host('mediaProgressRuns===0')! == 'true'
			assert slot.value.kind == .null_
			assert voidptr(slot.listener or { panic('invalid media listener retained') }) == voidptr(listener)
			assert unbound_element.get_attribute_value('on${name}') == body
			assert fixture.resolver_probe.calls == resolver_calls
			assert unsafe { &dom.HTMLAudioElement(unbound_element) }.media_element_model_ == unsafe { nil }
			assert voidptr(unbound_target) !in runtime.event_binding()!.target_wrappers
		}
		generic_element := media_progress_raw_element_by_marker(fixture, 'generic')
		generic_target := unsafe { &dom.EventTarget(generic_element) }
		generic_wrapper := runtime.evaluate_host_value('Object.create(EventTarget.prototype)')!
		runtime.bind_event_target(generic_wrapper, generic_target)!
		assert generic_target.get_current_value_of_event_handler(name) == none
		assert (generic_target.data.event_handler(name) or { panic('generic wrapper raw') }).value.kind == .string
		assert fixture.resolver_probe.calls == resolver_calls
		assert unsafe { &dom.HTMLAudioElement(generic_element) }.media_element_model_ == unsafe { nil }
		// Missing, null and throwing resolvers are owner boundaries, retaining raw/listener.
		unbound_element.set_attribute_value('on${name}', 'return false;')
		availability_slot := unbound_target.data.event_handler(name) or { panic('unavailable resolver slot') }
		availability_listener := availability_slot.listener or { panic('unavailable resolver listener') }
		mut wheel_host := fixture.wheel_host
		resolver := wheel_host.resolver
		wheel_host.resolver = unsafe { nil }
		assert unbound_target.get_current_value_of_event_handler(name) == none
		wheel_host.resolver = resolver
		assert availability_slot.value.kind == .string
		assert fixture.resolver_probe.calls == resolver_calls
		for result in ['null', 'throw'] {
			runtime.evaluate_host('mediaProgressResolverResult=${json2.encode(result)};0')!
			assert unbound_target.get_current_value_of_event_handler(name) == none
			assert availability_slot.value.kind == .string
			assert voidptr(availability_slot.listener or { panic('unavailable resolver listener retained') }) == voidptr(availability_listener)
			assert unsafe { &dom.HTMLAudioElement(unbound_element) }.media_element_model_ == unsafe { nil }
			assert voidptr(unbound_target) !in runtime.event_binding()!.target_wrappers
			media_progress_raw_assert_contexts(fixture)
		}
		runtime.evaluate_host('mediaProgressResolverResult="normal";0')!
		assert unbound_target.get_current_value_of_event_handler(name) != none
		assert voidptr(availability_slot.listener or { panic('resolved listener retained') }) == voidptr(availability_listener)
		assert fixture.resolver_probe.owner_contexts
		// Mutating the requested progress slot during resolution must preserve that later value.
		runtime.evaluate_host('globalThis.mediaProgressAssigned=function(event){mediaProgressRuns+=100;return false;};0')!
		assigned := runtime.event_callback(runtime.evaluate_host_value('mediaProgressAssigned')!, true)!
		for mode, marker in ['stale-assignment', 'stale-removal', 'stale-raw'] {
			stale_element := media_progress_raw_element_by_marker(fixture, marker)
			stale_target := unsafe { &dom.EventTarget(stale_element) }
			stale_slot := stale_target.data.event_handler(name) or { panic('stale source slot') }
			stale_listener := stale_slot.listener or { panic('stale source listener') }
			function_name := '__mediaProgressMutation_${mode}'
			target_handle := voidptr(stale_element)
			callback_handle := voidptr(assigned)
			runtime_handle := voidptr(runtime)
			runtime.define_value_host_function(function_name, fn [target_handle, callback_handle, runtime_handle, name, mode] (_ voidptr, _ []voidptr) !voidptr {
				mut element := unsafe { &dom.Element(target_handle) }
				target := unsafe { &dom.EventTarget(target_handle) }
				match mode {
					0 { target.set_event_handler_attribute(name, unsafe { &dom.CallbackType(callback_handle) }) }
					1 { element.remove_attribute('on${name}') }
					else { element.set_attribute_value('on${name}', 'mediaProgressRuns+=10;return false;') }
				}
				runtime := unsafe { &Runtime(runtime_handle) }
				return C.vox_jsc_JSValueMakeUndefined(runtime.context)
			})!
			runtime.evaluate_host('mediaProgressResolverBefore=function(){${function_name}()};0')!
			assert stale_target.get_current_value_of_event_handler(name) == none
			match mode {
				0 {
					assert voidptr(stale_target.get_current_value_of_event_handler(name) or { panic('resolver assigned callback') }) == voidptr(assigned)
					assert voidptr(stale_slot.listener or { panic('resolver assigned listener') }) == voidptr(stale_listener)
				}
				1 {
					assert !stale_target.data.has_event_handler(name)
					assert stale_slot.listener == none && stale_slot.value.kind == .null_
				}
				else {
					assert stale_slot.value.kind == .string
					assert stale_slot.value.string_data == 'mediaProgressRuns+=10;return false;'
					assert voidptr(stale_slot.listener or { panic('resolver changed raw listener') }) == voidptr(stale_listener)
				}
			}
			assert unsafe { &dom.HTMLAudioElement(stale_element) }.media_element_model_ != unsafe { nil }
			media_progress_raw_assert_contexts(fixture)
		}
		runtime.evaluate_host('mediaProgressResolverBefore=null;0')!
		assert runtime.evaluate_host('mediaProgressRuns===0')! == 'true'
		ordinary_element := fixture.document.get_element_by_id('ordinary')?
		ordinary_target := unsafe { &dom.EventTarget(ordinary_element) }
		assert ordinary_target.get_current_value_of_event_handler(name) == none
		assert (ordinary_target.data.event_handler(name) or { panic('ordinary raw progress handler unsupported') }).value.kind == .string
		audio_element.set_attribute_value('onstalled', 'globalThis.mediaProgressRuns++;')
		assert target.get_current_value_of_event_handler('stalled') == none
		assert (target.data.event_handler('stalled') or { panic('unsupported media raw name') }).value.kind == .string
		audio_element.set_attribute_value('on${name}', 'return false;')
		callback := target.get_current_value_of_event_handler(name) or { panic('valid media raw callback') }
		mut document := fixture.document
		document.set_csp_hook(dom.DocumentCSPHook{
			inline_check: fn (_ voidptr, _ &dom.Element, type_ string, _ string) bool { return type_ == 'script-attribute' }
		})
		audio_element.set_attribute_value('on${name}', 'return (')
		assert voidptr(target.get_current_value_of_event_handler(name) or { panic('CSP preserved media callback') }) == voidptr(callback)
		assert audio_element.get_attribute_value('on${name}') == 'return ('
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
		video_element.set_attribute_value('on${name}', 'return false;')
		media_host.records[video_wrapper] = audio_model
		assert video_target.get_current_value_of_event_handler(name) == none
		assert (video_target.data.event_handler(name) or { panic('mismatched model raw') }).value.kind == .string
		media_host.records.delete(video_wrapper)
		assert video_target.get_current_value_of_event_handler(name) == none
		assert (video_target.data.event_handler(name) or { panic('missing model raw') }).value.kind == .string
		media_host.records[video_wrapper] = video_model
		assert video_target.get_current_value_of_event_handler(name) != none
		video_element.set_attribute_value('on${name}', 'return false;')
		foreign_url := dom.URL{ value: 'https://foreign-media-progress.example.test/' }
		mut foreign_document := html.parse_navigation_document('<!doctype html><div></div>',
			foreign_url, foreign_url.origin(), none)!
		foreign_document.adopt_node(unsafe { &dom.Node(video_element) })
		assert video_target.get_current_value_of_event_handler(name) == none
		assert (video_target.data.event_handler(name) or { panic('foreign document raw progress handler') }).value.kind == .string
		no_document := media_progress_raw_fixture(name, true, false)!
		mut document_runtime := no_document.runtime
		defer { document_runtime.close() }
		missing_document_target := unsafe { &dom.EventTarget(no_document.document.get_element_by_id('video')?) }
		assert missing_document_target.get_current_value_of_event_handler(name) == none
		assert (missing_document_target.data.event_handler(name) or { panic('missing Document raw') }).value.kind == .string
		document_runtime.install_document_window_event_binding(no_document.document,
			document_runtime.evaluate_host_value('document')!)!
		assert missing_document_target.get_current_value_of_event_handler(name) != none
		no_media := media_progress_raw_fixture(name, false, true)!
		mut media_runtime := no_media.runtime
		defer { media_runtime.close() }
		missing_media_element := no_media.document.get_element_by_id('audio')?
		_ = html.html_media_element_for_dom_element(missing_media_element) or { panic('cached missing-host media') }
		missing_media_target := unsafe { &dom.EventTarget(missing_media_element) }
		assert missing_media_target.get_current_value_of_event_handler(name) == none
		assert (missing_media_target.data.event_handler(name) or { panic('missing MediaElementHost raw') }).value.kind == .string
		mut late_host := no_media.media_host
		late_host.install(mut media_runtime)!
		assert missing_media_target.get_current_value_of_event_handler(name) != none
		assert fixture.settings.realm().reported_exceptions.len == 0
		media_progress_raw_assert_contexts(fixture)
		media_progress_raw_assert_contexts(no_document)
		media_progress_raw_assert_contexts(no_media)
	}
}

fn test_raw_media_progress_strict_exceptions_and_page_gate_keep_owner_contexts_balanced_after_close() {
	$if !darwin { return }
	for name in ['progress', 'suspend'] {
		fixture := media_progress_raw_fixture(name, true, true)!
		mut runtime := fixture.runtime
		defer { runtime.close() }
		mut owner := fixture.owner
		mut audio_element := fixture.document.get_element_by_id('audio')?
		target := unsafe { &dom.EventTarget(audio_element) }
		runtime.evaluate_host('globalThis.mediaProgressThrown={owner:true};globalThis.mediaProgressStrict=false;0')!
		owner.set_is_scripting_enabled(false)
		audio_element.set_attribute_value('on${name}', r'"use strict";mediaProgressRuns++;mediaProgressStrict=this===audio&&arguments.length===1&&event===arguments[0]&&networkState===0&&readyState===0&&paused===true&&currentTime===0&&currentTime===mediaProgressCurrentTimeGetter.call(this);throw mediaProgressThrown;')
		assert target.get_current_value_of_event_handler(name) == none
		assert (target.data.event_handler(name) or { panic('disabled media raw') }).value.kind == .string
		assert target.dispatch_event(media_progress_raw_event(name))
		assert runtime.evaluate_host('mediaProgressRuns===0')! == 'true'
		owner.set_is_scripting_enabled(true)
		callback := target.get_current_value_of_event_handler(name) or { panic('strict media raw callback') }
		actual := runtime.javascript_event_handler(target, name)!
		owner.set_is_scripting_enabled(false)
		assert target.dispatch_event(media_progress_raw_event(name))
		assert runtime.evaluate_host('mediaProgressRuns===0')! == 'true'
		owner.set_is_scripting_enabled(true)
		assert target.dispatch_event(media_progress_raw_event(name))
		assert runtime.evaluate_host('mediaProgressRuns===1&&mediaProgressStrict&&window.event===undefined')! == 'true'
		assert fixture.settings.realm().reported_exceptions.len == 1
		reported := fixture.settings.realm().reported_exceptions[0].value.as_webidl_value()!
		assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mediaProgressThrown')!
		assert voidptr(target.get_current_value_of_event_handler(name) or { panic('strict media callback cache') }) == voidptr(callback)
		assert runtime.javascript_event_handler(target, name)! == actual
		media_progress_raw_assert_contexts(fixture)
		audio_element.set_attribute_value('on${name}', 'return false;')
		runtime.close()
		assert runtime.closed && runtime.context == unsafe { nil } && runtime.protected_values_.len == 0
		assert fixture.media_host.closed && fixture.media_host.records.len == 0
		assert fixture.wheel_host.closed && fixture.wheel_host.records.len == 0
		assert target.get_current_value_of_event_handler(name) == none
		assert (target.data.event_handler(name) or { panic('closed media raw') }).value.kind == .string
		assert target.dispatch_event(media_progress_raw_event(name))
		media_progress_raw_assert_contexts(fixture)
	}
}
