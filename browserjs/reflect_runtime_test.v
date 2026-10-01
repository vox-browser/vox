module browserjs

import libjs

// The completed Reflect record receives explicit Object/Array dependencies.
// Its test-only global name does not expose an unfinished production graph.
fn install_reflect_test_host(mut runtime Runtime) {
	mut vm := runtime.libjs_vm()
	realm := vm.realm()
	mut object_parent := libjs.Object.create(realm, none)
	object_parent.immutable_prototype = true
	array_parent := libjs.Object.create(realm, object_parent)
	reflect := libjs.ReflectObject.create(mut vm, realm, object_parent, array_parent).object
	mut parent := libjs.Object.create(realm, object_parent)
	parent.define_direct_property(libjs.PropertyName.from_str('inherited'),
		libjs.Value.from_i32(42), 7)
	mut target := libjs.Object.create(realm, parent)
	target.define_direct_property(libjs.PropertyName.from_str('storage'), libjs.Value.from_i32(42),
		7)
	target.define_direct_property(libjs.PropertyName.from_str('fixed'), libjs.Value.from_i32(1), 0)
	for index, name in ['HostReflect', 'HostRoot', 'Parent', 'Target'] {
		object := [reflect, object_parent, parent, target][index]
		mut global := vm.get_global_object()
		global.define_direct_property(libjs.PropertyName.from_str(name),
			libjs.Value.from_object(object), 7)
	}
	getter := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		return vm.this_value()
	}, 0, libjs.PropertyName.from_str('HostGetter'), none)
	setter := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm libjs.VM) !libjs.Value {
		mut receiver := vm.this_value().as_object()
		receiver.set(mut vm, libjs.PropertyName.from_str('storage'), vm.argument(0), .yes)!
		return libjs.js_undefined()
	}, 1, libjs.PropertyName.from_str('HostSetter'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(libjs.PropertyName.from_str('HostGetter'),
		libjs.Value.from_object(getter.object), 7)
	global.define_direct_property(libjs.PropertyName.from_str('HostSetter'),
		libjs.Value.from_object(setter.object), 7)
}

