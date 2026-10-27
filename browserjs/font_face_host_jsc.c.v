module browserjs

import css
import html
import webidl
import dom
import highresolutiontime


fn C.JSObjectGetTypedArrayBuffer(context voidptr, object voidptr, exception &voidptr) voidptr
fn C.JSObjectGetArrayBufferBytesPtr(context voidptr, object voidptr, exception &voidptr) voidptr
fn C.JSObjectGetTypedArrayByteLength(context voidptr, object voidptr, exception &voidptr) uint
fn C.JSObjectGetTypedArrayByteOffset(context voidptr, object voidptr, exception &voidptr) uint
fn C.JSValueMakeBoolean(context voidptr, value bool) voidptr

pub fn (mut host FontFaceHost) install(mut runtime Runtime) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
	if settings == unsafe { nil } {
		return error('FontFace binding requires its actual relevant settings object')
	}
	runtime.bind_scripting_environment(settings)!
	runtime.install_dom_exception_binding()!
	runtime.install_event_target_binding()!
	owner := voidptr(&runtime)
	runtime.define_value_host_function('__ladybirdFontFace', fn [mut host, owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if host.closed { return error('FontFace global has closed') }
		if args.len < 2 { return error('Missing internal FontFace binding arguments') }
		method := runtime.binding_dom_string(args[0])!
		return host.call(mut runtime, method, args[1], args[2..])
	})!
	runtime.evaluate_host(font_face_bootstrap())!
	host.face_factory = runtime.evaluate_host_value('__ladybirdFontFaceFactory')!
	host.set_wrapper = runtime.evaluate_host_value('__ladybirdFontFaceSetWrapper')!
	host.set_cache = runtime.evaluate_host_value('__ladybirdFontFaceSetCache')!
	host.buffer_source_view = runtime.evaluate_host_value('__ladybirdFontBufferSource')!
	host.font_event_factory = runtime.evaluate_host_value('__ladybirdFontLoadEventFactory')!
	host.font_event_sequence = runtime.evaluate_host_value('__ladybirdFontLoadEventSequence')!
	host.font_event_freeze = runtime.evaluate_host_value('__ladybirdFontLoadEventFreeze')!
	runtime.bind_event_target(host.set_wrapper, unsafe { &dom.EventTarget(host.set) })!
	handle := voidptr(&host)
	runtime.register_native_clone_font_face_host(&host)!
	runtime.install_event_wrapper_provider(EventWrapperProvider{
		owner: handle
		create: fn [handle, owner] (event &dom.Event) !voidptr {
			if event.interface_ != .font_face_set_load_event { return unsafe { nil } }
			mut host := unsafe { &FontFaceHost(handle) }
			mut runtime := unsafe { &Runtime(owner) }
			if host.closed { return unsafe { nil } }
			return host.wrap_font_event(mut runtime, unsafe { &css.FontFaceSetLoadEvent(event) })
		}
	})!
	host.set.install_setlike_binding_hooks(css.FontFaceSetBindingHooks{
		owner:       handle
		did_add:     fn [handle, owner] (face &css.FontFaceObject) {
			mut host := unsafe { &FontFaceHost(handle) }
			mut runtime := unsafe { &Runtime(owner) }
			if host.closed { return }
			wrapper := host.wrap_face(mut runtime, face) or { return }
			runtime.call_javascript_function(host.set_cache,
				C.JSValueMakeUndefined(runtime.context), [runtime.binding_string('add'),
				wrapper]) or {}
		}
		did_remove:  fn [handle, owner] (face &css.FontFaceObject) {
			mut host := unsafe { &FontFaceHost(handle) }
			runtime := unsafe { &Runtime(owner) }
			if host.closed { return }
			wrapper := host.wrappers[voidptr(face)] or { return }
			runtime.call_javascript_function(host.set_cache,
				C.JSValueMakeUndefined(runtime.context), [runtime.binding_string('delete'),
				wrapper]) or {}
		}
		did_reorder: fn [handle, owner] () {
			mut host := unsafe { &FontFaceHost(handle) }
			mut runtime := unsafe { &Runtime(owner) }
			if host.closed { return }
			runtime.call_javascript_function(host.set_cache,
				C.JSValueMakeUndefined(runtime.context), [runtime.binding_string('clear')]) or {}
			for face in host.set.set_entries() {
				wrapper := host.wrap_face(mut runtime, face) or { continue }
				runtime.call_javascript_function(host.set_cache,
					C.JSValueMakeUndefined(runtime.context), [
					runtime.binding_string('add'),
					wrapper,
				]) or {}
			}
		}
	})
	for face in host.set.set_entries() {
		wrapper := host.wrap_face(mut runtime, face)!
		runtime.call_javascript_function(host.set_cache, C.JSValueMakeUndefined(runtime.context), [
			runtime.binding_string('add'),
			wrapper,
		])!
	}
	runtime.add_close_handler(fn [handle] () {
		mut host := unsafe { &FontFaceHost(handle) }
		host.closed = true
		host.set.clear_setlike_binding_hooks(handle)
		host.faces = {}
		host.wrappers = {}
		host.font_events = {}
		host.font_event_faces = {}
	})
}

