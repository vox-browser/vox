module libjs

import math

@[heap]
struct MathTestLog { mut: closed int }

fn math_test_run(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'math.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_math_is_installed_with_intrinsic_ancestry_and_source_metadata() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	object := realm.math_object_record()
	assert realm.global_object_record().get(mut vm, PropertyName.from_str('Math'))!.as_object() == object
	assert object.internal_get_prototype_of()? == realm.object_prototype_record()
	for prototype in [realm.function_prototype_record(), realm.boolean_prototype_record(),
		realm.symbol_prototype_record(), realm.array_buffer_prototype_record(),
		realm.data_view_prototype_record(), realm.shared_array_buffer_prototype_record()] {
		assert prototype.internal_get_prototype_of()? == realm.object_prototype_record()
	}
	for name in ['E', 'LN2', 'LN10', 'LOG2E', 'LOG10E', 'PI', 'SQRT1_2', 'SQRT2'] {
		descriptor := object.internal_get_own_property(PropertyName.from_str(name))?
		assert !descriptor.writable? && !descriptor.enumerable? && !descriptor.configurable?
	}
	for name in ['abs', 'sqrt', 'ceil', 'floor', 'max', 'min', 'round', 'sumPrecise', 'f16round'] {
		descriptor := object.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		assert descriptor.value?.as_object().internal_get_prototype_of()? == realm.function_prototype_record()
	}
	assert math_test_run(mut vm, 'typeof Math;')!.as_string().utf16.str() == 'object'
	assert math_test_run(mut vm, 'Math.abs("-42");')!.number == 42
	assert math_test_run(mut vm, 'Math.imul(4294967295,5);')!.number == -5
	assert math_test_run(mut vm, 'Math.clz32(1);')!.number == 31
	assert math_test_run(mut vm, 'Math.hypot(3,4);')!.number == 5
	assert math_test_run(mut vm, 'Math.round(0.5);')!.number == 1
	assert math.signbit(math_test_run(mut vm, 'Math.round(-0.5);')!.number)
	assert math.signbit(math_test_run(mut vm, 'Math.min(0,-0);')!.number)
	assert !math.signbit(math_test_run(mut vm, 'Math.max(-0,0);')!.number)
	assert math.signbit(math_test_run(mut vm, 'Math.atan2(-0,1);')!.number)
	assert math_test_run(mut vm, 'Math.atan2(0,-0);')!.number == math.pi
	assert math_test_run(mut vm, 'Math.f16round(1.00048828125);')!.number == 1
	assert math_test_run(mut vm, 'Math.f16round(1.00146484375);')!.number == 1.001953125
	assert math_test_run(mut vm, 'Math.pow(NaN,0);')!.number == 1
	assert math.is_inf(math_test_run(mut vm, 'Math.hypot(NaN,Infinity);')!.number, 1)
}

fn test_math_random_uses_translated_xorshift_range_and_sequence() {
	mut rng := MathXorShift128Plus{ low: 1, high: 2 }
	assert rng.advance() == 8388646
	assert rng.advance() == 33816709
	for _ in 0 .. 1000 {
		value := math_random().number
		assert value >= 0 && value < 1
		assert math.floor(value * f64(u64(1) << 53)) == value * f64(u64(1) << 53)
	}
}

fn test_math_sum_precise_expansion_and_invalid_items_close_iterator() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut parent := Object.create(realm, realm.object_prototype_record())
	iterator_prototype := ArrayIteratorPrototype.create(mut vm, realm, parent, realm.object_prototype_record())
	values := [1e20, 1.0, -1e20, 3.0].map(Value.from_f64(it))
	array := ArrayObject.create_from(mut vm, realm, values, parent)!
	mut array_object := array.object
	iterator_fn := NativeFunction.create(mut vm, realm, realm.function_prototype,
		fn [iterator_prototype] (mut vm VM) !Value {
			return Value.from_object(ArrayIterator.create(vm.realm(), vm.this_value(),
				.value, iterator_prototype.object).object)
		}, 0, PropertyName.from_symbol(vm.well_known_symbol_iterator()), none)
	array_object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		Value.from_object(iterator_fn.object), 0)
	sum := realm.math_object_record().get(mut vm, PropertyName.from_str('sumPrecise'))!
	assert call(mut vm, sum, js_undefined(), [Value.from_object(array.object)])!.number == 4
	array_object.set(mut vm, PropertyName.from_number(0), Value.from_f64(math.max_f64), .yes)!
	array_object.set(mut vm, PropertyName.from_number(1), Value.from_f64(math.max_f64), .yes)!
	array_object.set(mut vm, PropertyName.from_number(2), Value.from_f64(-math.max_f64), .yes)!
	array_object.set(mut vm, PropertyName.from_number(3), Value.from_f64(0), .yes)!
	assert call(mut vm, sum, js_undefined(), [Value.from_object(array.object)])!.number == math.max_f64
	mut log := &MathTestLog{}
	mut iterator_parent := iterator_prototype.object
	return_method := NativeFunction.create(mut vm, realm, realm.function_prototype,
		fn [mut log] (mut vm VM) !Value { log.closed++; return Value.from_object(Object.create(vm.realm(), none)) },
		0, PropertyName.from_str('return'), none)
	iterator_parent.define_direct_property(PropertyName.from_str('return'), Value.from_object(return_method.object), 0)
	array_object.set(mut vm, PropertyName.from_number(0), Value.from_string(vm.create_string_from_str('1')), .yes)!
	if _ := call(mut vm, sum, js_undefined(), [Value.from_object(array.object)]) { assert false }
	else { assert thrown_value(err).as_object().error_kind()? == .type_error }
	assert log.closed == 1
}

