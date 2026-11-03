module browserjs

import dom

// Compact detached documents share their realm's native EventTarget machinery,
// while retaining their own Document identity and event-handler slots.
pub fn (mut runtime Runtime) install_document_event_target_resolver(resolve DocumentEventTargetResolver) ! {
	runtime.install_event_target_binding()!
	owner := voidptr(&runtime)
	runtime.define_value_host_function('__ladybirdDocumentEventTargetBind', fn [owner, resolve] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if args.len != 2 { return runtime.event_binding_type_error('Missing Document binding arguments') }
		key := runtime.binding_dom_string(args[1])!
		document := resolve(key) or { return runtime.event_binding_type_error('Unknown Document owner') }
		binding := runtime.event_binding()!
		if target := binding.targets[args[0]] {
			if voidptr(target) != voidptr(document) {
				return runtime.event_binding_type_error('Document wrapper already owns another target')
			}
			return C.vox_jsc_JSValueMakeUndefined(runtime.context)
		}
		runtime.bind_event_target(args[0], unsafe { &dom.EventTarget(document) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
}

fn (mut runtime Runtime) install_document_scrollend_handler(document_wrapper voidptr) ! {
	owner := voidptr(&runtime)
	get := runtime.make_native_value_host_function('get onscrollend', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		target := runtime.native_event_target(receiver)!
		if target.data.kind != .node || unsafe { &dom.Node(target) }.as_document() == none {
			return runtime.event_binding_type_error('Illegal Document receiver')
		}
		return runtime.javascript_event_handler(target, 'scrollend')!
	})!
	set := runtime.make_native_value_host_function('set onscrollend', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		target := runtime.native_event_target(receiver)!
		if target.data.kind != .node || unsafe { &dom.Node(target) }.as_document() == none {
			return runtime.event_binding_type_error('Illegal Document receiver')
		}
		value := if args.len > 0 { args[0] } else { C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		runtime.set_javascript_event_handler(target, 'scrollend', value)!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	factory := runtime.evaluate_host_value(r'(function(document,get,set){
 const target=typeof Document==="function"?Document.prototype:document;
 Object.defineProperty(target,"onscrollend",{get,set,enumerable:true,configurable:true});
})')!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [document_wrapper, get, set])!
}
