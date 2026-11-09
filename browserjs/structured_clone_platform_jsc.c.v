// HTML/StructuredSerialize.cpp steps 19/20 use actual native Wrappable
// identity, not prototype chains, author-visible tags or enumerable fields.
@[has_globals]
module browserjs


__global native_clone_font_face_hosts_ = map[voidptr]&FontFaceHost{}

fn (mut runtime Runtime) register_native_clone_font_face_host(host &FontFaceHost) ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if previous := native_clone_font_face_hosts_[owner] {
		if voidptr(previous) == voidptr(host) { return }
		return error('Native FontFace clone identity already belongs to another installed host')
	}
	register_runtime_binding(mut native_clone_font_face_hosts_, owner, host)
	runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut native_clone_font_face_hosts_, owner) })
}

fn (runtime &Runtime) native_clone_font_face_host() ?&FontFaceHost {
	return native_clone_font_face_hosts_[voidptr(runtime)] or { return none }
}

fn (runtime &Runtime) require_native_clone_non_platform(value voidptr) ! {
	owner := voidptr(runtime)
	// This cache contains only genuine source-backed platform wrappers:
	// Streams/controllers/readers, strategies and AbortController/Signal.
	if _ := runtime.native_stream_wrapper_records_[value] {
		return native_clone_unsupported('Cannot serialize platform objects')
	}
	if binding := event_target_bindings_[owner] {
		if _ := binding.targets[value] {
			return native_clone_unsupported('Cannot serialize platform objects')
		}
		if _ := binding.events[value] {
			return native_clone_unsupported('Cannot serialize platform objects')
		}
	}
	if binding := message_channel_bindings_[owner] {
		if _ := binding.channels[value] {
			return native_clone_unsupported('Cannot serialize platform objects')
		}
	}
	if host := runtime.native_clone_font_face_host() {
		if _ := host.faces[value] {
			return native_clone_unsupported('Cannot serialize platform objects')
		}
	}
	if host := crypto_bindings_[owner] {
		if _ := host.by_wrapper[value] {
			return native_clone_unsupported('Cannot serialize platform objects')
		}
	}
}