fn math_methods_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'math-methods.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })!.as_string().str()
}

// Each method is its own native function: definition order, lengths, names,
// special values, NaN propagation and the variadic conversion order.
fn test_math_methods_keep_order_lengths_and_special_values() {
	assert math_methods_eval('Object.getOwnPropertyNames(Math).filter(function(k){return typeof Math[k]==="function"}).map(function(k){return k+Math[k].length+(Math[k].name===k?"":"!")}).join()')! == 'abs1,random0,sqrt1,floor1,ceil1,round1,max2,min2,trunc1,sin1,cos1,tan1,pow2,exp1,expm11,sign1,clz321,acos1,acosh1,asin1,asinh1,atan1,atanh1,log1p1,cbrt1,atan22,fround1,f16round1,hypot2,imul2,log1,log21,log101,sinh1,cosh1,tanh1,sumPrecise1'
	source := 'var fails=[];function check(label,actual,expected){if(!Object.is(actual,expected))fails.push(label+"="+actual)}
check("abs",Math.abs(-0),0);check("ceil",Math.ceil(-0.5),-0);check("floor",Math.floor(-0),-0);check("floor2",Math.floor(-2.5),-3);
check("sign",Math.sign(-0),-0);check("sign2",Math.sign(-3),-1);check("trunc",Math.trunc(-0.7),-0);check("round-",Math.round(-0.4),-0);
check("round2.5",Math.round(2.5),3);check("round-2.5",Math.round(-2.5),-2);check("rounds",Math.round("7"),7);
check("log0",Math.log(0),-Infinity);check("log2",Math.log2(8),3);check("log10",Math.log10(1),0);check("log10z",Math.log10(-0),-Infinity);check("log-1",Math.log(-1),NaN);
check("cos",Math.cos(Infinity),NaN);check("cos0",Math.cos(-0),1);check("cosh",Math.cosh(-Infinity),Infinity);check("sqrt-0",Math.sqrt(-0),-0);check("sqrt-1",Math.sqrt(-1),NaN);check("sqrt",Math.sqrt(16),4);
check("exp",Math.exp(-Infinity),0);check("exp0",Math.exp(-0),1);check("expm1",Math.expm1(-Infinity),-1);check("atanh",Math.atanh(1),Infinity);check("atanh2",Math.atanh(-2),NaN);check("tanh",Math.tanh(-Infinity),-1);
check("fround",Math.fround(5.05),5.050000190734863);check("clz32",Math.clz32(0),32);check("clz32b",Math.clz32(-1),0);check("sin",Math.sin(-0),-0);check("tan",Math.tan(Infinity),NaN);
check("asin",Math.asin(2),NaN);check("acos",Math.acos(1),0);check("acosh",Math.acosh(0.5),NaN);check("acosh1",Math.acosh(1),0);check("asinh",Math.asinh(-0),-0);check("atan",Math.atan(-Infinity),-Math.PI/2);
check("cbrt",Math.cbrt(-Infinity),-Infinity);check("log1p",Math.log1p(-1),-Infinity);check("log1p2",Math.log1p(-2),NaN);check("sinh",Math.sinh(-0),-0);check("f16",Math.f16round(-0),-0);check("f16b",Math.f16round(65520),Infinity);
check("max0",Math.max(),-Infinity);check("min0",Math.min(),Infinity);check("max",Math.max(1,"5",3),5);check("min",Math.min(4,-0,0),-0);check("hypot0",Math.hypot(),0);check("hypot-0",Math.hypot(-0),0);check("hypot",Math.hypot(-3,4),5);
check("pow",Math.pow(2,10),1024);check("atan2",Math.atan2(-0,-1),-Math.PI);check("imul",Math.imul(3,-4),-12);check("random",typeof Math.random(),"number");
["abs","sqrt","floor","ceil","round","trunc","sin","cos","tan","exp","expm1","sign","acos","acosh","asin","asinh","atan","atanh","log1p","cbrt","fround","f16round","log","log2","log10","sinh","cosh","tanh","pow","atan2","max","min","hypot"].forEach(function(k){check(k+"(NaN)",Math[k](NaN),NaN);if(k!=="max"&&k!=="min"&&k!=="hypot")check(k+"()",Math[k](),NaN)});
var log=[];function v(x){return {valueOf:function(){log.push(x);return x}}}
check("maxNaN",Math.max(v(1),v(NaN),v(3)),NaN);check("minNaN",Math.min(v(NaN),v(-1)),NaN);check("hypotInf",Math.hypot(v(NaN),v(Infinity),v(2)),Infinity);check("hypotNaN",Math.hypot(v(3),v(NaN),v(4)),NaN);
check("order",log.join(),"1,NaN,3,NaN,-1,NaN,Infinity,2,3,NaN,4");
var thrown;try{Math.min(NaN,{valueOf:function(){throw 7}})}catch(e){thrown=e}check("throw",thrown,7);
fails.join(";")'
	assert math_methods_eval(source)! == ''
}
