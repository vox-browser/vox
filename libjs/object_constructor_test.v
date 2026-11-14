// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn object_constructor_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'object-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_object_constructor_intrinsic_descriptors_and_realm_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	constructor := realm.object_constructor_record()
	assert voidptr(constructor.internal_get_prototype_of()?) == voidptr(realm.function_prototype_record())
	assert Value.from_object(constructor).is_constructor()
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'Object'
	prototype := constructor.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert voidptr(prototype.value?.as_object()) == voidptr(realm.object_prototype_record())
	assert !prototype.writable? && !prototype.enumerable? && !prototype.configurable?
	back_reference := realm.object_prototype_record().internal_get_own_property(PropertyName.from_str('constructor'))?
	assert voidptr(back_reference.value?.as_object()) == voidptr(constructor)
	assert back_reference.writable? && back_reference.configurable? && !back_reference.enumerable?
	global := realm.global_object_record().internal_get_own_property(PropertyName.from_str('Object'))?
	assert voidptr(global.value?.as_object()) == voidptr(constructor)
	assert global.writable? && global.configurable? && !global.enumerable?
	for name, length in {
		'defineProperty': 3
		'create':         2
		'assign':         2
		'keys':           1
		'hasOwn':         2
		'is':             2
	} {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		method := descriptor.value?.as_object()
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == length
		assert !Value.from_object(method).is_constructor()
	}
	foreign := create_simple_execution_context(mut vm).realm?
	assert voidptr(foreign.object_constructor_record()) != voidptr(constructor)
	assert voidptr(foreign.object_prototype_record()) != voidptr(realm.object_prototype_record())
}