fn (mut host FontFaceHost) cache_font_event(mut runtime Runtime, wrapper voidptr, event &css.FontFaceSetLoadEvent) ! {
	runtime.bind_event(wrapper, event.base_event())!
	host.font_events[wrapper] = event
	mut faces := []voidptr{cap: event.fontfaces().len}
	for face in event.fontfaces() { faces << host.wrap_face(mut runtime, unsafe { &css.FontFaceObject(face) })! }
	mut exception := unsafe { nil }
	array := C.JSObjectMakeArray(runtime.context, uint(faces.len), faces.data, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	frozen := runtime.call_javascript_function(host.font_event_freeze, C.JSValueMakeUndefined(runtime.context), [array])!
	runtime.retain_javascript_value(frozen)!
	host.font_event_faces[wrapper] = frozen
}

fn (mut host FontFaceHost) wrap_font_event(mut runtime Runtime, event &css.FontFaceSetLoadEvent) !voidptr {
	binding := runtime.event_binding()!
	if wrapper := binding.event_wrappers[voidptr(event.base_event())] { return wrapper }
	wrapper := runtime.call_javascript_function(host.font_event_factory, C.JSValueMakeUndefined(runtime.context), [])!
	host.cache_font_event(mut runtime, wrapper, event)!
	return wrapper
}

fn (mut host FontFaceHost) wrap_face(mut runtime Runtime, face &css.FontFaceObject) !voidptr {
	if wrapper := host.wrappers[voidptr(face)] { return wrapper }
	wrapper := runtime.call_javascript_function(host.face_factory,
		C.JSValueMakeUndefined(runtime.context), [])!
	runtime.retain_javascript_value(wrapper)!
	host.faces[wrapper] = face
	host.wrappers[voidptr(face)] = wrapper
	return wrapper
}

fn (mut host FontFaceHost) convert(mut runtime Runtime, value webidl.Value) !voidptr {
	if value.kind == .runtime_value { return runtime.actual_webidl_value(value) }
	if value.kind == .undefined { return C.JSValueMakeUndefined(runtime.context) }
	if value.dom_exception_ != none { return runtime.javascript_dom_exception(value) }
	if value.kind == .platform_object {
		if 'FontFaceSet' in value.platform_interfaces && value.opaque_id == u64(voidptr(host.set)) {
			return host.set_wrapper
		}
		if wrapper := host.wrappers[voidptr(value.opaque_id)] { return wrapper }
		for face in host.set.set_entries() {
			if u64(voidptr(face)) == value.opaque_id { return host.wrap_face(mut runtime, face) }
		}
	}
	if value.kind == .sequence {
		mut values := []voidptr{cap: value.sequence_value.len}
		for item in value.sequence_value {
			values << host.convert(mut runtime, item)!
		}
		mut exception := unsafe { nil }
		array := C.JSObjectMakeArray(runtime.context, uint(values.len), values.data, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		return array
	}
	return error('Unexpected FontFace IDL result')
}

fn (mut host FontFaceHost) promise(mut runtime Runtime, promise &webidl.Promise) !voidptr {
	handle := voidptr(&host)
	owner := voidptr(&runtime)
	return runtime.javascript_webidl_promise(promise, fn [handle, owner] (value webidl.Value) !voidptr {
		mut host := unsafe { &FontFaceHost(handle) }
		mut runtime := unsafe { &Runtime(owner) }
		return host.convert(mut runtime, value)
	})
}

fn (mut host FontFaceHost) call(mut runtime Runtime, method string, receiver voidptr, args []voidptr) !voidptr {
	if method == 'event:faceBrand' {
		if _ := host.faces[args[0]] { return C.JSValueMakeUndefined(runtime.context) }
		return runtime.event_binding_type_error('fontfaces entry is not a FontFace')
	}
	if method == 'event:faces' {
		return host.font_event_faces[receiver] or { return runtime.event_binding_type_error('Illegal FontFaceSetLoadEvent receiver') }
	}
	if method == 'event:construct' {
		type_ := runtime.binding_dom_string(args[0])!
		mut init := css.FontFaceSetLoadEventInit{
			EventInit: dom.EventInit{
				bubbles: runtime.event_binding_bool_property(args[1], 'bubbles', false)!
				cancelable: runtime.event_binding_bool_property(args[1], 'cancelable', false)!
				composed: runtime.event_binding_bool_property(args[1], 'composed', false)!
			}
		}
		if C.JSValueIsObject(runtime.context, args[1]) {
			value := runtime.binding_property(args[1], 'fontfaces')!
			array := runtime.call_javascript_function(host.font_event_sequence, C.JSValueMakeUndefined(runtime.context), [value])!
			runtime.retain_javascript_value(array)!
			defer { runtime.release_javascript_value(array) }
			length := runtime.binding_property(array, 'length')!
			mut exception := unsafe { nil }
			count := int(C.JSValueToNumber(runtime.context, length, &exception))
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			for index in 0 .. count {
				face_wrapper := runtime.binding_property(array, index.str())!
				face := host.faces[face_wrapper] or { return runtime.event_binding_type_error('fontfaces entry is not a FontFace') }
				init.fontfaces << face
			}
		}
		settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
		time_stamp := highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
			time_origin: settings.time_origin()
			cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
		})
		event := css.FontFaceSetLoadEvent.create_with_time_stamp(type_, init, time_stamp)
		host.cache_font_event(mut runtime, receiver, event)!
		return C.JSValueMakeUndefined(runtime.context)
	}
	if method == 'construct' {
		family := runtime.binding_dom_string(args[0])!
		view := runtime.call_javascript_function(host.buffer_source_view,
			C.JSValueMakeUndefined(runtime.context), [args[1]])!
		mut source := css.FontFaceSource{}
		if C.JSValueIsNull(runtime.context, view) {
			source = css.FontFaceSource.from_string(runtime.binding_dom_string(args[1])!)
		} else {
			mut exception := unsafe { nil }
			length := C.JSObjectGetTypedArrayByteLength(runtime.context, view, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			offset := C.JSObjectGetTypedArrayByteOffset(runtime.context, view, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			buffer := C.JSObjectGetTypedArrayBuffer(runtime.context, view, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			// Copy immediately after acquiring the temporary backing-store pointer.
			pointer := C.JSObjectGetArrayBufferBytesPtr(runtime.context, buffer, &exception)
			if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
			data := if length == 0 {
				[]u8{}
			} else {
				unsafe { (&u8(pointer) + int(offset)).vbytes(int(length)).clone() }
			}
			source = css.FontFaceSource.from_binary(data)
		}
		mut descriptors := css.FontFaceDescriptors{}
		if args.len > 2 && !C.JSValueIsUndefined(runtime.context, args[2])
			&& !C.JSValueIsNull(runtime.context, args[2]) {
			if !C.JSValueIsObject(runtime.context, args[2]) {
				return runtime.actual_javascript_exception(runtime.binding_exception_value(error('TypeError: FontFaceDescriptors must be a dictionary')))
			}
			mut values := map[string]string{}
			// WebIDL dictionary members are converted in lexicographic order.
			for name in ['ascentOverride', 'descentOverride', 'display', 'featureSettings',
				'lineGapOverride', 'stretch', 'style', 'unicodeRange', 'variationSettings', 'weight'] {
				value := runtime.binding_property(args[2], name)!
				if !C.JSValueIsUndefined(runtime.context, value) {
					values[name] = runtime.binding_dom_string(value)!
				}
			}
			descriptors = css.FontFaceDescriptors{
				ascent_override:    values['ascentOverride'] or { 'normal' }
				descent_override:   values['descentOverride'] or { 'normal' }
				display:            values['display'] or { 'auto' }
				feature_settings:   values['featureSettings'] or { 'normal' }
				line_gap_override:  values['lineGapOverride'] or { 'normal' }
				stretch:            values['stretch'] or { 'normal' }
				style:              values['style'] or { 'normal' }
				unicode_range:      values['unicodeRange'] or { 'U+0-10FFFF' }
				variation_settings: values['variationSettings'] or { 'normal' }
				weight:             values['weight'] or { 'normal' }
			}
		}
		face := css.FontFaceObject.construct_impl_for_font_computer(host.computer, family, source,
			descriptors)
		host.faces[receiver] = face
		host.wrappers[voidptr(face)] = receiver
		runtime.retain_javascript_value(receiver)!
		return C.JSValueMakeUndefined(runtime.context)
	}
	if method.starts_with('set:') {
		if receiver != host.set_wrapper {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(error('TypeError: Illegal FontFaceSet receiver')))
		}
		mut set := host.set
		operation := method[4..]
		if operation == 'handler:get' {
			return runtime.javascript_event_handler(unsafe { &dom.EventTarget(set) }, runtime.binding_dom_string(args[0])!)
		}
		if operation == 'handler:set' {
			runtime.set_javascript_event_handler(unsafe { &dom.EventTarget(set) }, runtime.binding_dom_string(args[0])!, args[1])!
			return C.JSValueMakeUndefined(runtime.context)
		}
		if operation == 'ready' { return host.promise(mut runtime, set.ready()) }
		if operation == 'status' { return runtime.binding_string(set.status().str()) }
		if operation == 'size' { return C.JSValueMakeNumber(runtime.context, set.set_entries().len) }
		if operation == 'brand' { return C.JSValueMakeUndefined(runtime.context) }
		if operation in ['add', 'delete', 'has'] {
			face := host.faces[args[0]] or {
				return runtime.actual_javascript_exception(runtime.binding_exception_value(error('TypeError: Argument is not a FontFace')))
			}
			if operation == 'add' {
				set.add(face) or { return host.binding_exception(mut runtime, err) }
				return host.set_wrapper
			}
			if operation == 'delete' {
				return C.JSValueMakeBoolean(runtime.context, set.delete_(face))
			}
			return C.JSValueMakeBoolean(runtime.context,
				set.set_entries().any(voidptr(it) == voidptr(face)))
		}
		if operation == 'clear' {
			set.clear()
			return C.JSValueMakeUndefined(runtime.context)
		}
		font := runtime.binding_dom_string(args[0])!
		text := if args.len > 1 && !C.JSValueIsUndefined(runtime.context, args[1]) {
			runtime.binding_dom_string(args[1])!
		} else {
			' '
		}
		if operation == 'load' { return host.promise(mut runtime, set.load(font, text) or {
				return host.binding_exception(mut runtime, err)}) }
		if operation == 'check' { return C.JSValueMakeBoolean(runtime.context, set.check(font, text) or {
				return host.binding_exception(mut runtime, err)}) }
		return error('Unknown FontFaceSet binding operation')
	}
	mut face := host.faces[receiver] or {
		return runtime.actual_javascript_exception(runtime.binding_exception_value(error('TypeError: Illegal FontFace receiver')))
	}
	if method == 'load' { return host.promise(mut runtime, face.load()) }
	property := runtime.binding_dom_string(args[0])!
	if method == 'get' {
		if property == 'loaded' { return host.promise(mut runtime, face.loaded()) }
		return runtime.binding_string(match property {
			'family' { face.family() }
			'style' { face.style() }
			'weight' { face.weight() }
			'stretch' { face.stretch() }
			'unicodeRange' { face.unicode_range() }
			'featureSettings' { face.feature_settings() }
			'variationSettings' { face.variation_settings() }
			'display' { face.display() }
			'ascentOverride' { face.ascent_override() }
			'descentOverride' { face.descent_override() }
			'lineGapOverride' { face.line_gap_override() }
			'status' { face.status().str() }
			else { return error('Unknown FontFace attribute') }
		})
	}
	value := runtime.binding_dom_string(args[1])!
	match property {
		'family' {
			face.set_family(value) or { return host.binding_exception(mut runtime, err) }
		}
		'style' {
			face.set_style(value) or { return host.binding_exception(mut runtime, err) }
		}
		'weight' {
			face.set_weight(value) or { return host.binding_exception(mut runtime, err) }
		}
		'stretch' {
			face.set_stretch(value) or { return host.binding_exception(mut runtime, err) }
		}
		'unicodeRange' {
			face.set_unicode_range(value) or { return host.binding_exception(mut runtime, err) }
		}
		'featureSettings' {
			face.set_feature_settings(value) or { return host.binding_exception(mut runtime, err) }
		}
		'variationSettings' {
			face.set_variation_settings(value) or {
				return host.binding_exception(mut runtime, err)
			}
		}
		'display' {
			face.set_display(value) or { return host.binding_exception(mut runtime, err) }
		}
		'ascentOverride' {
			face.set_ascent_override(value) or { return host.binding_exception(mut runtime, err) }
		}
		'descentOverride' {
			face.set_descent_override(value) or { return host.binding_exception(mut runtime, err) }
		}
		'lineGapOverride' {
			face.set_line_gap_override(value) or { return host.binding_exception(mut runtime, err) }
		}
		else {
			return error('Unknown FontFace descriptor')
		}
	}

	return C.JSValueMakeUndefined(runtime.context)
}

fn (mut host FontFaceHost) binding_exception(mut runtime Runtime, reason IError) IError {
	message := reason.msg()
	separator := message.index(':') or { return reason }
	native := webidl.dom_exception_value(webidl.DOMException.create(message[..separator], message[
		separator + 1..].trim_left(' ')))
	wrapper := runtime.javascript_dom_exception(native) or { return err }
	return runtime.actual_javascript_exception(wrapper)
}
