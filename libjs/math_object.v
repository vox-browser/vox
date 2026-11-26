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
	// MathObject::initialize's define_native_function order; each method has
	// its own native behaviour, as upstream's MathObject::abs etc. do.
	methods := [
		math_method('abs', 1, math_abs), math_method('random', 0, math_random_method),
		math_method('sqrt', 1, math_sqrt), math_method('floor', 1, math_floor),
		math_method('ceil', 1, math_ceil), math_method('round', 1, math_round),
		math_method('max', 2, math_max), math_method('min', 2, math_min),
		math_method('trunc', 1, math_trunc), math_method('sin', 1, math_sin),
		math_method('cos', 1, math_cos), math_method('tan', 1, math_tan),
		math_method('pow', 2, math_pow), math_method('exp', 1, math_exp),
		math_method('expm1', 1, math_expm1), math_method('sign', 1, math_sign),
		math_method('clz32', 1, math_clz32), math_method('acos', 1, math_acos),
		math_method('acosh', 1, math_acosh), math_method('asin', 1, math_asin),
		math_method('asinh', 1, math_asinh), math_method('atan', 1, math_atan),
		math_method('atanh', 1, math_atanh), math_method('log1p', 1, math_log1p),
		math_method('cbrt', 1, math_cbrt), math_method('atan2', 2, math_atan2_method),
		math_method('fround', 1, math_fround), math_method('f16round', 1, math_f16round),
		math_method('hypot', 2, math_hypot), math_method('imul', 2, math_imul),
		math_method('log', 1, math_log), math_method('log2', 1, math_log2),
		math_method('log10', 1, math_log10), math_method('sinh', 1, math_sinh),
		math_method('cosh', 1, math_cosh), math_method('tanh', 1, math_tanh),
		math_method('sumPrecise', 1, math_sum_precise),
	]
	for method in methods {
		function := NativeFunction.create(mut vm, realm, realm.function_prototype, method.behaviour,
			method.length, PropertyName.from_str(method.name), none)
		object.define_direct_property(PropertyName.from_str(method.name), Value.from_object(function.object),
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

struct MathMethod {
	name      string
	length    f64
	behaviour NativeFunctionPointer = unsafe { nil }
}

fn math_method(name string, length f64, behaviour NativeFunctionPointer) MathMethod {
	return MathMethod{ name: name, length: length, behaviour: behaviour }
}

// The single-argument methods: ToNumber(x), then NaN yields NaN.
@[inline]
fn math_unary(mut vm VM, operation fn (f64) f64) !Value {
	n := vm.argument(0).to_number(mut vm)!.number
	if math.is_nan(n) { return Value.from_f64(math.nan()) }
	return Value.from_f64(operation(n))
}

fn math_abs(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { 0.0 } else if n < 0 { -n } else { n } })
}

fn math_acos(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n < -1 || n > 1 { math.nan() } else if n == 1 { 0.0 } else { math.acos(n) } })
}

fn math_acosh(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if math.is_inf(n, 1) { n } else if n == 1 { 0.0 } else if n < 1 { math.nan() } else { math.acosh(n) } })
}

fn math_asin(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { n } else if n < -1 || n > 1 { math.nan() } else { math.asin(n) } })
}

fn math_asinh(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else { math.asinh(n) } })
}

fn math_atan(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { n } else if math.is_inf(n, 1) { math.pi / 2 } else if math.is_inf(n, -1) { -math.pi / 2 } else { math.atan(n) } })
}

fn math_atanh(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { n } else if n < -1 || n > 1 { math.nan() } else if n == 1 { math.inf(1) } else if n == -1 { math.inf(-1) } else { math.atanh(n) } })
}

fn math_cbrt(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else { math.cbrt(n) } })
}

fn math_ceil(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else if n < 0 && n > -1 { math.f64_from_bits(u64(1) << 63) } else { math.ceil(n) } })
}

fn math_cos(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if math.is_inf(n, 0) { math.nan() } else if n == 0 { 1.0 } else { math.cos(n) } })
}

fn math_cosh(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if math.is_inf(n, 0) { math.inf(1) } else if n == 0 { 1.0 } else { math.cosh(n) } })
}

fn math_exp(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { 1.0 } else if math.is_inf(n, -1) { 0.0 } else if math.is_inf(n, 1) { n } else { math.exp(n) } })
}

fn math_expm1(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 1) { n } else if math.is_inf(n, -1) { -1.0 } else { math.expm1(n) } })
}

fn math_floor(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else { math.floor(n) } })
}

fn math_fround(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else { f64(f32(n)) } })
}

fn math_f16round(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else { float16_from_bits(float16_bits(n)) } })
}

// log, log2 and log10 share the special values for +Infinity, 1, 0 and
// negative arguments.
@[inline]
fn math_logarithm(n f64, logarithm fn (f64) f64) f64 {
	return if math.is_inf(n, 1) { n } else if n == 1 { 0.0 } else if n == 0 { math.inf(-1) } else if n < 0 { math.nan() } else { logarithm(n) }
}