fn test_browser_reflect_property_methods_execute_real_record_callbacks_and_return_boolean_failures() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_reflect_test_host(mut runtime)
	assert runtime.evaluate('HostReflect.get(Target,"storage");')! == '42'
	assert runtime.evaluate('HostReflect.has(Target,"inherited") && HostReflect.getOwnPropertyDescriptor(Target,"inherited")===undefined;')! == 'true'
	assert runtime.evaluate('HostReflect.set(Target,"storage",77) && HostReflect.get(Target,"storage")===77;')! == 'true'
	assert runtime.evaluate('HostReflect.set(Target,"fixed",42);')! == 'false'
	assert runtime.evaluate('HostReflect.deleteProperty(Target,"fixed");')! == 'false'
	assert runtime.evaluate('var descriptor=new Boolean(false); descriptor.value=99; descriptor.writable=true; descriptor.enumerable=true; descriptor.configurable=true; HostReflect.defineProperty(Target,"answer",descriptor);')! == 'true'
	assert runtime.evaluate('var actual=HostReflect.getOwnPropertyDescriptor(Target,"answer"); actual.value===99 && actual.writable && actual.enumerable && actual.configurable;')! == 'true'
	assert runtime.evaluate('var key=Symbol("answer"); HostReflect.defineProperty(Target,key,descriptor); HostReflect.get(Target,key);')! == '99'
	assert runtime.evaluate('HostReflect.deleteProperty(Target,"answer") && !HostReflect.has(Target,"answer");')! == 'true'
	assert runtime.evaluate('HostReflect.set(Parent,"inherited",17,Target); HostReflect.get(Target,"inherited")===17 && HostReflect.get(Parent,"inherited")===42;')! == 'true'
	assert runtime.evaluate('HostReflect.set(Target,"storage",12,undefined);')! == 'false'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_reflect_accessors_preserve_explicit_receivers_and_descriptor_callback_identity() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_reflect_test_host(mut runtime)
	assert runtime.evaluate('var descriptor=new Boolean(false); descriptor.get=HostGetter; descriptor.set=HostSetter; descriptor.enumerable=true; descriptor.configurable=true; HostReflect.defineProperty(Parent,"answer",descriptor);')! == 'true'
	assert runtime.evaluate('HostReflect.get(Target,"answer")===Target && HostReflect.get(Target,"answer",42)===42 && HostReflect.get(Target,"answer",undefined)===undefined;')! == 'true'
	assert runtime.evaluate('HostReflect.set(Parent,"answer",77,Target) && Target.storage===77;')! == 'true'
	assert runtime.evaluate('HostReflect.getOwnPropertyDescriptor(Target,"answer");')! == 'undefined'
	assert runtime.evaluate('var actual=HostReflect.getOwnPropertyDescriptor(Parent,"answer"); actual.get===HostGetter && actual.set===HostSetter && actual.enumerable && actual.configurable;')! == 'true'
	assert runtime.evaluate('HostReflect.ownKeys(actual)[0]==="get" && HostReflect.ownKeys(actual)[1]==="set";')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_reflect_prototypes_extensibility_and_key_arrays_preserve_live_state() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_reflect_test_host(mut runtime)
	assert runtime.evaluate('var key=Symbol("visible"); Target[42]=1; Target[2]=2; Target[key]=3; var keys=HostReflect.ownKeys(Target); keys.length===5 && keys[0]==="2" && keys[1]==="42" && keys[2]==="storage" && keys[3]==="fixed" && keys[4]===key;')! == 'true'
	assert runtime.evaluate('HostReflect.ownKeys(Target)!==keys && HostReflect.getOwnPropertyDescriptor(keys,"length").enumerable===false;')! == 'true'
	assert runtime.evaluate('HostReflect.getPrototypeOf(Target)===Parent && HostReflect.getPrototypeOf(HostRoot)===null;')! == 'true'
	assert runtime.evaluate('HostReflect.setPrototypeOf(Target,Target);')! == 'false'
	assert runtime.evaluate('HostReflect.setPrototypeOf(HostRoot,Parent);')! == 'false'
	assert runtime.evaluate('HostReflect.setPrototypeOf(Target,null) && !HostReflect.has(Target,"inherited");')! == 'true'
	assert runtime.evaluate('HostReflect.setPrototypeOf(Target,Parent) && HostReflect.isExtensible(Target);')! == 'true'
	assert runtime.evaluate('HostReflect.preventExtensions(Target) && !HostReflect.isExtensible(Target);')! == 'true'
	assert runtime.evaluate('HostReflect.set(Target,"newValue",42);')! == 'false'
	assert runtime.evaluate('HostReflect.setPrototypeOf(Target,null);')! == 'false'
	assert runtime.evaluate('HostReflect.setPrototypeOf(Target,Parent);')! == 'true'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_browser_reflect_apply_construct_and_error_recovery_execute_without_javascriptcore() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	install_reflect_test_host(mut runtime)
	assert runtime.evaluate('var list=new Boolean(false); list.length=1; list[0]="42"; HostReflect.apply(parseInt,null,list);')! == '42'
	assert runtime.evaluate('HostReflect.apply(HostGetter,77,list);')! == '77'
	assert runtime.evaluate('HostReflect.apply(parseInt.bind(null),undefined,list);')! == '42'
	assert runtime.evaluate('var result=HostReflect.construct(Boolean,list); result.valueOf();')! == 'true'
	assert runtime.evaluate('HostReflect.getPrototypeOf(result)===Boolean.prototype;')! == 'true'
	errors := runtime.run_document_scripts_collect_errors([
		ScriptSource{ code: 'HostReflect.get(42,"answer");', url: 'reflect-target.js' },
		ScriptSource{ code: 'HostReflect.setPrototypeOf(Target,42);', url: 'reflect-prototype.js' },
		ScriptSource{
			code: 'HostReflect.construct(Boolean,list,undefined);'
			url:  'reflect-new-target.js'
		},
		ScriptSource{ code: 'HostReflect.apply(42,null,list);', url: 'reflect-callable.js' },
		ScriptSource{ code: 'HostReflect.apply(parseInt,null,null);', url: 'reflect-list.js' },
	])
	assert errors.len == 5
	assert errors[0].contains('42 is not an object') && errors[0].contains('reflect-target.js')
	assert errors[1].contains('Prototype must be an object or null')
	assert errors[2].contains('undefined is not a constructor')
	assert errors[3].contains('42 is not a function')
	assert errors[4].contains('null is not an object')
	assert runtime.evaluate('HostReflect.apply(parseInt,null,list);')! == '42'
	assert runtime.context == unsafe { nil }
	vm := runtime.libjs_vm()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}
