@[has_globals]
module browserjs

import dom
import html
import libjs
import platform
import webidl

fn C.JSObjectIsConstructor(context voidptr, object voidptr) bool

@[heap]
struct JavaScriptCustomElementRegistry {
	native &html.CustomElementRegistry
mut:
	constructors map[u64]voidptr
	metadata     map[u64]voidptr
	// Lifecycle callbacks captured by define(), keyed by "id:name"; the
	// retained metadata array keeps each value alive.
	callbacks    map[string]voidptr
	pending      map[string]JavaScriptPromiseCapability
}

@[heap]
struct CustomElementRegistryBinding {
	window &html.WindowModel
mut:
	registries     map[voidptr]&JavaScriptCustomElementRegistry
	constructor_ids map[voidptr]u64
	next_id         u64
	read_metadata   voidptr
}

__global custom_element_registry_bindings_ = map[voidptr]&CustomElementRegistryBinding{}

pub fn (mut runtime Runtime) install_custom_element_registry_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in custom_element_registry_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('CustomElementRegistry requires owning Window settings') }
	target := settings.global_object()
	if target.data.kind != .window { return error('CustomElementRegistry requires an actual Window') }
	runtime.install_window_event_handler_binding()!
	runtime.install_dom_exception_binding()!
	mut binding := &CustomElementRegistryBinding{ window: unsafe { &html.WindowModel(target) } }
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut storage := binding.window.associated_document().native_storage()
		mut scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { scope = storage.enter_nested() }
		defer { scope.finish() }
		return runtime.custom_element_registry_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			for name in ['SyntaxError', 'NotSupportedError'] {
				if err.msg().starts_with(name + ':') {
					return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create(name, err.msg())))!)
				}
			}
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(custom_element_registry_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	binding.read_metadata = runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [operation, global])!)!
	custom_element_registry_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		// Runtime.close releases all actual engine roots, including pending
		// capabilities. Native upgrade queues remain owned by their documents.
		binding.registries = {}
		binding.constructor_ids = {}
		custom_element_registry_bindings_.delete(owner)
	})
}

fn (binding &CustomElementRegistryBinding) lifecycle_callback(registry_handle voidptr, id u64, name string) ?voidptr {
	for _, registry in binding.registries {
		if voidptr(registry.native) != registry_handle { continue }
		return registry.callbacks['${id}:${name}'] or { return none }
	}
	return none
}

// The metadata factory returns [names, observed, disabled, form, prototype,
// callbacks]; names and callbacks are parallel arrays.
fn (mut runtime Runtime) capture_custom_element_callbacks(mut registry JavaScriptCustomElementRegistry, id u64, metadata voidptr) ! {
	mut exception := voidptr(0)
	names_value := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, metadata, 0, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	values := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, metadata, 5, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	names := runtime.custom_element_metadata_strings(names_value)!
	for index, name in names {
		callback := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, values, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		registry.callbacks['${id}:${name}'] = callback
	}
}

fn (mut runtime Runtime) custom_element_metadata_strings(value voidptr) ![]string {
	mut exception := voidptr(0)
	length := int(C.vox_jsc_JSValueToNumber(runtime.context, runtime.binding_property(value, 'length')!, &exception))
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	mut strings := []string{cap: length}
	for index in 0 .. length {
		exception = unsafe { nil }
		item := C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, value, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		strings << (runtime.binding_dom_utf16(item)!).str()
	}
	return strings
}

fn (mut runtime Runtime) custom_element_metadata(value voidptr, id u64) !html.CustomElementConstructor {
	mut parts := []voidptr{cap: 4}
	for index in 0 .. 4 {
		mut exception := voidptr(0)
		parts << C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, value, u32(index), &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	}
	return html.CustomElementConstructor{
		id: id
		lifecycle_callbacks: runtime.custom_element_metadata_strings(parts[0])!
		observed_attributes: runtime.custom_element_metadata_strings(parts[1])!
		disabled_features: runtime.custom_element_metadata_strings(parts[2])!
		form_associated: C.JSValueToBoolean(runtime.context, parts[3])
	}
}

