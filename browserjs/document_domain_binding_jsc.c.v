module browserjs

import dom
import webidl

fn (runtime &Runtime) document_domain_receiver(receiver voidptr) !&dom.Document {
	target := runtime.native_event_target(receiver)!
	if target.data.kind != .node { return runtime.event_binding_type_error('Illegal Document receiver') }
	return unsafe { &dom.Node(target) }.as_document() or {
		return runtime.event_binding_type_error('Illegal Document receiver')
	}
}

fn (mut runtime Runtime) install_document_domain_attribute(document_wrapper voidptr) ! {
	runtime.install_dom_exception_binding()!
	owner := voidptr(&runtime)
	get := runtime.make_native_value_host_function('get domain', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		document := runtime.document_domain_receiver(receiver)!
		return runtime.binding_string(document.domain())
	})!
	set := runtime.make_native_value_host_function('set domain', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		mut document := runtime.document_domain_receiver(receiver)!
		value := if args.len > 0 { args[0] } else { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		// The IDL attribute is USVString: perform actual engine ToString once,
		// preserving author exceptions, then repair unpaired surrogate units.
		text := (runtime.binding_dom_utf16(value)!).to_well_formed().str()
		document.set_domain(text) or {
			if err.msg().starts_with('SecurityError:') {
				exception := webidl.dom_exception_value(webidl.DOMException.create('SecurityError', err.msg().all_after('SecurityError:').trim_space()))
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(exception)!)
			}
			return err
		}
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	factory := runtime.evaluate_host_value(r'(function(document,get,set){
 const target=typeof Document==="function"?Document.prototype:document;
 Object.defineProperty(target,"domain",{get,set,enumerable:true,configurable:true});
})')!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [document_wrapper, get, set])!
}
