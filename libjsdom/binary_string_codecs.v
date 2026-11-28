// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform

fn (mut host Host) install_binary_string_codecs() {
	mut global := host.realm.global_object_record()
	for name in ['atob', 'btoa'] {
		host.method_attributes(mut global, name, 1, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.window_receiver(mut vm)!
			if vm.argument_count() < 1 { return vm.throw_error(.type_error, name + ' requires an argument') }
			input := vm.argument(0).to_primitive_string(mut vm)!.str()
			charge_buffer_source_work(mut vm, u64(input.len))!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			output := if name == 'atob' {
				html.forgiving_base64_to_binary_string(input) or { return owner.dom_error(mut vm, err) }
			} else {
				html.binary_string_to_base64(input) or { return owner.dom_error(mut vm, err) }
			}
			return libjs.Value.from_string(vm.create_string_from_str(output))
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