fn math_log(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return math_logarithm(n, math.log) })
}

fn math_log2(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return math_logarithm(n, math.log2) })
}

fn math_log10(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return math_logarithm(n, math.log10) })
}

fn math_log1p(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 1) { n } else if n == -1 { math.inf(-1) } else if n < -1 { math.nan() } else { math.log1p(n) } })
}

// Integral results return the converted number itself, keeping its
// representation; other values round half up.
fn math_round(mut vm VM) !Value {
	number := vm.argument(0).to_number(mut vm)!
	n := number.number
	if math.is_nan(n) { return Value.from_f64(math.nan()) }
	if math.is_inf(n, 0) || n == math.trunc(n) { return number }
	mut integer := math.ceil(n)
	if integer - 0.5 > n { integer-- }
	return Value.from_f64(integer)
}

fn math_sign(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { n } else if n < 0 { -1.0 } else { 1.0 } })
}

fn math_sin(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { n } else if math.is_inf(n, 0) { math.nan() } else { math.sin(n) } })
}

fn math_tan(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { n } else if math.is_inf(n, 0) { math.nan() } else { math.tan(n) } })
}

fn math_sinh(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else { math.sinh(n) } })
}

fn math_sqrt(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 1) { n } else if n < 0 { math.nan() } else { math.sqrt(n) } })
}

fn math_tanh(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 { n } else if math.is_inf(n, 1) { 1.0 } else if math.is_inf(n, -1) { -1.0 } else { math.tanh(n) } })
}

fn math_trunc(mut vm VM) !Value {
	return math_unary(mut vm, fn (n f64) f64 { return if n == 0 || math.is_inf(n, 0) { n } else if n < 0 { math.ceil(n) } else { math.floor(n) } })
}

fn math_random_method(mut vm VM) !Value {
	return math_random()
}

fn math_clz32(mut vm VM) !Value {
	n := vm.argument(0).to_u32(mut vm)!
	mut count := 0
	for bit := 31; bit >= 0; bit-- { if (n & (u32(1) << bit)) != 0 { break }; count++ }
	return Value.from_i32(count)
}

fn math_imul(mut vm VM) !Value {
	a := vm.argument(0).to_u32(mut vm)!
	b := vm.argument(1).to_u32(mut vm)!
	return Value.from_i32(i32(a * b))
}

fn math_pow(mut vm VM) !Value {
	base := vm.argument(0).to_number(mut vm)!
	return exp(mut vm, base, vm.argument(1).to_number(mut vm)!)
}

fn math_atan2_method(mut vm VM) !Value {
	y := vm.argument(0).to_number(mut vm)!.number
	return math_atan2(y, vm.argument(1).to_number(mut vm)!.number)
}

// The upstream variadic methods convert every argument before inspecting NaN
// or infinity, preserving observable conversion side effects and exceptions.
// Once a NaN (or, for hypot, an infinity) decides the result, the remaining
// arguments are still converted but no longer compared.
fn math_max(mut vm VM) !Value {
	mut result := math.inf(-1)
	mut saw_nan := false
	for index in 0 .. vm.argument_count() {
		number := vm.argument(index).to_number(mut vm)!.number
		if saw_nan { continue }
		if math.is_nan(number) { saw_nan = true; continue }
		if (number == 0 && !math.signbit(number) && result == 0 && math.signbit(result)) || number > result { result = number }
	}
	return Value.from_f64(if saw_nan { math.nan() } else { result })
}

fn math_min(mut vm VM) !Value {
	mut result := math.inf(1)
	mut saw_nan := false
	for index in 0 .. vm.argument_count() {
		number := vm.argument(index).to_number(mut vm)!.number
		if saw_nan { continue }
		if math.is_nan(number) { saw_nan = true; continue }
		if (number == 0 && math.signbit(number) && result == 0 && !math.signbit(result)) || number < result { result = number }
	}
	return Value.from_f64(if saw_nan { math.nan() } else { result })
}

fn math_hypot(mut vm VM) !Value {
	mut result := 0.0
	mut saw_infinity := false
	mut saw_nan := false
	for index in 0 .. vm.argument_count() {
		number := vm.argument(index).to_number(mut vm)!.number
		if math.is_inf(number, 0) {
			saw_infinity = true
		} else if math.is_nan(number) {
			saw_nan = true
		} else if !saw_infinity && !saw_nan {
			// Ladybird 85afacea93a8: hypot scales before squaring, avoiding
			// intermediate overflow/underflow and retaining positive zero.
			result = math.hypot(result, number)
		}
	}
	if saw_infinity { return Value.from_f64(math.inf(1)) }
	if saw_nan { return Value.from_f64(math.nan()) }
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
