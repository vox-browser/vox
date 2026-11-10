module libjs

import math

#include "@DIR/math_random_entropy.h"

fn C.vox_ak_random_seed_u64() u64

// Runtime/MathObject.{h,cpp}. Native numeric approximations use the same libm
// operations as upstream; coercion, signed-zero and exceptional branches stay
// in the translated method bodies. XorShift128PlusRNG comes from AK/Random.cpp.
@[heap]
pub struct MathObject {
pub:
	object &Object
}

pub fn MathObject.create(mut vm VM, realm &Realm, object_prototype &Object) &MathObject {
	mut object := Object.create(realm, object_prototype)
	names := ['abs', 'random', 'sqrt', 'floor', 'ceil', 'round', 'max', 'min', 'trunc',
		'sin', 'cos', 'tan', 'pow', 'exp', 'expm1', 'sign', 'clz32', 'acos', 'acosh',
		'asin', 'asinh', 'atan', 'atanh', 'log1p', 'cbrt', 'atan2', 'fround', 'f16round',
		'hypot', 'imul', 'log', 'log2', 'log10', 'sinh', 'cosh', 'tanh', 'sumPrecise']
	for name in names {
		length := if name == 'random' { 0 } else if name in ['max', 'min', 'pow', 'atan2', 'hypot', 'imul'] { 2 } else { 1 }
		function := NativeFunction.create(mut vm, realm, realm.function_prototype,
			fn [name] (mut vm VM) !Value { return math_object_method(mut vm, name) }, length,
			PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object),
			attribute_writable | attribute_configurable)
	}
	constant_names := ['E', 'LN2', 'LN10', 'LOG2E', 'LOG10E', 'PI', 'SQRT1_2', 'SQRT2']
	constant_values := [math.e, math.ln2, math.ln10, math.log2(math.e), math.log10(math.e),
		math.pi, math.sqrt(0.5), math.sqrt2]
	for index, name in constant_names { object.define_direct_property(PropertyName.from_str(name), Value.from_f64(constant_values[index]), 0) }
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('Math')), attribute_configurable)
	return &MathObject{ object: object }
}

struct MathXorShift128Plus {
mut:
	low u64
	high u64
}

__global math_random_generator = &MathXorShift128Plus{}
__global math_random_initialized bool

// AK/Random.cpp's constructor obtains two independent native CSPRNG draws.
fn (mut rng MathXorShift128Plus) initialize() {
	first := C.vox_ak_random_seed_u64()
	rng.low = math_splitmix64(first)
	second := C.vox_ak_random_seed_u64()
	rng.high = math_splitmix64(second)
}

fn math_splitmix64(value u64) u64 {
	mut z := value + u64(0x9e3779b97f4a7c15)
	z = (z ^ (z >> 30)) * u64(0xbf58476d1ce4e5b9)
	z = (z ^ (z >> 27)) * u64(0x94d049bb133111eb)
	return z ^ (z >> 31)
}

fn (mut rng MathXorShift128Plus) advance() u64 {
	mut s1 := rng.low
	s0 := rng.high
	result := s0 + s1
	rng.low = s0
	s1 ^= s1 << 23
	s1 ^= s1 >> 18
	s1 ^= s0 ^ (s0 >> 5)
	rng.high = s1
	return result + s1
}

fn math_random() Value {
	if !math_random_initialized {
		math_random_generator.initialize()
		math_random_initialized = true
	}
	value := math_random_generator.advance() & ((u64(1) << 53) - 1)
	return Value.from_f64(f64(value) * (1.0 / f64(u64(1) << 53)))
}

