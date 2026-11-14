module browserjs

import libjs
import platform

// Module source executes in its own translated environment. Dependency graphs,
// dynamic imports and top-level await still fail explicitly in SourceTextModule.
fn (runtime &Runtime) execute_libjs_module(prepared &PreparedScript, stringify_result bool) !string {
	if prepared.frontend.reached_recursion_limit {
		return error('LibJS frontend recursion limit reached; module cannot be executed')
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &Runtime(runtime) }
	source := prepared.source
	mut key := source.url
	if element := source.element {
		if !element.has_attribute('src') { key += '#vox-libjs-inline-${element.as_node().unique_id()}' }
	}
	if key == '' {
		owner.next_libjs_inline_module_++
		key = '<libjs-module-${owner.next_libjs_inline_module_}>'
	}
	mut module_record := owner.libjs_modules_[key] or {
		created := &libjs.SourceTextModule{
			module_realm: runtime.realm
			module_filename: source.url.clone()
			parsed: prepared.frontend
			host_defined: voidptr(runtime)
			module_starting_line: u32(source.starting_line)
		}
		owner.libjs_modules_[key.clone()] = created
		created
	}
	mut vm := unsafe { &libjs.VM(runtime.agent_vm) }
	runtime.prepare_html_script()
	defer { runtime.clean_up_html_script() }
	module_record.link(mut vm) or { return error(libjs_exception_message(err)) }
	result := module_record.evaluate(mut vm) or { return error(libjs_exception_message(err)) }
	if result.promise.state == .rejected {
		return error(libjs_exception_message(libjs.throw_completion(result.promise.result)))
	}
	return if stringify_result { 'undefined' } else { '' }
}
