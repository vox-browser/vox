// HTML/TrackEvent.{idl,h,cpp}; payloads refer to the actual native track records.
module browserjs

import dom
import html
import highresolutiontime

fn (mut runtime Runtime) install_track_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.track_event_prototype != unsafe { nil } { return }
	construct := runtime.make_native_value_host_function('TrackEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.track_event_binding_call(true, receiver, args)
	})!
	getter := runtime.make_native_value_host_function('get track', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.track_event_binding_call(false, receiver, [])
	})!
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,getTrack){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const TrackEvent=new Proxy(function TrackEvent(type,eventInitDict={}){throw new T("TrackEvent constructor requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("TrackEvent constructor requires one argument");
  apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(TrackEvent,parent);define(TrackEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:TrackEvent,writable:true,configurable:true});
 define(prototype,"track",{get:getTrack,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"TrackEvent",configurable:true});
 define(global,"TrackEvent",{value:TrackEvent,writable:true,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	binding.track_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [binding.event_constructor,
		C.JSContextGetGlobalObject(runtime.context), construct, getter])!)!
}

fn (runtime &Runtime) native_track_event_payload(value voidptr) !html.TrackEventTrack {
	runtime.require_javascript_value_context()!
	if C.JSValueIsUndefined(runtime.context, value) || C.JSValueIsNull(runtime.context, value) {
		return html.TrackEventTrack{}
	}
	// Interface conversion uses runtime-local brands, with no author property or
	// prototype reads. A Proxy or prototype-derived object has no native brand.
	for host in runtime.media_element_hosts_ {
		if host.closed { continue }
		if track := host.video_tracks[value] { return html.TrackEventTrack.from_video(track) }
		if track := host.audio_tracks[value] { return html.TrackEventTrack.from_audio(track) }
		if track := host.text_tracks[value] { return html.TrackEventTrack.from_text(track) }
	}
	return runtime.event_binding_type_error('TrackEvent track is not a native VideoTrack, AudioTrack or TextTrack')
}

fn (mut runtime Runtime) javascript_track_event_payload(event &html.TrackEvent) !voidptr {
	runtime.require_javascript_value_context()!
	payload := event.track()
	if payload.kind == .empty { return C.vox_jsc_JSValueMakeNull(runtime.context) }
	// Saved wrappers remain valid after removal from their media list.
	for host in runtime.media_element_hosts_ {
		if host.closed { continue }
		match payload.kind {
			.video {
				track := payload.video or { return runtime.event_binding_type_error('Missing native video track') }
				if wrapper := host.video_owner_wrappers[voidptr(track)] { return wrapper }
			}
			.audio {
				track := payload.audio or { return runtime.event_binding_type_error('Missing native audio track') }
				if wrapper := host.audio_owner_wrappers[voidptr(track)] { return wrapper }
			}
			.text {
				track := payload.text or { return runtime.event_binding_type_error('Missing native text track') }
				if wrapper := host.text_owner_wrappers[voidptr(track)] { return wrapper }
			}
			.empty {}
		}
	}
	// Native list events may introduce a track before JavaScript requests its
	// indexed wrapper. The actual list target also permits a removed track's
	// first wrapper to be created after list membership has been cleared.
	target := event.target() or { unsafe { nil } }
	for mut host in runtime.media_element_hosts_ {
		if host.closed { continue }
		if payload.kind == .text {
			track := payload.text or { return runtime.event_binding_type_error('Missing native text track') }
			if _ := host.track_element_text_track(&track.EventTarget) { return host.wrap_text_track(track) }
		}
		for _, media in host.records {
			match payload.kind {
				.video {
					track := payload.video or { return runtime.event_binding_type_error('Missing native video track') }
					list := media.video_tracks()
					if voidptr(target) == voidptr(&list.EventTarget) || list.tracks().any(voidptr(it) == voidptr(track)) {
						return host.wrap_video_track(track)
					}
				}
				.audio {
					track := payload.audio or { return runtime.event_binding_type_error('Missing native audio track') }
					list := media.audio_tracks()
					if voidptr(target) == voidptr(list.event_target()) || list.tracks().any(voidptr(it) == voidptr(track)) {
						return host.wrap_audio_track(track)
					}
				}
				.text {
					track := payload.text or { return runtime.event_binding_type_error('Missing native text track') }
					list := media.text_tracks()
					mut member := false
					for index in 0 .. list.length() {
						item := list.item(index) or { continue }
						if voidptr(item) == voidptr(track) { member = true; break }
					}
					if voidptr(target) == voidptr(&list.EventTarget) || member { return host.wrap_text_track(track) }
				}
				.empty {}
			}
		}
	}
	return runtime.event_binding_type_error('TrackEvent track has no available native media binding')
}

fn (mut runtime Runtime) track_event_binding_call(construct bool, receiver voidptr, args []voidptr) !voidptr {
	if construct {
		if args.len < 2 { return runtime.event_binding_type_error('Missing internal TrackEvent arguments') }
		type_ := runtime.binding_dom_utf16(args[0])!.str()
		bubbles := runtime.event_binding_bool_property(args[1], 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(args[1], 'cancelable', false)!
		composed := runtime.event_binding_bool_property(args[1], 'composed', false)!
		track := runtime.native_track_event_payload(runtime.ui_event_dictionary_member(args[1], 'track')!)!
		mut event := html.TrackEvent.construct_impl(type_, html.TrackEventInit{
			EventInit: dom.EventInit{bubbles: bubbles, cancelable: cancelable, composed: composed}
			track: track
		})!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin: settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	event := runtime.native_event(receiver)!
	if event.interface_ != .track_event { return runtime.event_binding_type_error('Illegal TrackEvent receiver') }
	return runtime.javascript_track_event_payload(unsafe { &html.TrackEvent(event) })
}
