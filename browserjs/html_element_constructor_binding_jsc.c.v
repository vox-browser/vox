@[has_globals]
module browserjs

import dom
import html
import platform
import webidl

fn C.JSValueIsStrictEqual(context voidptr, a voidptr, b voidptr) bool

pub type HTMLElementWrapper = fn (&dom.Element) !voidptr
pub type HTMLElementConstructionReplay = fn () !

@[heap]
struct HTMLElementConstructorBinding {
	runtime &Runtime
	document &dom.Document
	wrap HTMLElementWrapper
	replay HTMLElementConstructionReplay
mut:
	construct voidptr
	set_prototype voidptr
	active_registries map[u64]voidptr
}

__global html_element_constructor_bindings_ = map[voidptr]&HTMLElementConstructorBinding{}

// Install before the compact interface constructors are created. The callback
// is captured by that bootstrap, then removed from the author-visible global.
pub fn (mut runtime Runtime) install_html_element_constructor_binding(wrap HTMLElementWrapper, replay HTMLElementConstructionReplay) ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in html_element_constructor_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('HTMLConstructor requires Window settings') }
	document := settings.responsible_document() or { return error('HTMLConstructor requires a Document') }
	mut binding := &HTMLElementConstructorBinding{ runtime: &runtime, document: document, wrap: wrap, replay: replay }
	// Compact element facades carry DOM members as own properties. Members the
	// author's class chain defines, between its prototype and the interface
	// prototype, must win over them, as they do over interface members.
	helpers := runtime.evaluate_host_value(r'(function(){const construct=Reflect.construct,set=Object.setPrototypeOf,get=Object.getPrototypeOf,keys=Reflect.ownKeys,own=Object.getOwnPropertyDescriptor,remove=Reflect.deleteProperty,base=Object.prototype;return [C=>construct(C,[]),(element,C,fallback)=>{const p=C.prototype,prototype=p!==null&&(typeof p==="object"||typeof p==="function")?p:fallback;set(element,prototype);for(let current=prototype;current!==null&&current!==fallback&&current!==base;current=get(current))for(const key of keys(current)){if(key==="constructor")continue;const member=own(element,key);if(member&&member.configurable)remove(element,key)}return element}]})()')!
	defer { runtime.release_javascript_value(helpers) }
	binding.construct = runtime.retain_javascript_value(runtime.binding_property(helpers, '0')!)!
	binding.set_prototype = runtime.retain_javascript_value(runtime.binding_property(helpers, '1')!)!
	runtime.define_value_host_function('__ladybirdHTMLConstructor', fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut storage := binding.document.native_storage()
		mut scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { scope = storage.enter_nested() }
		defer { scope.finish() }
		return runtime.construct_html_element(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.html_constructor_exception(err))
		}
	})!
	html_element_constructor_bindings_[owner] = binding
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_custom_element_construction_hook(dom.CustomElementConstructionHook{
		target: owner
		construct: construct_javascript_custom_element
		report: report_javascript_custom_element_exception
		upgrade: upgrade_javascript_custom_element
		invoke: invoke_javascript_custom_element_callback
	})
	runtime.add_close_handler(fn [owner, document] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.clear_custom_element_construction_hook(owner)
		html_element_constructor_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) html_constructor_exception(exception IError) voidptr {
	if exception is JavaScriptValueException { return exception.value }
	if exception.msg().starts_with('NotSupportedError:') {
		return runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create('NotSupportedError', exception.msg()))) or {
			return runtime.binding_exception_value(err)
		}
	}
	return runtime.binding_exception_value(exception)
}

fn report_javascript_custom_element_exception(owner voidptr, exception IError) {
	mut runtime := unsafe { &Runtime(owner) }
	value := runtime.html_constructor_exception(exception)
	runtime.report_event_callback_exception(runtime.actual_javascript_exception(value))
}

fn custom_element_constructor_value(owner voidptr, definition &dom.CustomElementDefinition, registry_handle voidptr) !voidptr {
	registry_binding := custom_element_registry_bindings_[owner] or { return error('TypeError: Custom element registry is not installed') }
	for _, registry in registry_binding.registries {
		if voidptr(registry.native) == registry_handle {
			return registry.constructors[definition.constructor()] or { return error('TypeError: Custom element constructor belongs to another realm') }
		}
	}
	return error('TypeError: Custom element registry belongs to another realm')
}

fn construct_javascript_custom_element(owner voidptr, definition &dom.CustomElementDefinition, registry_handle voidptr) !&dom.Element {
	mut runtime := unsafe { &Runtime(owner) }
	mut construction := html_element_constructor_bindings_[owner] or { return error('HTMLConstructor binding is closed') }
	constructor := custom_element_constructor_value(owner, definition, registry_handle)!
	construction.active_registries[definition.constructor()] = registry_handle
	defer { construction.active_registries.delete(definition.constructor()) }
	result := runtime.call_javascript_function(construction.construct, C.vox_jsc_JSValueMakeUndefined(runtime.context), [constructor])!
	runtime.retain_javascript_value(result)!
	defer { runtime.release_javascript_value(result) }
	// Compact writes must reach their native owners before the DOM factory's
	// post-construction attribute/child/document checks.
	construction.replay()!
	target := runtime.native_event_target(result)!
	if target.data.kind != .node || !unsafe { &dom.Node(target) }.is_element() {
		return runtime.event_binding_type_error('Custom element constructor must return an HTMLElement')
	}
	return unsafe { &dom.Element(target) }
}