fn math_object_method(mut vm VM, name string) !Value {
	if name == 'random' { return math_random() }
	if name == 'sumPrecise' { return math_sum_precise(mut vm) }
	if name in ['max', 'min', 'hypot'] { return math_variadic(mut vm, name) }
	if name == 'clz32' {
		n := vm.argument(0).to_u32(mut vm)!
		mut count := 0
		for bit := 31; bit >= 0; bit-- { if (n & (u32(1) << bit)) != 0 { break }; count++ }
		return Value.from_i32(count)
	}
	if name == 'imul' {
		a := vm.argument(0).to_u32(mut vm)!
		b := vm.argument(1).to_u32(mut vm)!
		return Value.from_i32(i32(a * b))
	}
	number := vm.argument(0).to_number(mut vm)!
	n := number.number
	if name == 'pow' { return exp(mut vm, number, vm.argument(1).to_number(mut vm)!) }
	if name == 'atan2' { return math_atan2(n, vm.argument(1).to_number(mut vm)!.number) }
	if math.is_nan(n) { return Value.from_f64(math.nan()) }
	return match name {
		'abs' { Value.from_f64(if n == 0 { 0.0 } else if n < 0 { -n } else { n }) }
		'acos' { Value.from_f64(if n < -1 || n > 1 { math.nan() } else if n == 1 { 0.0 } else { math.acos(n) }) }
		'acosh' { Value.from_f64(if math.is_inf(n, 1) { n } else if n == 1 { 0.0 } else if n < 1 { math.nan() } else { math.acosh(n) }) }
		'asin' { Value.from_f64(if n == 0 { n } else if n < -1 || n > 1 { math.nan() } else { math.asin(n) }) }
		'asinh' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else { math.asinh(n) }) }
		'atan' { Value.from_f64(if n == 0 { n } else if math.is_inf(n, 1) { math.pi / 2 } else if math.is_inf(n, -1) { -math.pi / 2 } else { math.atan(n) }) }
		'atanh' { Value.from_f64(if n == 0 { n } else if n < -1 || n > 1 { math.nan() } else if n == 1 { math.inf(1) } else if n == -1 { math.inf(-1) } else { math.atanh(n) }) }
		'cbrt' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else { math.cbrt(n) }) }
		'ceil' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else if n < 0 && n > -1 { math.f64_from_bits(u64(1) << 63) } else { math.ceil(n) }) }
		'cos' { Value.from_f64(if math.is_inf(n, 0) { math.nan() } else if n == 0 { 1.0 } else { math.cos(n) }) }
		'cosh' { Value.from_f64(if math.is_inf(n, 0) { math.inf(1) } else if n == 0 { 1.0 } else { math.cosh(n) }) }
		'exp' { Value.from_f64(if n == 0 { 1.0 } else if math.is_inf(n, -1) { 0.0 } else if math.is_inf(n, 1) { n } else { math.exp(n) }) }
		'expm1' { Value.from_f64(if n == 0 || math.is_inf(n, 1) { n } else if math.is_inf(n, -1) { -1.0 } else { math.expm1(n) }) }
		'floor' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else { math.floor(n) }) }
		'fround' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else { f64(f32(n)) }) }
		'f16round' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else { float16_from_bits(float16_bits(n)) }) }
		'log', 'log2', 'log10' { Value.from_f64(if math.is_inf(n, 1) { n } else if n == 1 { 0.0 } else if n == 0 { math.inf(-1) } else if n < 0 { math.nan() } else if name == 'log2' { math.log2(n) } else if name == 'log10' { math.log10(n) } else { math.log(n) }) }
		'log1p' { Value.from_f64(if n == 0 || math.is_inf(n, 1) { n } else if n == -1 { math.inf(-1) } else if n < -1 { math.nan() } else { math.log1p(n) }) }
		'round' {
			if math.is_inf(n, 0) || n == math.trunc(n) { number }
			else { mut integer := math.ceil(n); if integer - 0.5 > n { integer-- }; Value.from_f64(integer) }
		}
		'sign' { Value.from_f64(if n == 0 { n } else if n < 0 { -1.0 } else { 1.0 }) }
		'sin', 'tan' { Value.from_f64(if n == 0 { n } else if math.is_inf(n, 0) { math.nan() } else if name == 'sin' { math.sin(n) } else { math.tan(n) }) }
		'sinh' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else { math.sinh(n) }) }
		'sqrt' { Value.from_f64(if n == 0 || math.is_inf(n, 1) { n } else if n < 0 { math.nan() } else { math.sqrt(n) }) }
		'tanh' { Value.from_f64(if n == 0 { n } else if math.is_inf(n, 1) { 1.0 } else if math.is_inf(n, -1) { -1.0 } else { math.tanh(n) }) }
		'trunc' { Value.from_f64(if n == 0 || math.is_inf(n, 0) { n } else if n < 0 { math.ceil(n) } else { math.floor(n) }) }
		else { panic('Unknown Math intrinsic method') }
	}
}

// The upstream variadic methods collect all conversions before inspecting NaN
// or infinity, preserving observable conversion side effects and exceptions.
fn math_variadic(mut vm VM, name string) !Value {
	mut coerced := []f64{}
	for index in 0 .. vm.argument_count() { coerced << vm.argument(index).to_number(mut vm)!.number }
	if name == 'hypot' { for number in coerced { if math.is_inf(number, 0) { return Value.from_f64(math.inf(1)) } } }
	mut result := if name == 'max' { math.inf(-1) } else if name == 'min' { math.inf(1) } else { 0.0 }
	for number in coerced {
		if math.is_nan(number) { return Value.from_f64(math.nan()) }
		// Ladybird 85afacea93a8: hypot scales before squaring, avoiding
		// intermediate overflow/underflow and retaining positive zero.
		if name == 'hypot' { result = math.hypot(result, number) }
		else if name == 'max' {
			if (number == 0 && !math.signbit(number) && result == 0 && math.signbit(result)) || number > result { result = number }
		} else if (number == 0 && math.signbit(number) && result == 0 && !math.signbit(result)) || number < result { result = number }
	}
	return Value.from_f64(result)
}

fn math_atan2(y f64, x f64) Value {
	if math.is_nan(y) || math.is_nan(x) { return Value.from_f64(math.nan()) }
	if math.is_inf(y, 1) { return Value.from_f64(if math.is_inf(x, 1) { math.pi / 4 } else if math.is_inf(x, -1) { 3 * math.pi / 4 } else { math.pi / 2 }) }
	if math.is_inf(y, -1) { return Value.from_f64(if math.is_inf(x, 1) { -math.pi / 4 } else if math.is_inf(x, -1) { -3 * math.pi / 4 } else { -math.pi / 2 }) }
	if y == 0 {
		if x > 0 || (x == 0 && !math.signbit(x)) { return Value.from_f64(y) }
		return Value.from_f64(if math.signbit(y) { -math.pi } else { math.pi })
	}
	if y > 0 { return Value.from_f64(if math.is_inf(x, 1) { 0.0 } else if math.is_inf(x, -1) { math.pi } else if x == 0 { math.pi / 2 } else { math.atan2(y, x) }) }
	return Value.from_f64(if math.is_inf(x, 1) { math.f64_from_bits(u64(1) << 63) } else if math.is_inf(x, -1) { -math.pi } else if x == 0 { -math.pi / 2 } else { math.atan2(y, x) })
}
