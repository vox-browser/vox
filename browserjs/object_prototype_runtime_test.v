module browserjs

import libjs

// Explicit test host for translated ObjectPrototype native bodies. The actual
// ObjectPrototype intrinsic record and toString/IsArray chain are not installed.
fn install_object_method_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	mut methods := libjs.Object.create(realm, none)
	methods.immutable_prototype = true
	getter := fn (realm &libjs.Realm) &libjs.Object {
		return realm.data_view_prototype_record()
	}
	prototypes := libjs.PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	for name in ['hasOwnProperty', 'toLocaleString', 'valueOf', 'propertyIsEnumerable',
		'isPrototypeOf', '__defineGetter__', '__defineSetter__', '__lookupGetter__',
		'__lookupSetter__'] {
		length := if name in ['__defineGetter__', '__defineSetter__'] {
			2
		} else if name in ['toLocaleString', 'valueOf'] {
			0
		} else {
			1
		}
		function := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [name, prototypes] (mut vm libjs.VM) !libjs.Value {
			return match name {
				'hasOwnProperty' { libjs.object_prototype_has_own_property(mut vm, prototypes) }
				'toLocaleString' { libjs.object_prototype_to_locale_string(mut vm, prototypes) }
				'valueOf' { libjs.object_prototype_value_of(mut vm, prototypes) }
				'propertyIsEnumerable' { libjs.object_prototype_property_is_enumerable(mut vm,
						prototypes) }
				'isPrototypeOf' { libjs.object_prototype_is_prototype_of(mut vm, prototypes) }
				'__defineGetter__' { libjs.object_prototype_define_getter(mut vm, prototypes) }
				'__defineSetter__' { libjs.object_prototype_define_setter(mut vm, prototypes) }
				'__lookupGetter__' { libjs.object_prototype_lookup_getter(mut vm, prototypes) }
				'__lookupSetter__' { libjs.object_prototype_lookup_setter(mut vm, prototypes) }
				else { panic('unknown fixture method') }
			}
		}, length, libjs.PropertyName.from_str(name), none)
		methods.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(function.object), 5)
	}
	methods.define_native_accessor(mut vm, realm, libjs.PropertyName.from_str('__proto__'), fn [prototypes] (mut vm libjs.VM) !libjs.Value {
		return libjs.object_prototype_proto_getter(mut vm, prototypes)
	}, fn (mut vm libjs.VM) !libjs.Value {
		return libjs.object_prototype_proto_setter(mut vm)
	}, libjs.attribute_configurable, realm.function_prototype)
	mut parent := libjs.Object.create(realm, methods)
	parent.define_direct_property(libjs.PropertyName.from_str('inherited'),
		libjs.Value.from_i32(42), 7)
	mut child := libjs.Object.create(realm, parent)
	child.define_direct_property(libjs.PropertyName.from_str('storage'), libjs.Value.from_i32(42),
		7)
	child.define_direct_property(libjs.PropertyName.from_str('hidden'), libjs.Value.from_i32(1), 5)
	callback_get := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		assert vm.argument_count() == 0
		return vm.this_value().as_object().get(mut vm, libjs.PropertyName.from_str('storage'))
	}, 0, libjs.PropertyName.from_str('HostGetter'), none)
	callback_set := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		mut object := vm.this_value().as_object()
		object.set(mut vm, libjs.PropertyName.from_str('storage'), vm.argument(0), .yes)!
		return libjs.js_undefined()
	}, 1, libjs.PropertyName.from_str('HostSetter'), none)
	mut global := vm.get_global_object()
	for index, name in ['HostMethods', 'Parent', 'Child', 'HostGetter', 'HostSetter'] {
		object := [methods, parent, child, callback_get.object, callback_set.object][index]
		global.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(object), 7)
	}
}