// Upgrade steps 7-9.4. The element's existing wrapper is on the definition's
// construction stack, so HTMLConstructor returns it with C's prototype.
fn upgrade_javascript_custom_element(owner voidptr, element &dom.Element, definition &dom.CustomElementDefinition) ! {
	mut runtime := unsafe { &Runtime(owner) }
	mut construction := html_element_constructor_bindings_[owner] or { return error('HTMLConstructor binding is closed') }
	registry_handle := element.custom_element_registry()
	constructor := custom_element_constructor_value(owner, definition, registry_handle)!
	wrapper := runtime.retain_javascript_value(construction.wrap(element)!)!
	defer { runtime.release_javascript_value(wrapper) }
	construction.active_registries[definition.constructor()] = registry_handle
	defer { construction.active_registries.delete(definition.constructor()) }
	result := runtime.call_javascript_function(construction.construct, C.vox_jsc_JSValueMakeUndefined(runtime.context), [constructor])!
	runtime.mark_document_state_dirty()
	if !C.JSValueIsStrictEqual(runtime.context, result, wrapper) {
		return runtime.event_binding_type_error('Custom element constructor returned a different element than the one being upgraded')
	}
}

fn invoke_javascript_custom_element_callback(owner voidptr, element &dom.Element, reaction dom.CustomElementCallbackReaction) ! {
	mut runtime := unsafe { &Runtime(owner) }
	construction := html_element_constructor_bindings_[owner] or { return }
	registry_binding := custom_element_registry_bindings_[owner] or { return }
	definition := element.custom_element_definition() or { return }
	callback := registry_binding.lifecycle_callback(element.custom_element_registry(), definition.constructor(), reaction.callback_name) or { return }
	receiver := runtime.retain_javascript_value(construction.wrap(element)!)!
	defer { runtime.release_javascript_value(receiver) }
	mut arguments := []voidptr{}
	if change := reaction.attribute {
		null := C.vox_jsc_JSValueMakeNull(runtime.context)
		arguments << runtime.binding_string(change.name)
		arguments << if value := change.old_value { runtime.binding_string(value) } else { null }
		arguments << if value := change.new_value { runtime.binding_string(value) } else { null }
		arguments << if value := change.namespace_ { runtime.binding_string(value) } else { null }
	} else if reaction.old_document != unsafe { nil } && reaction.new_document != unsafe { nil } {
		arguments << runtime.javascript_event_target(unsafe { &dom.EventTarget(reaction.old_document) }, none)!
		arguments << runtime.javascript_event_target(unsafe { &dom.EventTarget(reaction.new_document) }, none)!
	} else {
		for argument in reaction.arguments { arguments << runtime.binding_string(argument) }
	}
	defer { runtime.mark_document_state_dirty() }
	runtime.call_javascript_function(callback, receiver, arguments)!
}

fn (mut runtime Runtime) construct_html_element(mut construction HTMLElementConstructorBinding, args []voidptr) !voidptr {
	if args.len != 3 { return runtime.event_binding_type_error('Invalid HTMLConstructor invocation') }
	binding := custom_element_registry_bindings_[voidptr(&runtime)] or { return runtime.event_binding_type_error('No custom element definition is installed') }
	id := binding.constructor_ids[args[0]] or { return runtime.event_binding_type_error('No custom element definition is assigned to this constructor') }
	mut registry_handle := binding.window.associated_document().custom_element_registry()
	if active := construction.active_registries[id] {
		registry_handle = active
		construction.active_registries.delete(id)
	}
	if registry_handle == unsafe { nil } { return runtime.event_binding_type_error('No custom element registry') }
	registry := unsafe { &html.CustomElementRegistry(registry_handle) }
	definition := registry.get_definition_from_new_target(id) or { return runtime.event_binding_type_error('No custom element definition is assigned to this constructor') }
	interface_name := runtime.binding_dom_string(args[1])!
	if dom.html_constructor_is_upgrading(definition) {
		// 10-14. Return the element being upgraded with its prototype set.
		upgrading := dom.take_html_constructor_upgrade_element(definition, interface_name)!
		existing := construction.wrap(upgrading)!
		return runtime.call_javascript_function(construction.set_prototype, C.vox_jsc_JSValueMakeUndefined(runtime.context), [existing, args[0], args[2]])
	}
	element := dom.create_element_for_html_constructor(construction.document, definition, registry_handle, interface_name)!
	wrapper := construction.wrap(element)!
	return runtime.call_javascript_function(construction.set_prototype, C.vox_jsc_JSValueMakeUndefined(runtime.context), [wrapper, args[0], args[2]])
}
