module browserjs

import dom
import html

fn (mut runtime Runtime) install_inline_script_evaluator(realm &html.ScriptingRealm) {
	owner := voidptr(&runtime)
	callback := fn [owner] (kind html.ScriptElementType, source string, address string, line int, element ?&dom.Element) ! {
		mut runtime := unsafe { &Runtime(owner) }
		if runtime.closed { return }
		runtime.run_document_scripts([ScriptSource{code:source,url:address,starting_line:line,
			source_type:if kind == .module { .module } else { .script },element:element}])!
		runtime.mark_document_state_dirty()
	}
	runtime.own_closure(voidptr(callback))
	mut mutable_realm := unsafe { &html.ScriptingRealm(realm) }
	mutable_realm.evaluate_script_element_ = callback
	runtime.add_close_handler(fn [realm] () { mut owner := unsafe { &html.ScriptingRealm(realm) }; owner.evaluate_script_element_ = none })
}
