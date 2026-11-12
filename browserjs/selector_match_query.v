module browserjs

import platform

pub struct SelectorMatchReply {
pub:
	handled bool
	matched bool
}

pub type SelectorMatchQuery = fn (key string, selector string) !SelectorMatchReply

// Keys and selectors are borrowed only for the synchronous callback. An
// unhandled owner asks the facade to use the ordinary DOM query transport.
pub fn (mut runtime Runtime) install_selector_match_query(callback SelectorMatchQuery) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux || windows {
		owner := &runtime
		runtime.define_value_host_function('__ladybirdSelectorMatches', fn [owner, callback] (_ voidptr, args []voidptr) !voidptr {
			if args.len != 2 || !C.JSValueIsString(owner.context, args[0])
				|| !C.JSValueIsString(owner.context, args[1]) {
				return C.vox_jsc_JSValueMakeUndefined(owner.context)
			}
			work := platform.begin_thread_scratch('selector match arguments')
			defer { work.finish() }
			key := owner.binding_dom_string(args[0])!
			selector := owner.binding_dom_string(args[1])!
			// DOM reactions may allocate retained state while reading the owner.
			// Retire only the argument copies with this scratch scope.
			work.leave()
			reply := callback(key, selector)!
			if !reply.handled { return C.vox_jsc_JSValueMakeUndefined(owner.context) }
			return C.vox_jsc_JSValueMakeBoolean(owner.context, reply.matched)
		})!
		runtime.own_closure(voidptr(callback))
	}
}