fn test_browser_object_membership_value_of_and_locale_bodies_execute_translated_bytecode() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_object_method_test_host(mut runtime)
	assert runtime.evaluate('Child.hasOwnProperty("storage") && Child.hasOwnProperty("hidden") && !Child.hasOwnProperty("inherited");')! == 'true'
	assert runtime.evaluate('Child.propertyIsEnumerable("storage") && !Child.propertyIsEnumerable("hidden") && !Child.propertyIsEnumerable("inherited");')! == 'true'
	assert runtime.evaluate('Parent.isPrototypeOf(Child) && HostMethods.isPrototypeOf(Child) && !Child.isPrototypeOf(Child);')! == 'true'
	assert runtime.evaluate('HostMethods.isPrototypeOf.call(null,42);')! == 'false'
	assert runtime.evaluate('Child.valueOf()===Child && HostMethods.valueOf.call(42)!==42;')! == 'true'
	assert runtime.evaluate('HostMethods.hasOwnProperty.call("abc",1) && HostMethods.propertyIsEnumerable.call("abc",1);')! == 'true'
	assert runtime.evaluate('HostMethods.hasOwnProperty.call("abc","length") && !HostMethods.propertyIsEnumerable.call("abc","length");')! == 'true'
	assert runtime.evaluate('Child.toString=HostGetter; Child.toLocaleString("ignored","also ignored");')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_legacy_accessors_preserve_both_callbacks_and_stop_lookup_at_data_properties() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_object_method_test_host(mut runtime)
	assert runtime.evaluate('Parent.__defineGetter__("answer",HostGetter); Parent.__defineSetter__("answer",HostSetter); Child.answer;')! == '42'
	assert runtime.evaluate('Child.answer=77; Child.storage;')! == '77'
	assert runtime.evaluate('Child.__lookupGetter__("answer")===HostGetter && Child.__lookupSetter__("answer")===HostSetter;')! == 'true'
	assert runtime.evaluate('Child.__defineGetter__("answer",HostGetter); Child.__lookupSetter__("answer");')! == 'undefined'
	assert runtime.evaluate('Child.__defineSetter__("answer",HostSetter); Child.answer=99; Child.answer;')! == '99'
	assert runtime.evaluate('Child.__lookupGetter__("storage");')! == 'undefined'
	assert runtime.evaluate('var key=Symbol("answer"); Child.__defineGetter__(key,HostGetter); Child[key];')! == '99'
	assert runtime.evaluate('Child.__lookupGetter__(key)===HostGetter && Child.propertyIsEnumerable(key);')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_proto_accessors_follow_live_prototype_changes_and_leave_vm_usable_after_errors() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_object_method_test_host(mut runtime)
	assert runtime.evaluate('Child.__proto__===Parent && Parent.__proto__===HostMethods && HostMethods.__proto__===null;')! == 'true'
	assert runtime.evaluate('Child.__proto__=42; Child.__proto__===Parent;')! == 'true'
	assert runtime.evaluate('var setProto=HostMethods.__lookupSetter__("__proto__"); Child.__proto__=null; HostMethods.isPrototypeOf(Child);')! == 'false'
	assert runtime.evaluate('setProto.call(Child,Parent); HostMethods.isPrototypeOf(Child);')! == 'true'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'Child.__proto__=Child;', url: 'object-proto-cycle.js' },
		ScriptSource{ code: 'HostMethods.__proto__=Parent;', url: 'object-proto-immutable.js' },
		ScriptSource{ code: 'setProto.call(null,42);', url: 'object-proto-null.js' },
		ScriptSource{
			code: 'Child.__defineGetter__("answer",42);'
			url:  'object-accessor-callability.js'
		},
	])
	assert errors.len == 4
	assert errors[0].contains("Object's [[SetPrototypeOf]] method returned false")
		&& errors[0].contains('object-proto-cycle.js')
	assert errors[1].contains("Object's [[SetPrototypeOf]] method returned false")
		&& errors[1].contains('object-proto-immutable.js')
	assert errors[2].contains('null cannot be converted to an object')
	assert errors[3].contains('42 is not a function')
	assert runtime.evaluate('Child.__proto__===Parent && HostMethods.__proto__===null && Child.valueOf()===Child;')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}
