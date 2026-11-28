// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import xhr

@[heap]
struct FormDataIteratorBinding {
	kind xhr.IteratorKind
mut:
	native xhr.FormDataIterator
	done bool
}

fn (mut host Host) install_form_data_iteration(mut prototype libjs.Object) ! {
	mut vm := host.vm
	mut iterator_prototype := libjs.Object.create(host.realm, host.realm.iterator_prototype)
	host.form_data_iterator_prototype = iterator_prototype
	iterator_prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('FormData Iterator')), libjs.attribute_configurable)
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut iterator_prototype, 'next', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		if vm.this_value().is_object() {
			if mut state := host.form_data_iterators[voidptr(vm.this_value().as_object())] {
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				mut owner := unsafe { &Host(host) }
				mut value := libjs.js_undefined()
				if !state.done {
					step := state.native.next(); state.done = step.done
					if !step.done {
						value = match state.kind {
							.key { libjs.Value.from_string(vm.create_string_from_str(step.key)) }
							.value { owner.form_entry_value(mut vm, step.value) }
							.key_value { libjs.Value.from_object(libjs.ArrayObject.create_from(mut vm, host.realm, [libjs.Value.from_string(vm.create_string_from_str(step.key)), owner.form_entry_value(mut vm, step.value)], host.realm.array_prototype_record())!.object) }
						}
					}
				}
				return libjs.Value.from_object(libjs.create_iterator_result_object(host.realm, value, state.done, host.realm.object_prototype))
			}
		}
		return vm.throw_error(.type_error, 'Expected a FormData Iterator')
	}, attributes)
	for name, kind in {'keys': xhr.IteratorKind.key, 'values': .value, 'entries': .key_value} {
		host.method_attributes(mut prototype, name, 0, fn [host, kind] (mut vm libjs.VM) !libjs.Value {
			native := host.form_data_value(mut vm, vm.this_value())!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			object := libjs.Object.create(host.realm, host.form_data_iterator_prototype)
			owner.form_data_iterators[voidptr(object)] = &FormDataIteratorBinding{native: native.iterator(kind), kind: kind}
			return libjs.Value.from_object(object)
		}, attributes)
	}
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), prototype.get(mut vm, libjs.PropertyName.from_str('entries'))!, libjs.attribute_writable | libjs.attribute_configurable)
	host.method_attributes(mut prototype, 'forEach', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.form_data_value(mut vm, vm.this_value())!
		callback, receiver, object := vm.argument(0), vm.argument(1), vm.this_value()
		if !callback.is_function() { return vm.throw_error(.type_error, 'FormData callback must be callable') }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		mut iterator := native.iterator(.key_value)
		for {
			vm.consume_execution_budget()!
			step := iterator.next()
			if step.done { break }
			libjs.call(mut vm, callback, receiver, [owner.form_entry_value(mut vm, step.value), libjs.Value.from_string(vm.create_string_from_str(step.key)), object])!
		}
		return libjs.js_undefined()
	}, attributes)
}
