// SPDX-License-Identifier: BSD-2-Clause
module libjs

// AbstractOperations.cpp::perform_import_call. Specifier/options expressions
// have already evaluated in order. Conversion, attributes and loading failures
// reject an intrinsic Promise, without calling a global Promise replacement.
fn perform_import_call(mut vm VM, specifier Value, options Value) !Value {
	active := vm.get_active_script_or_module()
	referrer := match active.kind {
		.script { ImportedModuleReferrer.from_script(active.script or { return error('Missing import script') }) }
		.module { ImportedModuleReferrer.from_module(active.module_record or { return error('Missing import module') }) }
		.empty { ImportedModuleReferrer.from_realm(vm.realm()) }
	}
	constructor := vm.realm().promise_constructor or { return error('Missing intrinsic Promise constructor') }
	capability := new_promise_capability(mut vm, Value.from_object(constructor))!
	name := specifier.to_primitive_string(mut vm) or { return reject_dynamic_import_error(mut vm, capability, err) }
	attributes := dynamic_import_attributes(mut vm, options) or { return reject_dynamic_import_error(mut vm, capability, err) }
	request := ModuleRequest{module_specifier: name.utf16_string(), attributes: attributes}
	owner := &vm
	payload := ImportedModulePayload.for_js_promise_capability(capability, fn [owner, capability] (result ModuleLoadResult) {
		mut agent := unsafe { &VM(owner) }
		continue_dynamic_import(mut agent, capability, result) or { agent.promise_job_errors << err }
	})
	// A custom embedding hook owns its fetch/security policy. The default VM
	// filesystem hook still enforces dynamic_imports_allowed on this payload.
	vm.host_load_imported_module(referrer, request, unsafe { nil }, payload)
	return capability.promise
}

fn reject_dynamic_import_error(mut vm VM, capability &JSPromiseCapability, err IError) !Value {
	reason := if is_throw_completion(err) { thrown_value(err) } else {
		Value.from_object(create_error(mut vm, vm.realm(), .internal_error, utf16_string(err.msg())))
	}
	call(mut vm, capability.reject, js_undefined(), [reason])!
	return capability.promise
}

fn dynamic_import_attributes(mut vm VM, options Value) ![]ImportAttribute {
	if options.is_undefined() { return []ImportAttribute{} }
	if !options.is_object() { return vm.throw_error(.type_error, 'Import options must be an object') }
	attributes := options.as_object().get(mut vm, PropertyName.from_str('with'))!
	mut result := []ImportAttribute{}
	if !attributes.is_undefined() {
		if !attributes.is_object() { return vm.throw_error(.type_error, 'Import attributes must be an object') }
		object := attributes.as_object()
		mut names := []Utf16String{}
		mut values := []Value{}
		// EnumerableOwnProperties snapshots keys and reads all enumerable string
		// values before validating their types. Symbol getters are not invoked.
		for key in object.own_property_keys() {
			vm.consume_execution_budget()!
			if key.is_symbol() { continue }
			descriptor := object.internal_get_own_property(key) or { continue }
			if !(descriptor.enumerable or { false }) { continue }
			names << key.to_value(mut vm).as_string().utf16_string()
			values << object.get(mut vm, key)!
		}
		for index, name in names {
			if !values[index].is_string() { return vm.throw_error(.type_error, 'Import attribute values must be strings') }
			result << ImportAttribute{key: name, value: values[index].as_string().utf16_string()}
		}
	}
	supported := vm.host_get_supported_import_attributes()
	for attribute in result {
		if !supported.any(it == attribute.key) { return vm.throw_error(.type_error, 'Unsupported import attribute: ${attribute.key.str()}') }
	}
	for index in 1 .. result.len {
		mut cursor := index
		for cursor > 0 && module_name_less(result[cursor].key, result[cursor - 1].key) {
			result[cursor], result[cursor - 1] = result[cursor - 1], result[cursor]
			cursor--
		}
	}
	return result
}

// CyclicModule.cpp::continue_dynamic_import. Observe the native module promises
// through PerformPromiseThen; both loading and evaluation may finish later.
// No user-replaced .then or @@species participates in these continuations.
fn continue_dynamic_import(mut vm VM, capability &JSPromiseCapability, result ModuleLoadResult) ! {
	if reason := result.thrown {
		call(mut vm, capability.reject, js_undefined(), [reason])!
		return
	}
	loaded := result.module_record or { return error('Import loader returned no module') }
	if loaded !is SourceTextModule {
		reject_dynamic_import_error(mut vm, capability, vm.throw_error(.type_error, 'Dynamic import requires a translated JavaScript module'))!
		return
	}
	target := loaded
	mut module_record := unsafe { &SourceTextModule(target) }
	loading := module_record.load_requested_modules(mut vm, unsafe { nil })
	reject := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [capability] (mut vm VM) !Value {
		call(mut vm, capability.reject, js_undefined(), [vm.argument(0)])!
		return js_undefined()
	}, 1, PropertyName.from_str(''), none).object
	link_and_evaluate := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [target, capability, reject] (mut vm VM) !Value {
		mut module_record := unsafe { &SourceTextModule(target) }
		module_record.link(mut vm) or { return reject_dynamic_import_error(mut vm, capability, err) }
		evaluation := module_record.evaluate(mut vm) or { return reject_dynamic_import_error(mut vm, capability, err) }
		fulfilled := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [target, capability] (mut vm VM) !Value {
			mut module_record := unsafe { &SourceTextModule(target) }
			namespace := module_record.get_module_namespace(mut vm) or { return reject_dynamic_import_error(mut vm, capability, err) }
			call(mut vm, capability.resolve, js_undefined(), [Value.from_object(namespace)])!
			return js_undefined()
		}, 0, PropertyName.from_str(''), none).object
		observe_module_promise(mut vm, evaluation.promise, Value.from_object(fulfilled), Value.from_object(reject))
		return js_undefined()
	}, 0, PropertyName.from_str(''), none).object
	observe_module_promise(mut vm, loading.promise, Value.from_object(link_and_evaluate), Value.from_object(reject))
}

fn observe_module_promise(mut vm VM, promise &Promise, fulfilled Value, rejected Value) {
	mut record := unsafe { &Promise(promise) }
	record.owner_vm = &vm
	perform_promise_then(mut vm, mut record, fulfilled, rejected, unsafe { nil })
}
