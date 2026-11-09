module browserjs

import contentsecuritypolicy as csp
import html

$if darwin {
	#include "@DIR/eval_policy_jsc.h"
}
fn C.vox_jsc_set_eval_enabled(context voidptr, enabled bool)

fn (mut runtime Runtime) install_string_compilation_policy(realm &html.ScriptingRealm) {
	$if darwin {
		$if !vox_v8 ? {
			owner := voidptr(&runtime)
			callback := fn [owner] () {
				runtime := unsafe { &Runtime(owner) }
				if runtime.closed { return }
				settings := runtime.scripting_settings_ or { return }
				global := settings.fetch_request_client_csp_global()
				C.vox_jsc_set_eval_enabled(runtime.context,csp.string_compilation_is_allowed(global))
			}
			runtime.own_closure(voidptr(callback))
			mut mutable_realm := unsafe { &html.ScriptingRealm(realm) }
			mutable_realm.string_compilation_policy_changed_ = callback
			callback()
			runtime.add_close_handler(fn [realm] () {
				mut mutable_realm := unsafe { &html.ScriptingRealm(realm) }
				mutable_realm.string_compilation_policy_changed_ = none
			})
		}
	}
}