fn (mut runtime Runtime) custom_element_registry_operation(mut binding CustomElementRegistryBinding, args []voidptr) !voidptr {
	if args.len < 2 { return error('Missing CustomElementRegistry operation') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	undefined := C.vox_jsc_JSValueMakeUndefined(runtime.context)
	if method == 'rejected' {
		capability := runtime.create_javascript_promise()!
		defer { runtime.release_javascript_promise(capability) }
		runtime.reject_javascript_promise(capability, args[2])!
		return capability.promise
	}
	if method == 'windowBrand' {
		target := runtime.native_event_target(receiver)!
		if voidptr(target) != voidptr(binding.window) { return runtime.event_binding_type_error('Illegal Window receiver') }
		return undefined
	}
	if method in ['global', 'construct'] {
		native := if method == 'global' { binding.window.custom_elements() } else { html.CustomElementRegistry.construct(binding.window.associated_document()) }
		binding.registries[receiver] = &JavaScriptCustomElementRegistry{ native: native }
		runtime.retain_javascript_value(receiver)!
		return undefined
	}
	mut registry := binding.registries[receiver] or { return runtime.event_binding_type_error('Illegal CustomElementRegistry receiver') }
	mut native := registry.native
	match method {
		'brand' { return undefined }
		'string' { return runtime.binding_utf16_string(runtime.binding_dom_utf16(args[2])!) }
		'callback' {
			if !C.JSValueIsObject(runtime.context, args[2]) || !C.JSObjectIsFunction(runtime.context, args[2]) {
				return runtime.event_binding_type_error('Custom element callback must be callable')
			}
		}
		'get' {
			id := native.get((runtime.binding_dom_utf16(args[2])!).str()) or { return undefined }
			return registry.constructors[id] or { return error('Native constructor has no JavaScript callback in this realm') }
		}
		'getName' {
			id := binding.constructor_ids[args[2]] or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
			name := native.get_name(id) or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
			return runtime.binding_utf16_string(libjs.utf16_string_from_utf8_without_validation(name))
		}
		'define' {
			name := (runtime.binding_dom_utf16(args[2])!).str()
			constructor := args[3]
			id := binding.constructor_ids[constructor] or {
				binding.next_id++
				binding.next_id
			}
			// Reserve identity before author metadata can define this callback in
			// another registry. A failed outer definition must keep an identity
			// published by a successful nested definition, and otherwise release
			// both its reservation and temporary GC root.
			known := constructor in binding.constructor_ids
			binding.constructor_ids[constructor] = id
			runtime.retain_javascript_value(constructor)!
			defer {
				if !known {
					mut published := false
					for _, bound in binding.registries {
						if id in bound.constructors { published = true; break }
					}
					if !published { binding.constructor_ids.delete(constructor) }
				}
				runtime.release_javascript_value(constructor)
			}
			extends := if C.JSValueIsUndefined(runtime.context, args[4]) { ?string(none) } else { ?string((runtime.binding_dom_utf16(args[4])!).str()) }
			owner := voidptr(&runtime)
			// Capture callback values/prototype exactly once under the native
			// definition guard, retaining them even if author properties change.
			mut captured := &CustomElementMetadataCapture{}
			defer { if captured.value != unsafe { nil } { runtime.release_javascript_value(captured.value) } }
			read_metadata := fn [owner, binding, receiver, constructor, id, mut captured] (_ html.CustomElementConstructor) !html.CustomElementConstructor {
				mut runtime := unsafe { &Runtime(owner) }
				captured.value = runtime.retain_javascript_value(runtime.call_javascript_function(binding.read_metadata, C.vox_jsc_JSValueMakeUndefined(runtime.context), [receiver, constructor])!)!
				return runtime.custom_element_metadata(captured.value, id)
			}
			defer { platform.release_closure(voidptr(read_metadata)) }
			native.define_with_metadata(name, html.CustomElementConstructor{
				id: id
				is_constructor: C.JSObjectIsConstructor(runtime.context, constructor)
			}, html.ElementDefinitionOptions{ extends: extends }, read_metadata)!
			registry.constructors[id] = runtime.retain_javascript_value(constructor)!
			registry.metadata[id] = captured.value
			runtime.capture_custom_element_callbacks(mut registry, id, captured.value)!
			captured.value = unsafe { nil }
			binding.constructor_ids[constructor] = id
			if capability := registry.pending[name] {
				registry.pending.delete(name)
				defer { runtime.release_javascript_promise(capability) }
				runtime.resolve_javascript_promise(capability, constructor)!
			}
			// define() is [CEReactions]: upgrade the candidates it queued.
			mut document := unsafe { &dom.Document(binding.window.associated_document()) }
			document.invoke_custom_element_reactions()
		}
		'whenDefined' {
			name := (runtime.binding_dom_utf16(args[2])!).str()
			if !html.is_valid_custom_element_name(name) { return error("SyntaxError: '${name}' is not a valid custom element name") }
			if id := native.get(name) {
				constructor := registry.constructors[id] or { return error('Native constructor has no JavaScript callback in this realm') }
				capability := runtime.create_javascript_promise()!
				defer { runtime.release_javascript_promise(capability) }
				runtime.resolve_javascript_promise(capability, constructor)!
				return capability.promise
			}
			if capability := registry.pending[name] { return capability.promise }
			// Like upstream BindingsGlue, the binding owns the real Promise;
			// definition identity and validation remain in the native registry.
			capability := runtime.create_javascript_promise()!
			registry.pending[name] = capability
			return capability.promise
		}
		'upgrade', 'initialize' {
			target := runtime.native_event_target(args[2])!
			if target.data.kind != .node { return runtime.event_binding_type_error('CustomElementRegistry requires a Node') }
			node := unsafe { &dom.Node(target) }
			if method == 'upgrade' { native.upgrade(node) } else { native.initialize(node)! }
			mut document := unsafe { &dom.Document(binding.window.associated_document()) }
			document.invoke_custom_element_reactions()
		}
		else { return error('Unknown CustomElementRegistry operation') }
	}
	return undefined
}

@[heap]
struct CustomElementMetadataCapture {
mut:
	value voidptr
}