fn test_object_call_and_construction_box_values_and_honor_new_target() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	constructor := Value.from_object(realm.object_constructor_record())
	original := Object.create(realm, none)
	for value in [js_null(), js_undefined(), Value.from_bool(true), Value.from_i32(42),
		Value.from_string(vm.create_string_from_str('abc')), Value.from_object(original),
		Value.from_symbol(Symbol.create(none, .unique)),
		Value.from_bigint(string_to_bigint(utf16_string('42'))?)] {
		called := call(mut vm, constructor, js_null(), [value])!.as_object()
		created := construct(mut vm, constructor, [value], none)!
		if value.is_object() {
			assert voidptr(called) == voidptr(original) && voidptr(created) == voidptr(original)
		} else {
			assert voidptr(called) != voidptr(created)
			if value.is_number() {
				assert called.number_object?.value == 42 && created.number_object?.value == 42
			}
			if value.is_string() {
				assert called.string_object?.value.str() == 'abc'
			}
			if value.is_boolean() {
				assert called.boolean_object?.value
			}
			if value.is_symbol() {
				assert voidptr(called.symbol_object?.symbol) == voidptr(value.as_symbol())
			}
		}
	}
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	custom := Object.create(realm, none)
	for prototype in [Value.from_object(custom), js_null(), Value.from_i32(5)] {
		target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
			object_constructor_call, object_constructor_construct, 1, PropertyName.from_str('Derived'))
		mut object := target.object
		object.define_direct_property(PropertyName.from_str('prototype'), prototype, 0)
		created := construct(mut vm, constructor, [Value.from_object(original)], object)!
		assert voidptr(created) != voidptr(original)
		assert voidptr(created.internal_get_prototype_of()?) == voidptr(if prototype.is_object() {
			custom
		} else {
			foreign.object_prototype_record()
		})
	}
	target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
		object_constructor_call, object_constructor_construct, 1, PropertyName.from_str('Abrupt'))
	mut abrupt := target.object
	abrupt.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, unsafe { nil }, 0, foreign.function_prototype)
	if _ := construct(mut vm, constructor, []Value{}, abrupt) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_object_property_definitions_preserve_descriptors_and_conversion_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_constructor_eval(mut vm, 'var o={};Object.defineProperty(o,"answer",{value:42});var d=Object.getOwnPropertyDescriptor(o,"answer");d.value+":"+d.writable+":"+d.enumerable+":"+d.configurable')!.as_string().str() == '42:false:false:false'
	assert object_constructor_eval(mut vm, 'var getter=function(){return 42};Object.defineProperty(o,"live",{get:getter,enumerable:true,configurable:true});var desc=Object.getOwnPropertyDescriptors(o);(desc.live.get===getter)+":"+o.live+":"+("value" in desc.live)')!.as_string().str() == 'true:42:false'
	assert object_constructor_eval(mut vm, 'var p={};var conversions=0;try{Object.defineProperty(1,{toString:function(){conversions++;return "x"}},{value:1})}catch(e){};conversions')!.number == 0
	assert object_constructor_eval(mut vm, 'try{Object.defineProperties(p,{first:{value:1},bad:{get:1}})}catch(e){};Object.hasOwn(p,"first")')!.as_bool() == false
	assert object_constructor_eval(mut vm, 'Object.defineProperty(p,"locked",{value:1});try{Object.defineProperties(p,{first:{value:2},locked:{value:3}})}catch(e){};p.first+":"+p.locked')!.as_string().str() == '2:1'
	assert object_constructor_eval(mut vm, 'var nullProto=Object.create(null,{answer:{value:42,enumerable:true}});(Object.getPrototypeOf(nullProto)===null)+":"+nullProto.answer+":"+Object.hasOwn(nullProto,"toString")')!.as_string().str() == 'true:42:false'
	assert object_constructor_eval(mut vm, 'Object.getOwnPropertyDescriptor("ab",0).value+":"+Object.getOwnPropertyDescriptor({},"missing")')!.as_string().str() == 'a:undefined'
	assert object_constructor_eval(mut vm, 'var symbol=Symbol("property");Object.defineProperty(p,symbol,{value:42});Object.getOwnPropertyDescriptors(p)[symbol].value+":"+Object.hasOwn(p,symbol)')!.as_string().str() == '42:true'
	assert object_constructor_eval(mut vm, 'var order="";var key={toString:function(){order+="k";return "converted"}};var attrs={};Object.defineProperty(attrs,"value",{get:function(){order+="v";return 42}});Object.defineProperty(p,key,attrs);order+":"+p.converted')!.as_string().str() == 'kv:42'
}

fn test_object_key_enumeration_uses_own_order_symbols_and_live_getters() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_constructor_eval(mut vm, 'var sym=Symbol("s");var source={b:2,2:20,1:10,a:1};source[sym]=42;Object.defineProperty(source,"hidden",{value:99});Object.keys(source).join(",")+":"+Object.getOwnPropertyNames(source).join(",")+":"+(Object.getOwnPropertySymbols(source)[0]===sym)')!.as_string().str() == '1,2,b,a:1,2,b,a,hidden:true'
	assert object_constructor_eval(mut vm, 'var seen="";var changes={};Object.defineProperty(changes,"first",{enumerable:true,get:function(){seen+="a";delete changes.last;changes.added=3;return 42}});changes.last=2;Object.keys(changes).join(",")+":"+seen')!.as_string().str() == 'first,last:'
	assert object_constructor_eval(mut vm, 'Object.values(changes).join(",")+":"+seen+":"+Object.entries({x:42})[0].join("=")')!.as_string().str() == '42:a:x=42'
	assert object_constructor_eval(mut vm, 'Object.keys("ab").join(",")+":"+Object.values("ab").join("")+":"+Object.keys(42).length')!.as_string().str() == '0,1:ab:0'
	assert object_constructor_eval(mut vm, 'var inherited=Object.create({other:1});inherited.own=42;Object.keys(inherited).join(",")+":"+("ab".hasOwnProperty(0))+":"+Object.getOwnPropertyDescriptor(inherited,"other")')!.as_string().str() == 'own:true:undefined'
}

