module browserjs

import dom
import html
import json2
import libjs
import math
import mediasourceextensions
import webidl


fn C.JSObjectMakeDate(context voidptr, count usize, arguments &voidptr, exception &voidptr) voidptr

pub fn (mut host MediaElementHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	runtime.install_event_target_binding()!
	runtime.install_time_ranges_binding()!
	runtime.install_media_error_binding()!
	runtime.install_dom_exception_binding()!
	host.runtime = &runtime
	handle := voidptr(&host)
	mut getters := []voidptr{}
	for name in ['buffered', 'currentSrc', 'networkState', 'readyState', 'seeking', 'duration', 'paused', 'ended', 'defaultPlaybackRate', 'playbackRate', 'volume', 'muted', 'currentTime', 'error', 'played', 'seekable'] {
		getters << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.get(name, receiver) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(getters.len), getters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	mut setters := []voidptr{}
	for name in ['defaultPlaybackRate', 'playbackRate', 'volume', 'muted', 'currentTime'] {
		setters << runtime.make_native_value_host_function('set ${name}', 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			mut argument := C.JSValueMakeUndefined(host.runtime.context)
			if args.len > 0 { argument = args[0] }
			return host.set_property(name, receiver, argument) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	setter_array := C.JSObjectMakeArray(runtime.context, usize(setters.len), setters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(setter_array)!
	defer { runtime.release_javascript_value(setter_array) }
	mut handler_getters := []voidptr{}
	mut handler_setters := []voidptr{}
	for name in media_element_event_handler_names {
		handler_getters << runtime.make_native_value_host_function('get on${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.get_event_handler(name, receiver) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
		handler_setters << runtime.make_native_value_host_function('set on${name}', 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			mut argument := C.JSValueMakeUndefined(host.runtime.context)
			if args.len > 0 { argument = args[0] }
			return host.set_event_handler(name, receiver, argument) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	handler_getter_array := C.JSObjectMakeArray(runtime.context, usize(handler_getters.len), handler_getters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(handler_getter_array)!
	defer { runtime.release_javascript_value(handler_getter_array) }
	handler_setter_array := C.JSObjectMakeArray(runtime.context, usize(handler_setters.len), handler_setters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(handler_setter_array)!
	defer { runtime.release_javascript_value(handler_setter_array) }
	fast_seek := runtime.make_native_value_host_function('fastSeek', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.fast_seek(receiver, args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	start_date := runtime.make_native_value_host_function('getStartDate', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.start_date(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	pause := runtime.make_native_value_host_function('pause', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.pause(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	load := runtime.make_native_value_host_function('load', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.load(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	play := runtime.make_native_value_host_function('play', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		// Promise-returning WebIDL operations reject binding abrupt completions.
		return host.play(receiver) or { host.reject_play_binding_exception(err) }
	})!
	can_play_type := runtime.make_native_value_host_function('canPlayType', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.can_play_type(receiver, args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	default_muted_getter := runtime.make_native_value_host_function('get defaultMuted', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.default_muted(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	default_muted_setter := runtime.make_native_value_host_function('set defaultMuted', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_default_muted(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	set_attribute_sync := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.set_attribute_sync(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	loop_getter := runtime.make_native_value_host_function('get loop', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.loop(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	loop_setter := runtime.make_native_value_host_function('set loop', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_loop(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	autoplay_getter := runtime.make_native_value_host_function('get autoplay', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.autoplay(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	autoplay_setter := runtime.make_native_value_host_function('set autoplay', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_autoplay(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	preload_getter := runtime.make_native_value_host_function('get preload', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.preload(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	preload_setter := runtime.make_native_value_host_function('set preload', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_preload(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	cross_origin_getter := runtime.make_native_value_host_function('get crossOrigin', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.cross_origin(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	cross_origin_setter := runtime.make_native_value_host_function('set crossOrigin', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_cross_origin(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	mut dimension_getters := []voidptr{}
	for name in ['videoWidth', 'videoHeight'] {
		dimension_getters << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.video_dimension(name, receiver) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	dimension_array := C.JSObjectMakeArray(runtime.context, usize(dimension_getters.len), dimension_getters.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(dimension_array)!
	defer { runtime.release_javascript_value(dimension_array) }
	mut size_accessors := []voidptr{}
	for name in ['width', 'height'] {
		size_accessors << runtime.make_native_value_host_function('get ${name}', 0, fn [handle, name] (receiver voidptr, _ []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.video_size_attribute(name, receiver) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
		size_accessors << runtime.make_native_value_host_function('set ${name}', 1, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			mut value := C.JSValueMakeUndefined(host.runtime.context)
			if args.len > 0 { value = args[0] }
			return host.set_video_size_attribute(name, receiver, value) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	size_array := C.JSObjectMakeArray(runtime.context, usize(size_accessors.len), size_accessors.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(size_array)!
	defer { runtime.release_javascript_value(size_array) }
	poster_getter := runtime.make_native_value_host_function('get poster', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.poster(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	poster_setter := runtime.make_native_value_host_function('set poster', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_poster(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	controls_getter := runtime.make_native_value_host_function('get controls', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.controls(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	controls_setter := runtime.make_native_value_host_function('set controls', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_controls(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	plays_inline_getter := runtime.make_native_value_host_function('get playsInline', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.plays_inline(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	plays_inline_setter := runtime.make_native_value_host_function('set playsInline', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_plays_inline(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	src_getter := runtime.make_native_value_host_function('get src', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.src(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	src_setter := runtime.make_native_value_host_function('set src', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_src(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	src_object_getter := runtime.make_native_value_host_function('get srcObject', 0, fn [handle] (receiver voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.src_object(receiver) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	src_object_setter := runtime.make_native_value_host_function('set srcObject', 1, fn [handle] (receiver voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		mut value := C.JSValueMakeUndefined(host.runtime.context)
		if args.len > 0 { value = args[0] }
		return host.set_src_object(receiver, value) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	create_audio := runtime.make_value_host_function(fn [handle] (_ voidptr, _ []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.create_audio() or { return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	initialize_audio := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.initialize_audio(args) or { return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err)) }
	})!
	register_audio_factory := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		if host.closed || args.len != 1 || !C.JSValueIsObject(host.runtime.context, args[0])
			|| !C.JSObjectIsFunction(host.runtime.context, args[0]) || host.audio_factory != unsafe { nil } {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(error('TypeError: Audio facade factory must be installed once with a callable')))
		}
		host.audio_factory = host.runtime.retain_javascript_value(args[0])!
		return C.JSValueMakeUndefined(host.runtime.context)
	})!
	bind := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.bind(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(media_element_native_factory.replace('__MEDIA_HANDLER_NAMES__',
		json2.encode(media_element_event_handler_names)))!
	defer { runtime.release_javascript_value(factory) }
	prototypes := runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [array, setter_array, bind, fast_seek, start_date,
			pause, load, play, handler_getter_array, handler_setter_array, can_play_type,
			default_muted_getter, default_muted_setter, set_attribute_sync, loop_getter, loop_setter,
			autoplay_getter, autoplay_setter, preload_getter, preload_setter,
			cross_origin_getter, cross_origin_setter, controls_getter, controls_setter,
			poster_getter, poster_setter, dimension_array, size_array,
			plays_inline_getter, plays_inline_setter, src_getter, src_setter,
			src_object_getter, src_object_setter, create_audio, initialize_audio, register_audio_factory])!)!
	defer { runtime.release_javascript_value(prototypes) }
	host.prototype = runtime.retain_javascript_value(runtime.binding_property(prototypes, 'media')!)!
	host.audio_prototype = runtime.retain_javascript_value(runtime.binding_property(prototypes, 'audio')!)!
	host.video_prototype = runtime.retain_javascript_value(runtime.binding_property(prototypes, 'video')!)!
	host.install_media_tracks()!
	host.install_track_elements()!
	runtime.add_canvas_element_provider_with_identity_lookup(fn [handle] () map[string]&dom.Element {
		host := unsafe { &MediaElementHost(handle) }
		return host.elements_for_binding()
	}, fn [handle] (key string) ?&dom.Element {
		host := unsafe { &MediaElementHost(handle) }
		if key !in host.elements { return none }
		return unsafe { host.elements[key] }
	}, fn [handle] (element &dom.Element) []string {
		host := unsafe { &MediaElementHost(handle) }
		return native_canvas_element_identity_keys(host.elements, element)
	})
	runtime.add_close_handler(fn [handle] () {
		mut host := unsafe { &MediaElementHost(handle) }
		host.closed = true
		host.attribute_sync = unsafe { nil }
		host.audio_factory = unsafe { nil }
		host.audio_track_prototype = unsafe { nil }
		host.audio_list_wrap = unsafe { nil }
		host.audio_lists = {}
		host.audio_tracks = {}
		host.audio_owner_wrappers = {}
		host.video_track_prototype = unsafe { nil }
		host.video_list_wrap = unsafe { nil }
		host.video_lists = {}
		host.video_tracks = {}
		host.video_owner_wrappers = {}
		host.text_track_prototype = unsafe { nil }
		host.text_list_wrap = unsafe { nil }
		host.text_lists = {}
		host.text_tracks = {}
		host.text_owner_wrappers = {}
		host.track_element_prototype = unsafe { nil }
		host.track_elements = {}
		host.bound_elements = {}
		host.records = {}
		host.elements = {}
	})
	// The combined Document compiler must use this owner's actual media records.
	runtime.media_element_hosts_ << &host
}

fn (mut host MediaElementHost) bind(args []voidptr) !voidptr {
	if host.closed || args.len != 3 { return error('TypeError: Invalid media element binding') }
	wrapper := args[0]
	if !C.JSValueIsObject(host.runtime.context, wrapper) {
		return error('TypeError: Media element wrapper is not an object')
	}
	if _ := host.records[wrapper] { return C.JSValueMakeUndefined(host.runtime.context) }
	key := host.runtime.binding_dom_string(args[1])!
	tag := host.runtime.binding_dom_string(args[2])!
	element := host.element_for_binding(key, tag)!
	media := html.html_media_element_for_dom_element(element) or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	host.runtime.bind_event_target(wrapper, unsafe { &dom.EventTarget(element) })!
	mut prototype := host.prototype
	if element.local_name() == 'audio' { prototype = host.audio_prototype }
	if element.local_name() == 'video' { prototype = host.video_prototype }
	C.JSObjectSetPrototype(host.runtime.context, wrapper, prototype)
	host.records[wrapper] = media
	host.bound_elements[wrapper] = element
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) create_audio() !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if replay := host.replay { replay(host.runtime)! }
	if host.audio_factory != unsafe { nil } {
		wrapper := host.runtime.call_javascript_function(host.audio_factory, C.JSValueMakeUndefined(host.runtime.context), [])!
		host.media_element_for_binding(wrapper)!
		element := host.bound_elements[wrapper] or { return error('TypeError: Audio factory has no native owner') }
		if element.local_name() != 'audio' { return error('TypeError: Audio factory requires an HTML audio owner') }
		return wrapper
	}
	mut key := ''
	for {
		host.audio_factory_serial++
		key = '__created_native_audio_${host.audio_factory_serial}'
		if key !in host.elements { break }
	}
	wrapper := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	host.runtime.retain_javascript_value(wrapper)!
	host.bind([wrapper, host.runtime.binding_string(key), host.runtime.binding_string('audio')])!
	return wrapper
}

fn (mut host MediaElementHost) initialize_audio(args []voidptr) !voidptr {
	if args.len != 2 { return error('TypeError: Invalid Audio initialization') }
	receiver := args[0]
	host.media_element_for_binding(receiver)!
	mut element := host.bound_elements[receiver] or { return error('TypeError: Audio factory has no native owner') }
	if element.local_name() != 'audio' { return error('TypeError: Audio factory requires an HTML audio owner') }
	if replay := host.replay { replay(host.runtime)! }
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync, C.JSValueMakeUndefined(host.runtime.context),
			[receiver, host.runtime.binding_string('preload'), host.runtime.binding_string('auto')])!
	}
	element.set_attribute_value('preload', 'auto')
	// AudioConstructor.cpp converts the optional DOMString only after creation,
	// prototype resolution and the preload write. Undefined leaves src absent.
	if !C.JSValueIsUndefined(host.runtime.context, args[1]) {
		source := host.runtime.binding_dom_utf16(args[1])!
		if host.attribute_sync != unsafe { nil } {
			host.runtime.call_javascript_function(host.attribute_sync, C.JSValueMakeUndefined(host.runtime.context),
				[receiver, host.runtime.binding_string('src'), host.runtime.binding_utf16_string(source)!])!
		}
		element.set_attribute_value('src', source.str())
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) set_attribute_sync(args []voidptr) !voidptr {
	if host.closed || args.len != 1 || !C.JSValueIsObject(host.runtime.context, args[0])
		|| !C.JSObjectIsFunction(host.runtime.context, args[0]) {
		return error('TypeError: Media attribute synchronization must be callable')
	}
	if host.attribute_sync != unsafe { nil } {
		return error('TypeError: Media attribute synchronization is already installed')
	}
	host.attribute_sync = host.runtime.retain_javascript_value(args[0])!
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) default_muted(receiver voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	element := host.bound_elements[receiver] or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	return C.JSValueMakeBoolean(host.runtime.context, element.has_attribute_ns(none, 'muted'))
}

fn (mut host MediaElementHost) set_default_muted(receiver voidptr, value voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	// Reflected boolean setters perform ToBoolean without author conversion hooks.
	present := C.JSValueToBoolean(host.runtime.context, value)
	if replay := host.replay { replay(host.runtime)! }
	mut element := host.bound_elements[receiver] or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	if present {
		element.set_attribute_value('muted', '')
	} else {
		element.remove_attribute_ns(none, 'muted')
	}
	// This content attribute does not change the independent runtime muted state.
	// DOM mutation preserves its mutation records and custom-element reaction queue;
	// synchronous customized-built-in reaction delivery remains a runtime boundary.
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('muted'), C.JSValueMakeBoolean(host.runtime.context, present)])!
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) loop(receiver voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	element := host.bound_elements[receiver] or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	return C.JSValueMakeBoolean(host.runtime.context, element.has_attribute_ns(none, 'loop'))
}

fn (mut host MediaElementHost) set_loop(receiver voidptr, value voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	// Reflected boolean setters do not invoke author conversion hooks.
	present := C.JSValueToBoolean(host.runtime.context, value)
	if replay := host.replay { replay(host.runtime)! }
	media.set_loop(present)
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('loop'), C.JSValueMakeBoolean(host.runtime.context, present)])!
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) autoplay(receiver voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	element := host.bound_elements[receiver] or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	return C.JSValueMakeBoolean(host.runtime.context, element.has_attribute_ns(none, 'autoplay'))
}

fn (mut host MediaElementHost) set_autoplay(receiver voidptr, value voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	present := C.JSValueToBoolean(host.runtime.context, value)
	if replay := host.replay { replay(host.runtime)! }
	// Resource fetching can reenter JavaScript after the DOM mutation. Publish
	// the outer write first so an inner reflected write remains the final value.
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('autoplay'), C.JSValueMakeBoolean(host.runtime.context, present)])!
	}
	media.set_autoplay(present)
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) preload(receiver voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	return host.runtime.binding_string(media.preload())
}

fn (mut host MediaElementHost) set_preload(receiver voidptr, value voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	// DOMString conversion retains NUL and lone surrogates and runs once.
	converted := host.runtime.binding_dom_utf16(value)!
	raw := converted.str()
	if replay := host.replay { replay(host.runtime)! }
	// Publish the raw string before deferred fetching can reenter and replace it.
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('preload'), host.runtime.binding_utf16_string(converted)!])!
	}
	media.set_preload(raw)
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) cross_origin(receiver voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	if keyword := media.cross_origin() { return host.runtime.binding_string(keyword) }
	return C.JSValueMakeNull(host.runtime.context)
}

fn (mut host MediaElementHost) set_cross_origin(receiver voidptr, value voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	mut converted := ?libjs.Utf16String(none)
	if !C.JSValueIsNull(host.runtime.context, value) && !C.JSValueIsUndefined(host.runtime.context, value) {
		converted = host.runtime.binding_dom_utf16(value)!
	}
	if replay := host.replay { replay(host.runtime)! }
	mut raw := ?string(none)
	mut synchronized_value := C.JSValueMakeBoolean(host.runtime.context, false)
	if text := converted {
		raw = text.str()
		synchronized_value = host.runtime.binding_utf16_string(text)!
	}
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('crossorigin'), synchronized_value])!
	}
	media.set_crossorigin(raw)
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (host &MediaElementHost) video_element_for_binding(receiver voidptr) !&dom.Element {
	if host.closed { return error('Media element binding is closed') }
	if element := host.bound_elements[receiver] {
		if element.is_html_element() && element.local_name() == 'video' { return element }
	}
	return error('TypeError: Not an object of type HTMLVideoElement')
}

fn (mut host MediaElementHost) video_dimension(name string, receiver voidptr) !voidptr {
	element := host.video_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	mut pixels := video.video_width()
	if name == 'videoHeight' { pixels = video.video_height() }
	return C.JSValueMakeNumber(host.runtime.context, f64(pixels))
}

fn (mut host MediaElementHost) video_size_attribute(name string, receiver voidptr) !voidptr {
	element := host.video_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	// Source's unsigned-long reflection reads the first qualified attribute.
	raw := element.get_attribute(name) or { return C.JSValueMakeNumber(host.runtime.context, 0) }
	value := html.parse_non_negative_integer(raw) or { return C.JSValueMakeNumber(host.runtime.context, 0) }
	if value > 0x7fff_ffff { return C.JSValueMakeNumber(host.runtime.context, 0) }
	return C.JSValueMakeNumber(host.runtime.context, f64(value))
}

fn (mut host MediaElementHost) set_video_size_attribute(name string, receiver voidptr, value voidptr) !voidptr {
	mut element := host.video_element_for_binding(receiver)!
	converted := u32(webidl.convert_to_int(host.runtime.webidl_value(value)!, 32, false, .no, .no)!)
	if replay := host.replay { replay(host.runtime)! }
	// The generated reflection setter applies this limit after WebIDL wrapping.
	mut reflected := converted
	if reflected > 0x7fff_ffff { reflected = 0 }
	raw := reflected.str()
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string(name), host.runtime.binding_string(raw)])!
	}
	element.set_attribute_value(name, raw)
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) plays_inline(receiver voidptr) !voidptr {
	element := host.video_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	return C.JSValueMakeBoolean(host.runtime.context, element.has_attribute('playsinline'))
}

fn (mut host MediaElementHost) set_plays_inline(receiver voidptr, value voidptr) !voidptr {
	mut element := host.video_element_for_binding(receiver)!
	present := C.JSValueToBoolean(host.runtime.context, value)
	if replay := host.replay { replay(host.runtime)! }
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('playsinline'), C.JSValueMakeBoolean(host.runtime.context, present),
				C.JSValueMakeBoolean(host.runtime.context, true)])!
	}
	// Generated boolean reflection removes the first qualified Attr, while
	// presence writes an empty value into the null-namespace slot.
	if present {
		element.set_attribute_value('playsinline', '')
	} else {
		element.remove_attribute('playsinline')
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) src(receiver voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	element := host.bound_elements[receiver] or { return error('TypeError: Not an object of type HTMLMediaElement') }
	if replay := host.replay { replay(host.runtime)! }
	raw := element.get_attribute('src') or { return host.runtime.binding_string('') }
	if url := element.document().encoding_parse_and_serialize_url(raw) {
		return host.runtime.binding_string(url)
	}
	return host.runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(raw).to_well_formed())
}

fn (mut host MediaElementHost) set_src(receiver voidptr, value voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	mut element := host.bound_elements[receiver] or { return error('TypeError: Not an object of type HTMLMediaElement') }
	converted := host.runtime.binding_dom_utf16(value)!.to_well_formed()
	if replay := host.replay { replay(host.runtime)! }
	// Publish captured raw attributes before the DOM load hook can reenter.
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('src'), host.runtime.binding_utf16_string(converted)!])!
	}
	element.set_attribute_value('src', converted.str())
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) src_object(receiver voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	provider := media.src_object() or { return C.JSValueMakeNull(host.runtime.context) }
	if provider.kind == .blob {
		blob := provider.blob or { return error('TypeError: Media provider has no Blob') }
		return host.runtime.javascript_blob(blob)
	}
	// This typed HTML/MSE boundary carries the actual MediaSource, not a
	// serialized handle or a JavaScript-visible property on a lookalike.
	source := unsafe { &mediasourceextensions.MediaSource(provider.media_source_handle) }
	return host.runtime.javascript_media_source(source)
}

fn (mut host MediaElementHost) set_src_object(receiver voidptr, value voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	mut provider := ?html.MediaProviderObject(none)
	if !C.JSValueIsNull(host.runtime.context, value) && !C.JSValueIsUndefined(host.runtime.context, value) {
		if blob := host.runtime.native_blob(value) {
			provider = html.MediaProviderObject.from_blob(blob)
		} else if source := host.runtime.native_media_source(value) {
			provider = source.as_media_provider()
		} else {
			return error('TypeError: No union types matched')
		}
	}
	if replay := host.replay { replay(host.runtime)! }
	media.set_src_object(provider) or {
		message := err.msg()
		if !message.starts_with('NotSupportedError:') { return err }
		native_exception := webidl.dom_exception_value(webidl.DOMException.create('NotSupportedError',
			message['NotSupportedError:'.len..].trim_left(' ')))
		return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native_exception)!)
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) poster(receiver voidptr) !voidptr {
	element := host.video_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	// Source reflection reads the first qualified Attr, while writes target
	// the null-namespace slot through set_attribute_value().
	raw := element.get_attribute('poster') or { return host.runtime.binding_string('') }
	if url := element.document().encoding_parse_and_serialize_url(raw) {
		return host.runtime.binding_string(url)
	}
	return host.runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(raw).to_well_formed())
}

fn (mut host MediaElementHost) set_poster(receiver voidptr, value voidptr) !voidptr {
	mut element := host.video_element_for_binding(receiver)!
	converted := host.runtime.binding_dom_utf16(value)!.to_well_formed()
	if replay := host.replay { replay(host.runtime)! }
	// Publish facade text before the existing poster algorithm can reenter.
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('poster'), host.runtime.binding_utf16_string(converted)!])!
	}
	element.set_attribute_value('poster', converted.str())
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) controls(receiver voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	element := host.bound_elements[receiver] or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	return C.JSValueMakeBoolean(host.runtime.context, element.has_attribute_ns(none, 'controls'))
}

fn (mut host MediaElementHost) set_controls(receiver voidptr, value voidptr) !voidptr {
	host.media_element_for_binding(receiver)!
	// WebIDL boolean conversion does not invoke author conversion hooks.
	present := C.JSValueToBoolean(host.runtime.context, value)
	if replay := host.replay { replay(host.runtime)! }
	mut element := host.bound_elements[receiver] or {
		return error('TypeError: Not an object of type HTMLMediaElement')
	}
	if host.attribute_sync != unsafe { nil } {
		host.runtime.call_javascript_function(host.attribute_sync,
			C.JSValueMakeUndefined(host.runtime.context), [receiver,
				host.runtime.binding_string('controls'), C.JSValueMakeBoolean(host.runtime.context, present)])!
	}
	// Reflect the content attribute, independently of the controls UI's lifecycle.
	if present {
		element.set_attribute_value('controls', '')
	} else {
		element.remove_attribute_ns(none, 'controls')
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) get(name string, receiver voidptr) !voidptr {
	// Native receiver checks precede replay, including author Proxy traps.
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	return match name {
		'buffered' { host.runtime.javascript_time_ranges(media.buffered())! }
		'played' { host.runtime.javascript_time_ranges(media.played())! }
		'seekable' { host.runtime.javascript_time_ranges(media.seekable())! }
		'currentSrc' { host.runtime.binding_string(media.current_src()) }
		'networkState' { C.JSValueMakeNumber(host.runtime.context, f64(media.network_state())) }
		'readyState' { C.JSValueMakeNumber(host.runtime.context, f64(media.ready_state())) }
		'seeking' { C.JSValueMakeBoolean(host.runtime.context, media.seeking()) }
		'duration' { C.JSValueMakeNumber(host.runtime.context, media.duration()) }
		'paused' { C.JSValueMakeBoolean(host.runtime.context, media.paused()) }
		'ended' { C.JSValueMakeBoolean(host.runtime.context, media.ended()) }
		'defaultPlaybackRate' { C.JSValueMakeNumber(host.runtime.context, media.default_playback_rate()) }
		'playbackRate' { C.JSValueMakeNumber(host.runtime.context, media.playback_rate()) }
		'volume' { C.JSValueMakeNumber(host.runtime.context, media.volume()) }
		'muted' { C.JSValueMakeBoolean(host.runtime.context, media.muted()) }
		'currentTime' { C.JSValueMakeNumber(host.runtime.context, media.current_time()) }
		'error' {
			if failure := media.error() { host.runtime.javascript_media_error(failure)! }
			else { C.JSValueMakeNull(host.runtime.context) }
		}
		else { return error('Unknown media element getter') }
	}
}

fn (mut host MediaElementHost) get_event_handler(name string, receiver voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	return host.runtime.javascript_event_handler(media.event_target(), name)
}

fn (mut host MediaElementHost) set_event_handler(name string, receiver voidptr, value voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	// Convert and capture the incumbent settings before replaying DOM mutations.
	callback := host.runtime.event_callback(value, true)!
	if replay := host.replay { replay(host.runtime)! }
	media.event_target().set_event_handler_attribute(name, if callback != unsafe { nil } {
		?&dom.CallbackType(callback)
	} else {
		none
	})
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) restricted_double(name string, value voidptr) !f64 {
	// Unary plus preserves ECMAScript ToNumber, including the BigInt rejection.
	converted := host.runtime.call_engine_function(host.runtime.value_number_intrinsic_, [value])!
	mut exception := unsafe { nil }
	number := C.JSValueToNumber(host.runtime.context, converted, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	if !math.is_finite(number) { return error('TypeError: Expected ${name} to be a finite floating-point number') }
	return number
}

fn (mut host MediaElementHost) fast_seek(receiver voidptr, args []voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	// Source's generated operation checks the receiver, arity, then conversion.
	if args.len == 0 { return error('TypeError: fastSeek() needs one argument') }
	number := host.restricted_double('time', args[0])!
	if replay := host.replay { replay(host.runtime)! }
	media.fast_seek(number)
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) can_play_type(receiver voidptr, args []voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if args.len == 0 { return error('TypeError: canPlayType() needs one argument') }
	// DOMString retains every UTF-16 code unit, including lone surrogates.
	converted := host.runtime.binding_dom_utf16(args[0])!
	type_ := converted.str()
	if replay := host.replay { replay(host.runtime)! }
	return host.runtime.binding_string(match media.can_play_type(type_) {
		.empty { '' }
		.maybe { 'maybe' }
		.probably { 'probably' }
	})
}

fn (mut host MediaElementHost) start_date(receiver voidptr) !voidptr {
	media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	value := media.get_start_date().get_time()
	// Source Date::create installs the raw value; JSC's constructor TimeClips it.
	// Keep that existing engine boundary explicit instead of silently losing it.
	if !math.is_nan(value) && math.abs(value) > 8_640_000_000_000_000.0 {
		return error('Source media Date value cannot be installed exactly by JavaScriptCore')
	}
	arguments := [C.JSValueMakeNumber(host.runtime.context, value)]
	mut exception := unsafe { nil }
	date := C.JSObjectMakeDate(host.runtime.context, 1, arguments.data, &exception)
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	return date
}

fn (mut host MediaElementHost) pause(receiver voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	media.pause()
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) wrap_play_promise(promise &webidl.Promise) !voidptr {
	handle := voidptr(&host)
	return host.runtime.javascript_webidl_promise(promise, fn [handle] (value webidl.Value) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		if value.dom_exception_ != none { return host.runtime.javascript_dom_exception(value) }
		if value.kind == .undefined { return C.JSValueMakeUndefined(host.runtime.context) }
		return host.runtime.actual_webidl_value(value)
	})
}

fn (mut host MediaElementHost) reject_play_binding_exception(exception IError) !voidptr {
	actual := host.runtime.binding_exception_value(exception)
	return host.wrap_play_promise(webidl.create_rejected_promise_for(host.settings.stream_promise_context(),
		host.runtime.webidl_value(actual)!))
}

fn (mut host MediaElementHost) play(receiver voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	promise := media.play().webidl_promise() or { return error('Media play requires its actual WebIDL capability') }
	return host.wrap_play_promise(promise)
}

fn (mut host MediaElementHost) load(receiver voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	if replay := host.replay { replay(host.runtime)! }
	media.load() or {
		message := err.msg()
		if !message.starts_with('NotSupportedError:') { return err }
		native_exception := webidl.dom_exception_value(webidl.DOMException.create('NotSupportedError',
			message['NotSupportedError:'.len..].trim_left(' ')))
		return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native_exception)!)
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

fn (mut host MediaElementHost) set_property(name string, receiver voidptr, value voidptr) !voidptr {
	mut media := host.media_element_for_binding(receiver)!
	// Source's generated setters check the brand before converting the value.
	if name == 'muted' {
		// ToBoolean does not invoke author conversion hooks, including on proxies.
		muted := C.JSValueToBoolean(host.runtime.context, value)
		if replay := host.replay { replay(host.runtime)! }
		media.set_muted(muted)
		return C.JSValueMakeUndefined(host.runtime.context)
	}
	number := host.restricted_double(name, value)!
	if replay := host.replay { replay(host.runtime)! }
	if name == 'defaultPlaybackRate' {
		media.set_default_playback_rate(number)
	} else if name == 'currentTime' {
		media.set_current_time(number)
	} else if name == 'volume' {
		media.set_volume(number) or {
			message := err.msg()
			if !message.starts_with('IndexSizeError:') { return err }
			native_exception := webidl.dom_exception_value(webidl.DOMException.create('IndexSizeError',
				message['IndexSizeError:'.len..].trim_left(' ')))
			return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native_exception)!)
		}
	} else {
		media.set_playback_rate(number) or {
			message := err.msg()
			if !message.starts_with('NotSupportedError:') { return err }
			native_exception := webidl.dom_exception_value(webidl.DOMException.create('NotSupportedError',
				message['NotSupportedError:'.len..].trim_left(' ')))
			return host.runtime.actual_javascript_exception(host.runtime.javascript_dom_exception(native_exception)!)
		}
	}
	return C.JSValueMakeUndefined(host.runtime.context)
}

// The compact DOM hierarchy remains partial. This base prototype exposes only
// the completed state/range getters, rate/volume/time accessors, fastSeek,
// getStartDate, pause, load, play, canPlayType, and completed media attribute reflection,
// selected media and input handler attributes,
// and constants.
// Full HTMLElement/audio/video interfaces remain open.
const media_element_native_factory = r'(function(getters,setters,bind,fastSeek,getStartDate,pause,load,play,handlerGetters,handlerSetters,canPlayType,defaultMutedGetter,defaultMutedSetter,setAttributeSync,loopGetter,loopSetter,autoplayGetter,autoplaySetter,preloadGetter,preloadSetter,crossOriginGetter,crossOriginSetter,controlsGetter,controlsSetter,posterGetter,posterSetter,dimensionGetters,sizeAccessors,playsInlineGetter,playsInlineSetter,srcGetter,srcSetter,srcObjectGetter,srcObjectSetter,createAudio,initializeAudio,registerAudioFactory){
 "use strict";
 const define=Object.defineProperty,create=Object.create,P=Proxy,T=TypeError;
 const prototype=create(EventTarget.prototype);
 const names=["buffered","currentSrc","networkState","readyState","seeking","duration","paused","ended"];
 for(let i=0;i<names.length;i++)define(prototype,names[i],{get:getters[i],enumerable:true,configurable:true});
 const properties=["defaultPlaybackRate","playbackRate","volume","muted","currentTime"];
 for(let i=0;i<properties.length;i++)define(prototype,properties[i],{get:getters[names.length+i],set:setters[i],enumerable:true,configurable:true});
 define(prototype,"error",{get:getters[names.length+properties.length],enumerable:true,configurable:true});
 define(prototype,"played",{get:getters[names.length+properties.length+1],enumerable:true,configurable:true});
 define(prototype,"seekable",{get:getters[names.length+properties.length+2],enumerable:true,configurable:true});
 const handlerNames=__MEDIA_HANDLER_NAMES__;
 for(let i=0;i<handlerNames.length;i++)define(prototype,"on"+handlerNames[i],{get:handlerGetters[i],set:handlerSetters[i],enumerable:true,configurable:true});
 define(prototype,"fastSeek",{value:fastSeek,writable:true,enumerable:true,configurable:true});
 define(prototype,"getStartDate",{value:getStartDate,writable:true,enumerable:true,configurable:true});
 define(prototype,"pause",{value:pause,writable:true,enumerable:true,configurable:true});
 define(prototype,"load",{value:load,writable:true,enumerable:true,configurable:true});
 define(prototype,"play",{value:play,writable:true,enumerable:true,configurable:true});
 define(prototype,"canPlayType",{value:canPlayType,writable:true,enumerable:true,configurable:true});
 define(prototype,"defaultMuted",{get:defaultMutedGetter,set:defaultMutedSetter,enumerable:true,configurable:true});
 define(prototype,"loop",{get:loopGetter,set:loopSetter,enumerable:true,configurable:true});
 define(prototype,"autoplay",{get:autoplayGetter,set:autoplaySetter,enumerable:true,configurable:true});
 define(prototype,"preload",{get:preloadGetter,set:preloadSetter,enumerable:true,configurable:true});
 define(prototype,"crossOrigin",{get:crossOriginGetter,set:crossOriginSetter,enumerable:true,configurable:true});
 define(prototype,"controls",{get:controlsGetter,set:controlsSetter,enumerable:true,configurable:true});
 define(prototype,"src",{get:srcGetter,set:srcSetter,enumerable:true,configurable:true});
 define(prototype,"srcObject",{get:srcObjectGetter,set:srcObjectSetter,enumerable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"HTMLMediaElement",configurable:true});
 const constructor=new P(function HTMLMediaElement(){},{apply(){throw new T("Illegal HTMLMediaElement constructor")},construct(){throw new T("Illegal HTMLMediaElement constructor")}});
 define(constructor,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:constructor,writable:true,configurable:true});
 const constants={NETWORK_EMPTY:0,NETWORK_IDLE:1,NETWORK_LOADING:2,NETWORK_NO_SOURCE:3,HAVE_NOTHING:0,HAVE_METADATA:1,HAVE_CURRENT_DATA:2,HAVE_FUTURE_DATA:3,HAVE_ENOUGH_DATA:4};
 for(const name of Object.keys(constants))for(const object of [constructor,prototype])define(object,name,{value:constants[name],enumerable:true});
 define(globalThis,"HTMLMediaElement",{value:constructor,writable:true,configurable:true});
 define(globalThis,"__ladybirdMediaElementBind",{value:bind,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAttributeSync",{value:setAttributeSync,configurable:true});
 define(globalThis,"__ladybirdMediaElementSetAudioFactory",{value:registerAudioFactory,configurable:true});
 const audioPrototype=create(prototype);
 define(audioPrototype,Symbol.toStringTag,{value:"HTMLAudioElement",configurable:true});
 const audioConstructor=new P(function HTMLAudioElement(){},{apply(){throw new T("Illegal HTMLAudioElement constructor")},construct(){throw new T("Illegal HTMLAudioElement constructor")}});
 Object.setPrototypeOf(audioConstructor,constructor);
 define(audioConstructor,"prototype",{value:audioPrototype,writable:false});
 define(audioPrototype,"constructor",{value:audioConstructor,writable:true,configurable:true});
 define(globalThis,"HTMLAudioElement",{value:audioConstructor,writable:true,configurable:true});
 const setPrototype=Object.setPrototypeOf;
 const legacyAudio=new P(function Audio(){},{apply(){throw new T("Audio constructor must be called with \u0027new\u0027")},construct(target,args,newTarget){const audio=createAudio(),desired=newTarget.prototype;setPrototype(audio,desired!==null&&(typeof desired==="object"||typeof desired==="function")?desired:audioPrototype);initializeAudio(audio,args[0]);return audio;}});
 define(legacyAudio,"prototype",{value:audioPrototype,writable:false});
 define(globalThis,"Audio",{value:legacyAudio,writable:true,configurable:true});
 const videoPrototype=create(prototype);
 for(const [index,name] of ["videoWidth","videoHeight"].entries())define(videoPrototype,name,{get:dimensionGetters[index],enumerable:true,configurable:true});
 for(const [index,name] of ["width","height"].entries())define(videoPrototype,name,{get:sizeAccessors[index*2],set:sizeAccessors[index*2+1],enumerable:true,configurable:true});
 define(videoPrototype,"poster",{get:posterGetter,set:posterSetter,enumerable:true,configurable:true});
 define(videoPrototype,"playsInline",{get:playsInlineGetter,set:playsInlineSetter,enumerable:true,configurable:true});
 define(videoPrototype,Symbol.toStringTag,{value:"HTMLVideoElement",configurable:true});
 const videoConstructor=new P(function HTMLVideoElement(){},{apply(){throw new T("Illegal HTMLVideoElement constructor")},construct(){throw new T("Illegal HTMLVideoElement constructor")}});
 Object.setPrototypeOf(videoConstructor,constructor);
 define(videoConstructor,"prototype",{value:videoPrototype,writable:false});
 define(videoPrototype,"constructor",{value:videoConstructor,writable:true,configurable:true});
 define(globalThis,"HTMLVideoElement",{value:videoConstructor,writable:true,configurable:true});
 return {media:prototype,audio:audioPrototype,video:videoPrototype};
})'

// HTMLMediaElement track interfaces share indexed-list transport and native owners.
fn (mut host MediaElementHost) install_media_tracks() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	mut functions := []voidptr{}
	for name in ['audioTracks', 'length', 'getTrackById', 'id', 'kind', 'label', 'language', 'enabled', 'setEnabled', 'onchange', 'setOnchange', 'onaddtrack', 'setOnaddtrack', 'onremovetrack', 'setOnremovetrack'] {
		function_name := if name == 'setEnabled' { 'set enabled' } else if name.starts_with('setOn') {
			'set ${name[3..].to_lower()}'
		} else if name == 'getTrackById' { name } else { 'get ${name}' }
		arity := if name == 'getTrackById' || name.starts_with('set') { 1 } else { 0 }
		functions << runtime.make_native_value_host_function(function_name, arity, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.audio_track_operation(name, receiver, args) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	indexed := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.audio_track_list_index(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(functions.len), functions.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(media_tracks_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [array, indexed, host.prototype, C.JSValueMakeBoolean(runtime.context, false)])!)!
	defer { runtime.release_javascript_value(installed) }
	host.audio_track_prototype = runtime.retain_javascript_value(runtime.binding_property(installed, 'track')!)!
	host.audio_list_wrap = runtime.retain_javascript_value(runtime.binding_property(installed, 'wrapList')!)!
	host.install_video_tracks()!
	host.install_text_tracks()!
	runtime.install_event_target_wrapper_provider(EventTargetWrapperProvider{
		owner: handle
		create: fn [handle] (target &dom.EventTarget) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			if host.closed { return unsafe { nil } }
			if track := host.track_element_text_track(target) { return host.wrap_text_track(track) }
			for _, media in host.records {
				list := media.audio_tracks()
				if voidptr(target) == voidptr(list.event_target()) { return host.wrap_audio_track_list(list) }
				video_list := media.video_tracks()
				if voidptr(target) == voidptr(&video_list.EventTarget) { return host.wrap_video_track_list(video_list) }
				text_list := media.text_tracks()
				if voidptr(target) == voidptr(&text_list.EventTarget) { return host.wrap_text_track_list(text_list) }
				for index in 0 .. text_list.length() {
					track := text_list.item(index) or { continue }
					if voidptr(target) == voidptr(&track.EventTarget) { return host.wrap_text_track(track) }
				}
			}
			return unsafe { nil }
		}
	})!
}

fn (mut host MediaElementHost) wrap_audio_track_list(list &html.AudioTrackList) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if wrapper := host.audio_owner_wrappers[voidptr(list)] { return wrapper }
	wrapper := host.runtime.call_javascript_function(host.audio_list_wrap,
		C.JSValueMakeUndefined(host.runtime.context), [])!
	host.runtime.bind_event_target(wrapper, list.event_target())!
	host.audio_lists[wrapper] = list
	host.audio_owner_wrappers[voidptr(list)] = wrapper
	return wrapper
}

fn (mut host MediaElementHost) wrap_audio_track(track &html.AudioTrack) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if wrapper := host.audio_owner_wrappers[voidptr(track)] { return wrapper }
	wrapper := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, wrapper, host.audio_track_prototype)
	host.runtime.retain_javascript_value(wrapper)!
	host.audio_tracks[wrapper] = track
	host.audio_owner_wrappers[voidptr(track)] = wrapper
	return wrapper
}

fn (mut host MediaElementHost) audio_track_operation(name string, receiver voidptr, args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	context := host.runtime.context
	if name == 'audioTracks' {
		media := host.media_element_for_binding(receiver)!
		if replay := host.replay { replay(host.runtime)! }
		return host.wrap_audio_track_list(media.audio_tracks())
	}
	if name in ['length', 'getTrackById'] || name.starts_with('on') || name.starts_with('setOn') {
		list := host.audio_lists[receiver] or { return error('TypeError: Not an object of type AudioTrackList') }
		if name == 'length' { return C.JSValueMakeNumber(context, f64(list.length())) }
		if name == 'getTrackById' {
			if args.len == 0 { return error('TypeError: getTrackById requires at least 1 argument') }
			id := host.runtime.binding_dom_string(args[0])!
			track := list.get_track_by_id(id) or { return C.JSValueMakeNull(context) }
			return host.wrap_audio_track(track)
		}
		if name.starts_with('setOn') {
			mut value := C.JSValueMakeUndefined(context)
			if args.len > 0 { value = args[0] }
			host.runtime.set_javascript_event_handler(list.event_target(), name[5..].to_lower(), value)!
			return C.JSValueMakeUndefined(context)
		}
		return host.runtime.javascript_event_handler(list.event_target(), name[2..])
	}
	mut track := host.audio_tracks[receiver] or { return error('TypeError: Not an object of type AudioTrack') }
	if name == 'setEnabled' {
		mut value := C.JSValueMakeUndefined(context)
		if args.len > 0 { value = args[0] }
		track.set_enabled(C.JSValueToBoolean(context, value))
		return C.JSValueMakeUndefined(context)
	}
	return match name {
		'id' { host.runtime.binding_string(track.base.id()) }
		'kind' { host.runtime.binding_string(track.base.kind()) }
		'label' { host.runtime.binding_string(track.base.label()) }
		'language' { host.runtime.binding_string(track.base.language()) }
		else { C.JSValueMakeBoolean(context, track.enabled) }
	}
}

fn (mut host MediaElementHost) audio_track_list_index(args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if args.len == 1 {
		key := libjs.PropertyName.from_utf16(host.runtime.native_utf16_string(args[0])!)
		if !key.is_number() { return C.JSValueMakeUndefined(host.runtime.context) }
		return C.JSValueMakeNumber(host.runtime.context, f64(key.number))
	}
	list := host.audio_lists[args[0]] or { return error('TypeError: Not an object of type AudioTrackList') }
	mut exception := unsafe { nil }
	index := u32(C.JSValueToNumber(host.runtime.context, args[1], &exception))
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	track := list.item(index) or { return C.JSValueMakeUndefined(host.runtime.context) }
	return host.wrap_audio_track(track)
}

const media_tracks_native_factory = r'(function(functions,indexed,media,video,text){
 "use strict";
 const define=Object.defineProperty,create=Object.create,P=Proxy,T=TypeError,ET=EventTarget;
 const get=Reflect.get,set=Reflect.set,has=Reflect.has,getOwn=Reflect.getOwnPropertyDescriptor,defineOwn=Reflect.defineProperty,remove=Reflect.deleteProperty,ownKeys=Reflect.ownKeys;
 const track=create(text?ET.prototype:Object.prototype),list=create(ET.prototype);
 define(media,text?"textTracks":video?"videoTracks":"audioTracks",{get:functions[0],enumerable:true,configurable:true});
 define(list,"length",{get:functions[1],enumerable:true,configurable:true});
 define(list,"getTrackById",{value:functions[2],writable:true,enumerable:true,configurable:true});
 if(video)define(list,"selectedIndex",{get:functions[15],enumerable:true,configurable:true});
 const state=text?"mode":video?"selected":"enabled";
 if(text){define(media,"addTextTrack",{value:functions[17],writable:true,enumerable:true,configurable:true});define(track,"oncuechange",{get:functions[15],set:functions[16],enumerable:true,configurable:true});}
 for(const [index,name] of ["id","kind","label","language",state].entries())define(track,name,{get:functions[3+index],set:name===state?functions[8]:undefined,enumerable:true,configurable:true});
 for(const [index,name] of ["onchange","onaddtrack","onremovetrack"].entries())define(list,name,{get:functions[9+index*2],set:functions[10+index*2],enumerable:true,configurable:true});
 for(const [name,prototype,target] of [[text?"TextTrack":video?"VideoTrack":"AudioTrack",track,text?function TextTrack(){}:video?function VideoTrack(){}:function AudioTrack(){}],[text?"TextTrackList":video?"VideoTrackList":"AudioTrackList",list,text?function TextTrackList(){}:video?function VideoTrackList(){}:function AudioTrackList(){}]]){
  const illegal=()=>{throw new T("Illegal constructor")},constructor=new P(target,{apply:illegal,construct:illegal});
  if(text||prototype===list)Object.setPrototypeOf(constructor,ET);
  define(constructor,"prototype",{value:prototype,writable:false});define(prototype,"constructor",{value:constructor,writable:true,configurable:true});
  define(prototype,Symbol.toStringTag,{value:name,configurable:true});define(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 function arrayIndex(key){return typeof key==="string"?indexed(key):undefined}
 function wrapList(){
  const target=create(list);let wrapper;
  function property(key){const index=arrayIndex(key);if(index===undefined)return undefined;const value=indexed(wrapper,index);return value===undefined?undefined:{value,writable:false,enumerable:true,configurable:true}}
  wrapper=new P(target,{
   getOwnPropertyDescriptor(target,key){return property(key)||getOwn(target,key)},
   get(target,key,receiver){const d=property(key);return d?d.value:get(target,key,receiver)},
   has(target,key){return property(key)!==undefined||has(target,key)},
   set(target,key,value,receiver){if(property(key)!==undefined)return false;return set(target,key,value,receiver)},
   defineProperty(target,key,d){if(arrayIndex(key)!==undefined)return false;return defineOwn(target,key,d)},
   deleteProperty(target,key){if(arrayIndex(key)!==undefined)return property(key)===undefined;return remove(target,key)},
   preventExtensions(){return false},
   ownKeys(target){const keys=[];function append(key){define(keys,keys.length,{value:key,writable:true,enumerable:true,configurable:true})}for(let index=0;index<=4294967295;index++){if(indexed(wrapper,index)===undefined)break;append(`${index}`)}const ordinary=ownKeys(target);for(const key of ordinary)if(typeof key==="string")append(key);for(const key of ordinary)if(typeof key==="symbol")append(key);return keys}
  });return wrapper;
 }
 return {track,wrapList};
})'

// HTMLMediaElement.videoTracks and the native VideoTrack/List IDL owners.
fn (mut host MediaElementHost) install_video_tracks() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	mut functions := []voidptr{}
	for name in ['videoTracks', 'length', 'getTrackById', 'id', 'kind', 'label', 'language', 'selected', 'setSelected', 'onchange', 'setOnchange', 'onaddtrack', 'setOnaddtrack', 'onremovetrack', 'setOnremovetrack', 'selectedIndex'] {
		function_name := if name == 'setSelected' { 'set selected' } else if name.starts_with('setOn') {
			'set ${name[3..].to_lower()}'
		} else if name == 'getTrackById' { name } else { 'get ${name}' }
		arity := if name == 'getTrackById' || name.starts_with('set') { 1 } else { 0 }
		functions << runtime.make_native_value_host_function(function_name, arity, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.video_track_operation(name, receiver, args) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	indexed := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.video_track_list_index(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(functions.len), functions.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(media_tracks_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [array, indexed, host.prototype, C.JSValueMakeBoolean(runtime.context, true)])!)!
	defer { runtime.release_javascript_value(installed) }
	host.video_track_prototype = runtime.retain_javascript_value(runtime.binding_property(installed, 'track')!)!
	host.video_list_wrap = runtime.retain_javascript_value(runtime.binding_property(installed, 'wrapList')!)!
}

fn (mut host MediaElementHost) wrap_video_track_list(list &html.VideoTrackList) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if wrapper := host.video_owner_wrappers[voidptr(list)] { return wrapper }
	wrapper := host.runtime.call_javascript_function(host.video_list_wrap,
		C.JSValueMakeUndefined(host.runtime.context), [])!
	host.runtime.bind_event_target(wrapper, &list.EventTarget)!
	host.video_lists[wrapper] = list
	host.video_owner_wrappers[voidptr(list)] = wrapper
	return wrapper
}

fn (mut host MediaElementHost) wrap_video_track(track &html.VideoTrack) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if wrapper := host.video_owner_wrappers[voidptr(track)] { return wrapper }
	wrapper := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, wrapper, host.video_track_prototype)
	host.runtime.retain_javascript_value(wrapper)!
	host.video_tracks[wrapper] = track
	host.video_owner_wrappers[voidptr(track)] = wrapper
	return wrapper
}

fn (mut host MediaElementHost) video_track_operation(name string, receiver voidptr, args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	context := host.runtime.context
	if name == 'videoTracks' {
		media := host.media_element_for_binding(receiver)!
		if replay := host.replay { replay(host.runtime)! }
		return host.wrap_video_track_list(media.video_tracks())
	}
	if name in ['length', 'selectedIndex', 'getTrackById'] || name.starts_with('on') || name.starts_with('setOn') {
		list := host.video_lists[receiver] or { return error('TypeError: Not an object of type VideoTrackList') }
		if name == 'length' { return C.JSValueMakeNumber(context, f64(list.length())) }
		if name == 'selectedIndex' { return C.JSValueMakeNumber(context, f64(list.selected_index())) }
		if name == 'getTrackById' {
			if args.len == 0 { return error('TypeError: getTrackById requires at least 1 argument') }
			id := host.runtime.binding_dom_string(args[0])!
			track := list.get_track_by_id(id) or { return C.JSValueMakeNull(context) }
			return host.wrap_video_track(track)
		}
		if name.starts_with('setOn') {
			mut value := C.JSValueMakeUndefined(context)
			if args.len > 0 { value = args[0] }
			host.runtime.set_javascript_event_handler(&list.EventTarget, name[5..].to_lower(), value)!
			return C.JSValueMakeUndefined(context)
		}
		return host.runtime.javascript_event_handler(&list.EventTarget, name[2..])
	}
	mut track := host.video_tracks[receiver] or { return error('TypeError: Not an object of type VideoTrack') }
	if name == 'setSelected' {
		mut value := C.JSValueMakeUndefined(context)
		if args.len > 0 { value = args[0] }
		track.set_selected(C.JSValueToBoolean(context, value))
		return C.JSValueMakeUndefined(context)
	}
	return match name {
		'id' { host.runtime.binding_string(track.base.id()) }
		'kind' { host.runtime.binding_string(track.base.kind()) }
		'label' { host.runtime.binding_string(track.base.label()) }
		'language' { host.runtime.binding_string(track.base.language()) }
		else { C.JSValueMakeBoolean(context, track.selected) }
	}
}

fn (mut host MediaElementHost) video_track_list_index(args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if args.len == 1 {
		key := libjs.PropertyName.from_utf16(host.runtime.native_utf16_string(args[0])!)
		if !key.is_number() { return C.JSValueMakeUndefined(host.runtime.context) }
		return C.JSValueMakeNumber(host.runtime.context, f64(key.number))
	}
	list := host.video_lists[args[0]] or { return error('TypeError: Not an object of type VideoTrackList') }
	mut exception := unsafe { nil }
	index := u32(C.JSValueToNumber(host.runtime.context, args[1], &exception))
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	track := list.item(index) or { return C.JSValueMakeUndefined(host.runtime.context) }
	return host.wrap_video_track(track)
}

// Non-FIXME TextTrack IDL and the existing HTMLMediaElement.add_text_track owner.
fn (mut host MediaElementHost) install_text_tracks() ! {
	mut runtime := unsafe { &Runtime(host.runtime) }
	handle := voidptr(&host)
	mut functions := []voidptr{}
	for name in ['textTracks', 'length', 'getTrackById', 'id', 'kind', 'label', 'language', 'mode', 'setMode', 'onchange', 'setOnchange', 'onaddtrack', 'setOnaddtrack', 'onremovetrack', 'setOnremovetrack', 'oncuechange', 'setOncuechange', 'addTextTrack'] {
		function_name := if name == 'setMode' { 'set mode' } else if name.starts_with('setOn') {
			'set ${name[3..].to_lower()}'
		} else if name in ['getTrackById', 'addTextTrack'] { name } else { 'get ${name}' }
		arity := if name in ['getTrackById', 'addTextTrack'] || name.starts_with('set') { 1 } else { 0 }
		functions << runtime.make_native_value_host_function(function_name, arity, fn [handle, name] (receiver voidptr, args []voidptr) !voidptr {
			mut host := unsafe { &MediaElementHost(handle) }
			return host.text_track_operation(name, receiver, args) or {
				return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
			}
		})!
	}
	indexed := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &MediaElementHost(handle) }
		return host.text_track_list_index(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, usize(functions.len), functions.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(media_tracks_native_factory)!
	defer { runtime.release_javascript_value(factory) }
	installed := runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.JSValueMakeUndefined(runtime.context), [array, indexed, host.prototype, C.JSValueMakeBoolean(runtime.context, false), C.JSValueMakeBoolean(runtime.context, true)])!)!
	defer { runtime.release_javascript_value(installed) }
	host.text_track_prototype = runtime.retain_javascript_value(runtime.binding_property(installed, 'track')!)!
	host.text_list_wrap = runtime.retain_javascript_value(runtime.binding_property(installed, 'wrapList')!)!
}

fn (mut host MediaElementHost) wrap_text_track_list(list &html.TextTrackList) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if wrapper := host.text_owner_wrappers[voidptr(list)] { return wrapper }
	wrapper := host.runtime.call_javascript_function(host.text_list_wrap,
		C.JSValueMakeUndefined(host.runtime.context), [])!
	host.runtime.bind_event_target(wrapper, &list.EventTarget)!
	host.text_lists[wrapper] = list
	host.text_owner_wrappers[voidptr(list)] = wrapper
	return wrapper
}

fn (mut host MediaElementHost) wrap_text_track(track &html.TextTrack) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if wrapper := host.text_owner_wrappers[voidptr(track)] { return wrapper }
	wrapper := C.JSObjectMake(host.runtime.context, unsafe { nil }, unsafe { nil })
	C.JSObjectSetPrototype(host.runtime.context, wrapper, host.text_track_prototype)
	host.runtime.bind_event_target(wrapper, &track.EventTarget)!
	host.text_tracks[wrapper] = track
	host.text_owner_wrappers[voidptr(track)] = wrapper
	return wrapper
}

fn (mut host MediaElementHost) text_track_operation(name string, receiver voidptr, args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	context := host.runtime.context
	if name in ['textTracks', 'addTextTrack'] {
		media := host.media_element_for_binding(receiver)!
		if name == 'addTextTrack' { return host.add_text_track(media, args) }
		if replay := host.replay { replay(host.runtime)! }
		return host.wrap_text_track_list(media.text_tracks())
	}
	if name in ['length', 'getTrackById', 'onchange', 'setOnchange', 'onaddtrack', 'setOnaddtrack', 'onremovetrack', 'setOnremovetrack'] {
		list := host.text_lists[receiver] or { return error('TypeError: Not an object of type TextTrackList') }
		if name == 'length' { return C.JSValueMakeNumber(context, f64(list.length())) }
		if name == 'getTrackById' {
			if args.len == 0 { return error('TypeError: getTrackById requires at least 1 argument') }
			id := host.runtime.binding_dom_utf16(args[0])!.str()
			track := list.get_track_by_id(id) or { return C.JSValueMakeNull(context) }
			return host.wrap_text_track(track)
		}
		if name.starts_with('setOn') {
			mut value := C.JSValueMakeUndefined(context)
			if args.len > 0 { value = args[0] }
			host.runtime.set_javascript_event_handler(&list.EventTarget, name[5..].to_lower(), value)!
			return C.JSValueMakeUndefined(context)
		}
		return host.runtime.javascript_event_handler(&list.EventTarget, name[2..])
	}
	mut track := host.text_tracks[receiver] or { return error('TypeError: Not an object of type TextTrack') }
	if name == 'setMode' {
		mut value := C.JSValueMakeUndefined(context)
		if args.len > 0 { value = args[0] }
		// Source's generated enum attribute setter ignores conversion errors.
		converted := host.runtime.binding_dom_utf16(value) or {
			if err is JavaScriptValueException { host.runtime.release_javascript_value(err.value) }
			return C.JSValueMakeUndefined(context)
		}
		mode := match converted.str() {
			'disabled' { html.TextTrackMode.disabled }
			'hidden' { html.TextTrackMode.hidden }
			'showing' { html.TextTrackMode.showing }
			else { return C.JSValueMakeUndefined(context) }
		}
		track.set_mode(mode)
		return C.JSValueMakeUndefined(context)
	}
	if name == 'oncuechange' { return host.runtime.javascript_event_handler(&track.EventTarget, 'cuechange') }
	if name == 'setOncuechange' {
		mut value := C.JSValueMakeUndefined(context)
		if args.len > 0 { value = args[0] }
		host.runtime.set_javascript_event_handler(&track.EventTarget, 'cuechange', value)!
		return C.JSValueMakeUndefined(context)
	}
	if name == 'kind' { return host.runtime.binding_string(track.kind().str()) }
	if name == 'mode' { return host.runtime.binding_string(track.mode().str()) }
	value := match name { 'id' { track.id() } 'label' { track.label() } else { track.language() } }
	return host.runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(value))
}

fn (mut host MediaElementHost) text_track_list_index(args []voidptr) !voidptr {
	if host.closed { return error('TypeError: Media element binding is closed') }
	if args.len == 1 {
		key := libjs.PropertyName.from_utf16(host.runtime.native_utf16_string(args[0])!)
		if !key.is_number() { return C.JSValueMakeUndefined(host.runtime.context) }
		return C.JSValueMakeNumber(host.runtime.context, f64(key.number))
	}
	list := host.text_lists[args[0]] or { return error('TypeError: Not an object of type TextTrackList') }
	mut exception := unsafe { nil }
	index := u32(C.JSValueToNumber(host.runtime.context, args[1], &exception))
	if exception != unsafe { nil } { return host.runtime.actual_javascript_exception(exception) }
	track := list.item(int(index)) or { return C.JSValueMakeUndefined(host.runtime.context) }
	return host.wrap_text_track(track)
}

fn (mut host MediaElementHost) add_text_track(media &html.HTMLMediaElement, args []voidptr) !voidptr {
	if args.len == 0 { return error('TypeError: addTextTrack requires at least 1 argument') }
	converted := host.runtime.binding_dom_utf16(args[0])!.str()
	kind := match converted {
		'subtitles' { html.TextTrackKind.subtitles }
		'captions' { html.TextTrackKind.captions }
		'descriptions' { html.TextTrackKind.descriptions }
		'chapters' { html.TextTrackKind.chapters }
		'metadata' { html.TextTrackKind.metadata }
		else { return error('TypeError: Invalid TextTrackKind') }
	}
	mut label := ''
	mut language := ''
	if args.len > 1 && !C.JSValueIsUndefined(host.runtime.context, args[1]) {
		label = host.runtime.binding_dom_utf16(args[1])!.str()
	}
	if args.len > 2 && !C.JSValueIsUndefined(host.runtime.context, args[2]) {
		language = host.runtime.binding_dom_utf16(args[2])!.str()
	}
	if replay := host.replay { replay(host.runtime)! }
	mut actual := unsafe { &html.HTMLMediaElement(media) }
	return host.wrap_text_track(actual.add_text_track(kind, label, language))
}
