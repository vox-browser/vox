@[has_globals]
module browserjs

import dom
import html
import platform
import trustedtypes
import webidl

pub type TrustedTypesReplay = fn (&Runtime) !
pub type TrustedTypesAttributeSetter = fn (string, ?string, string, trustedtypes.TrustedTypeOrString, bool, string) !string

@[heap]
struct TrustedTypesPolicyBinding {
	runtime &Runtime
	document &dom.Document
	convert voidptr
	replay TrustedTypesReplay
	set_attribute TrustedTypesAttributeSetter
mut:
	closed bool
	factory voidptr
}

__global trusted_types_policy_bindings_ = map[voidptr]&TrustedTypesPolicyBinding{}

struct TrustedTypesCallbackOption {
	callback ?trustedtypes.PolicyCallback
}

// Policy creation and DOM enforcement must consult the same Window factory.
// The compact interface supplies actual callback values, never serialized IDs.
pub fn (mut runtime Runtime) install_trusted_types_policy_binding(document &dom.Document, replay TrustedTypesReplay, setter TrustedTypesAttributeSetter) ! {
	runtime.require_javascript_value_context()!
	// The native Window factory can retain a policy after its document payload
	// retires. Its callback must still be able to observe the closed guard.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	runtime.own_closure(voidptr(replay))
	runtime.own_closure(voidptr(setter))
	if document.relevant_settings_object() == unsafe { nil } {
		_ := html.WindowModel.create_top_level(document, none, '')!
	}
	converter := runtime.evaluate_host_value('(function(){const S=String,T=TypeError;return function(value){if(typeof value==="symbol")throw new T("Cannot convert a Symbol to a string");return S(value);};})()')!
	binding := &TrustedTypesPolicyBinding{runtime: &runtime, document: document, convert: converter, replay: replay, set_attribute: setter}
	operation := runtime.make_native_value_host_function('', 4, fn [binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(binding.runtime) }
		return binding.create_policy(args) or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	attribute := runtime.make_native_value_host_function('', 7, fn [binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(binding.runtime) }
		return binding.set_trusted_attribute(args) or {
			return runtime.actual_javascript_exception(runtime.trusted_attribute_exception(err))
		}
	})!
	getter := runtime.make_native_value_host_function('get trustedTypes', 0, fn [binding] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(binding.runtime) }
		return runtime.trusted_types_factory_for_receiver(receiver) or {
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	register := runtime.make_native_value_host_function('', 1, fn [binding] (_ voidptr, args []voidptr) !voidptr {
		if binding.closed { return error('InvalidStateError: Trusted Types realm is closed') }
		mut owner := unsafe { &TrustedTypesPolicyBinding(binding) }
		if args.len != 1 || owner.factory != unsafe { nil } { return error('TypeError: Invalid private factory registration') }
		mut runtime := unsafe { &Runtime(binding.runtime) }
		owner.factory = runtime.retain_javascript_value(args[0])!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	trusted_types_policy_bindings_[runtime.context] = binding
	// This bootstrap property is configurable so the compact closure can take
	// ownership and remove it before any author script executes.
	installer := runtime.evaluate_host_value('(function(operation,attribute,getter,register){Object.defineProperty(globalThis,"__ladybirdCreateTrustedTypePolicy",{value:operation,configurable:true});Object.defineProperty(globalThis,"__ladybirdSetTrustedAttribute",{value:attribute,configurable:true});Object.defineProperty(globalThis,"__ladybirdTrustedTypesFactoryGetter",{value:getter,configurable:true});Object.defineProperty(globalThis,"__ladybirdRegisterTrustedTypesFactory",{value:register,configurable:true});})')!
	defer { runtime.release_javascript_value(installer) }
	runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [operation, attribute, getter, register])!
	runtime.add_close_handler(fn [binding] () {
		mut owner := unsafe { &TrustedTypesPolicyBinding(binding) }
		owner.closed = true
		trusted_types_policy_bindings_.delete(binding.runtime.context)
	})
}

fn (mut runtime Runtime) trusted_types_factory_for_receiver(receiver voidptr) !voidptr {
	mut actual := receiver
	// A Window global attribute converts a null or undefined receiver to its
	// own global. Same-agent iframe globals are actual JSC objects, not JSON.
	if C.JSValueIsNull(runtime.context, actual) || C.JSValueIsUndefined(runtime.context, actual) {
		actual = C.JSContextGetGlobalObject(runtime.context)
	}
	if proxy := runtime.native_window_proxy(actual) {
		window := window_model_for_proxy(proxy)!
		settings := runtime.scripting_settings_ or { return error('InvalidStateError: Window has no settings') }
		if !window.associated_document().origin().is_same_origin_domain(settings.origin()) {
			return runtime.window_proxy_security_error()
		}
		mut proxies := window_proxy_bindings_[voidptr(&runtime)] or { return error('TypeError: Illegal Window receiver') }
		actual = runtime.window_proxy_realm_global(proxies, window) or { return error('InvalidStateError: Window realm is unavailable') }
	}
	group := C.JSContextGetGroup(runtime.context)
	for _, binding in trusted_types_policy_bindings_ {
		if binding.closed || binding.factory == unsafe { nil } { continue }
		owner := binding.runtime
		if C.JSContextGetGroup(owner.context) != group { continue }
		if actual == C.JSContextGetGlobalObject(owner.context) { return binding.factory }
	}
	return error('TypeError: Illegal Window receiver')
}

fn (mut runtime Runtime) trusted_attribute_exception(failure IError) voidptr {
	// A callback may throw any JavaScript value, including an Error whose text
	// resembles a native DOMException. Preserve that original value verbatim.
	if failure is JavaScriptValueException || failure is webidl.ValueException {
		return runtime.binding_exception_value(failure)
	}
	message := failure.msg()
	for name in ['InvalidCharacterError', 'NamespaceError', 'InvalidStateError'] {
		if message.starts_with(name + ':') {
			value := webidl.dom_exception_value(webidl.DOMException.create(name,
				message[name.len + 1..].trim_left(' ')))
			return runtime.javascript_dom_exception(value) or { runtime.binding_exception_value(failure) }
		}
	}
	return runtime.binding_exception_value(failure)
}

fn (binding &TrustedTypesPolicyBinding) set_trusted_attribute(args []voidptr) !voidptr {
	if binding.closed { return error('InvalidStateError: Trusted Types realm is closed') }
	if args.len != 7 { return error('TypeError: Invalid trusted attribute arguments') }
	runtime := binding.runtime
	work := platform.begin_thread_scratch('trusted attribute transport')
	defer { work.finish() }
	key := runtime.binding_dom_string(args[0])!
	namespace := if C.JSValueIsNull(runtime.context, args[1]) { ?string(none) } else { ?string((runtime.binding_dom_utf16(args[1])!).str()) }
	name := (runtime.binding_dom_utf16(args[2])!).str()
	kind := runtime.binding_dom_string(args[3])!
	value := (runtime.binding_dom_utf16(args[4])!).str()
	namespaced := C.JSValueToBoolean(runtime.context, args[5])
	state := runtime.binding_dom_string(args[6])!
	input := match kind {
		'' { trustedtypes.TrustedTypeOrString(value) }
		'TrustedHTML' { trustedtypes.TrustedTypeOrString(trustedtypes.TrustedHTML{data: value}) }
		'TrustedScript' { trustedtypes.TrustedTypeOrString(trustedtypes.TrustedScript{data: value}) }
		'TrustedScriptURL' { trustedtypes.TrustedTypeOrString(trustedtypes.TrustedScriptURL{data: value}) }
		else { return error('TypeError: Invalid private trusted attribute type') }
	}
	work.leave()
	binding.replay(runtime)!
	result := binding.set_attribute(key, namespace, name, input, namespaced, state)!
	return runtime.binding_string(result)
}

fn (binding &TrustedTypesPolicyBinding) create_policy(args []voidptr) !voidptr {
	if binding.closed { return error('InvalidStateError: Trusted Types realm is closed') }
	if args.len != 4 { return error('TypeError: Invalid Trusted Types policy arguments') }
	name := binding.runtime.binding_dom_string(args[0])!
	html_callback := binding.callback_option(args[1])!
	script_callback := binding.callback_option(args[2])!
	url_callback := binding.callback_option(args[3])!
	mut factory := html.trusted_types_factory_for_document(binding.document)
	factory.create_policy(name, trustedtypes.TrustedTypePolicyOptions{
		create_html: html_callback.callback
		create_script: script_callback.callback
		create_script_url: url_callback.callback
	})!
	return C.vox_jsc_JSValueMakeUndefined(binding.runtime.context)
}

fn (binding &TrustedTypesPolicyBinding) callback_option(value voidptr) !TrustedTypesCallbackOption {
	mut runtime := unsafe { &Runtime(binding.runtime) }
	if C.JSValueIsUndefined(runtime.context, value) { return TrustedTypesCallbackOption{} }
	if !C.JSValueIsObject(runtime.context, value) || !C.JSObjectIsFunction(runtime.context, value) {
		return error('TypeError: Trusted Types policy callback must be callable')
	}
	runtime.retain_javascript_value(value)!
	settings := runtime.callback_settings()
	callback := fn [binding, value, settings] (_ string, arguments []webidl.Value) !trustedtypes.PolicyResult {
		if binding.closed { return error('InvalidStateError: Trusted Types realm is closed') }
		mut owner := unsafe { &Runtime(binding.runtime) }
		owner.prepare_html_callback(settings)
		defer { owner.clean_up_html_callback(settings) }
		defer { owner.mark_document_state_dirty() }
		result := binding.invoke_callback(value, arguments) or {
			failure := err
			binding.replay(owner) or { return failure }
			return failure
		}
		// A policy can mutate the DOM, including detaching the very attribute
		// being assigned. Publish those writes before its native caller resumes.
		binding.replay(owner)!
		return result
	}
	return TrustedTypesCallbackOption{callback: callback}
}

fn (binding &TrustedTypesPolicyBinding) invoke_callback(function voidptr, arguments []webidl.Value) !trustedtypes.PolicyResult {
	mut runtime := unsafe { &Runtime(binding.runtime) }
	mut actual := []voidptr{cap: arguments.len}
	for argument in arguments {
		actual << match argument.kind {
			.runtime_value { runtime.actual_webidl_value(argument)! }
			.undefined { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
			.null_ { C.vox_jsc_JSValueMakeNull(runtime.context) }
			.boolean { C.vox_jsc_JSValueMakeBoolean(runtime.context, argument.boolean_value) }
			.number { C.vox_jsc_JSValueMakeNumber(runtime.context, argument.number_value) }
			.string_ { runtime.binding_string(argument.string_value) }
			else { return error('TypeError: Policy callback argument needs an actual engine value') }
		}
	}
	result := runtime.forward_javascript_function(function, C.vox_jsc_JSValueMakeUndefined(runtime.context), actual)!
	if C.JSValueIsNull(runtime.context, result) || C.JSValueIsUndefined(runtime.context, result) {
		return trustedtypes.PolicyResult{}
	}
	runtime.retain_javascript_value(result)!
	defer { runtime.release_javascript_value(result) }
	converted := runtime.call_javascript_function(binding.convert, C.vox_jsc_JSValueMakeUndefined(runtime.context), [result])!
	return trustedtypes.PolicyResult{value: runtime.binding_dom_string(converted)!}
}