fn test_object_assign_uses_setters_copies_symbols_and_retains_partial_writes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_constructor_eval(mut vm, 'var count=0;var target={};Object.defineProperty(target,"x",{set:function(v){count+=v}});var symbol=Symbol("key");var input={x:40,y:2};input[symbol]=42;var result=Object.assign(target,null,input,undefined);(result===target)+":"+(count+target.y)+":"+target[symbol]')!.as_string().str() == 'true:42:42'
	assert object_constructor_eval(mut vm, 'var locked={};Object.defineProperty(locked,"b",{value:9});try{Object.assign(locked,{a:1,b:2,c:3})}catch(e){};locked.a+":"+locked.b+":"+("c" in locked)')!.as_string().str() == '1:9:false'
	assert object_constructor_eval(mut vm, 'Object.assign({},"ab")[1]')!.as_string().str() == 'b'
	assert object_constructor_eval(mut vm, 'var inherited={};var proto={p:42};Object.defineProperty(inherited,"__proto__",{value:proto,enumerable:true});var assigned=Object.assign({},inherited);(Object.getPrototypeOf(assigned)===proto)+":"+Object.hasOwn(assigned,"__proto__")')!.as_string().str() == 'true:false'
}

fn test_object_prototype_integrity_and_same_value_methods() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert object_constructor_eval(mut vm, 'var parent={answer:42};var child={};Object.setPrototypeOf(child,parent);child.answer+":"+(Object.getPrototypeOf(child)===parent)+":"+Object.is(NaN,NaN)+":"+Object.is(0,-0)')!.as_string().str() == '42:true:true:false'
	assert object_constructor_eval(mut vm, 'var n=0;try{Object.setPrototypeOf(parent,child)}catch(e){n++};try{Object.setPrototypeOf(1,2)}catch(e){n++};Object.setPrototypeOf(1,null)+":"+n')!.as_string().str() == '1:2'
	assert object_constructor_eval(mut vm, 'var sealed=Object.seal({x:1});sealed.x=42;sealed.x+":"+Object.isSealed(sealed)+":"+Object.isFrozen(sealed)+":"+Object.isExtensible(sealed)')!.as_string().str() == '42:true:false:false'
	assert object_constructor_eval(mut vm, 'var frozen=Object.freeze({x:42});frozen.x=1;frozen.x+":"+Object.isFrozen(frozen)+":"+Object.isSealed(frozen)+":"+Object.isExtensible(frozen)')!.as_string().str() == '42:true:true:false'
	assert object_constructor_eval(mut vm, 'Object.isFrozen(1)+":"+Object.isSealed(null)+":"+Object.isExtensible(undefined)+":"+Object.freeze(42)+":"+Object.preventExtensions(null)')!.as_string().str() == 'true:true:false:42:null'
	assert object_constructor_eval(mut vm, 'var fixed=Object.preventExtensions({});try{Object.setPrototypeOf(fixed,{})}catch(e){n++};Object.setPrototypeOf(fixed,Object.getPrototypeOf(fixed))===fixed')!.as_bool()
	for source in ['Object.keys(null)', 'Object.getOwnPropertyDescriptor(undefined,"a")',
		'Object.create(1)', 'Object.setPrototypeOf(null,{})', 'Object.defineProperties({},null)'] {
		object_constructor_eval(mut vm, source) or {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			continue
		}
		assert false, source
	}
}

fn test_object_enumeration_is_bounded_by_the_callers_execution_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut many := Object.create(vm.realm(), none)
	for index in 0 .. 200 {
		many.define_direct_property(PropertyName.from_number(u32(index)), Value.from_i32(1), attribute_enumerable)
	}
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('many'), Value.from_object(many), 0)
	mut script := Script.parse('Object.entries(many)', vm.realm(), 'object-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 20 }) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert object_constructor_eval(mut vm, '6*7')!.number == 42
		return
	}
	assert false, 'Object.entries must share the caller instruction budget'
}
