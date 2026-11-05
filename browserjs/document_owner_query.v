module browserjs

import platform

// The synchronous callback only borrows the key for this read. It must not
// retain it or mutate the DOM; false asks the facade to use its normal query.
pub type DocumentOwnerQuery = fn (key string) bool

pub fn (mut runtime Runtime) install_document_owner_query(callback DocumentOwnerQuery) ! {
	runtime.require_javascript_value_context()!
	$if darwin || linux {
		owner := &runtime
		runtime.define_value_host_function('__ladybirdRootDocumentOwner', fn [owner, callback] (_ voidptr, args []voidptr) !voidptr {
			if args.len != 1 || !C.JSValueIsString(owner.context, args[0]) {
				return C.vox_jsc_JSValueMakeBoolean(owner.context, false)
			}
			// No wrapper or retained native value is allocated by this read.
			// Retire the copied input after the synchronous lookup returns.
			work := platform.begin_thread_scratch('document owner key')
			defer { work.finish() }
			key := owner.binding_dom_string(args[0]) or {
				return C.vox_jsc_JSValueMakeBoolean(owner.context, false)
			}
			return C.vox_jsc_JSValueMakeBoolean(owner.context, callback(key))
		})!
		runtime.own_closure(voidptr(callback))
	}
}
