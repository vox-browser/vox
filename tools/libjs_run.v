module main

import libjs
import os

fn fail(err IError) {
	if libjs.is_throw_completion(err) {
		value := libjs.thrown_value(err)
		if value.is_object() {
			object := value.as_object()
			if kind := object.error_kind() {
				eprintln('${kind.name()}: ${object.error_message() or { '' }}')
				if data := object.error_data { eprint(data.stack_string(false)) }
				exit(1)
			}
		}
	}
	eprintln(err.msg())
	exit(1)
}

// A standalone entry into the translated VM. No browser host or JavaScriptCore.
fn main() {
	args := os.args[1..]
	mut source := ''
	mut filename := '<command line>'
	if args.len == 2 && args[0] == '-e' {
		source = args[1]
	} else if args.len == 1 && !args[0].starts_with('-') {
		filename = os.real_path(args[0])
		source = os.read_file(filename) or {
			fail(err)
			return
		}
	} else {
		eprintln('Usage: libjs_run -e SOURCE | FILE.js')
		exit(2)
	}
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut script := libjs.Script.parse(source, vm.realm(), filename, unsafe { nil }) or {
		fail(err)
		return
	}
	value := vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 1000000 }) or {
		fail(err)
		return
	}
	println(value.str())
}
