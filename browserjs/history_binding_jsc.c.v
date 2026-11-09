@[has_globals]
module browserjs

import html
import platform
import webidl

@[heap]
struct HistoryBinding {
	window &html.WindowModel
	clone  &StructuredCloneBridge
mut:
	state          voidptr
	state_revision u64
	state_entry    voidptr
}

__global history_bindings_ = map[voidptr]&HistoryBinding{}

pub fn (mut runtime Runtime) install_history_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in history_bindings_ { return }
	runtime.install_window_event_handler_binding()!
	runtime.install_dom_exception_binding()!
	settings := runtime.scripting_settings_ or { return error('History requires owning Window settings') }
	target := settings.global_object()
	if target.data.kind != .window { return error('History requires an actual Window') }
	mut binding := &HistoryBinding{
		window: unsafe { &html.WindowModel(target) }
		clone:  StructuredCloneBridge.create(&runtime)!
	}
	// The compact host activates its document before installing the script
	// realm. Seed Navigation's view before History can replace that entry.
	model := binding.window.navigable_model()
	if entry := model.active_session_history_entry() {
		mut navigation := unsafe { &html.Navigation(binding.window.navigation()) }
		navigation.initialize_the_navigation_api_entries_for_a_new_document(model.get_session_history_entries(), entry)
	}
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut storage := binding.window.associated_document().native_storage()
		mut allocation_scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
		defer { allocation_scope.finish() }
		return runtime.history_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			value := webidl.exception_value(err)
			if value.dom_exception_ != none {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(value)!)
			}
			if err.msg().starts_with('SecurityError:') {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('SecurityError', err.msg())))!)
			}
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(history_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	runtime.call_javascript_function(factory, global, [operation, global])!
	mut history := binding.window.history()
	history.set_deserialization_context(runtime.native_clone_deserialization_context())
	register_runtime_binding(mut history_bindings_, owner, binding)
	runtime.add_close_handler(fn [owner, mut history] () {
		history.set_deserialization_context(html.StructuredDeserializationContext{})
		unregister_runtime_binding(mut history_bindings_, owner)
	})
}

fn (mut runtime Runtime) history_operation(mut binding HistoryBinding, args []voidptr) !voidptr {
	if args.len == 0 { return error('Missing History operation') }
	method := runtime.binding_dom_string(args[0])!
	if method == 'windowBrand' {
		if args.len < 2 { return runtime.event_binding_type_error('Missing Window receiver') }
		target := runtime.native_event_target(args[1])!
		if voidptr(target) != voidptr(binding.window) {
			return runtime.event_binding_type_error('Illegal Window receiver')
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	mut history := binding.window.history()
	match method {
		'url' { return runtime.binding_string(history.current_url().serialize()) }
		'length' { return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(history.length()!)) }
		'state' {
			state := history.state()!
			document := binding.window.associated_document()
			entry := document.get_latest_entry() or { unsafe { nil } }
			if binding.state == unsafe { nil } || binding.state_revision != history.state_revision() || binding.state_entry != voidptr(entry) {
				mut projection := NativeCloneProjection{ bridge: binding.clone }
				defer { projection.release_roots() }
				actual := projection.reconstruct(state)!
				if binding.state != unsafe { nil } {
					runtime.release_javascript_value(binding.state)
				}
				binding.state = runtime.retain_javascript_value(actual)!
				binding.state_revision = history.state_revision()
				binding.state_entry = voidptr(entry)
			}
			return binding.state
		}
		'scrollRestoration' { return runtime.binding_string(history.scroll_restoration()!.str()) }
		'setScrollRestoration' {
			mode := runtime.binding_dom_string(args[1])!
			history.set_scroll_restoration(if mode == 'manual' { .manual } else { .auto })!
		}
		'pushState', 'replaceState' {
			_ = history.length()!
			if args.len < 4 { return error('Missing History state arguments') }
			// Storage serialization rejects uncloneable engine values before
			// native navigation, retaining cycles, typed arrays and BigInts.
			record := binding.clone.serialize(args[1], true)!
			data := html.structured_deserialize_with_context(record, runtime.native_clone_deserialization_context())!
			unused := runtime.binding_dom_string(args[2])!
			url := if C.JSValueIsNull(runtime.context, args[3]) {
				?string(none)
			} else {
				?string(runtime.binding_dom_string(args[3])!)
			}
			if method == 'pushState' {
				history.push_state(data, unused, url)!
			} else {
				history.replace_state(data, unused, url)!
			}
		}
		else { return error('Unknown History operation') }
	}
	return C.vox_jsc_JSValueMakeUndefined(runtime.context)
}
