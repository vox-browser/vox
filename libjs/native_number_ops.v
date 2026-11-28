module libjs

// ECMAScript discards the fraction and wraps the remaining bits. Keep shifts
// unsigned and reconstruct signed results without implementation-defined casts.
const native_number_helpers = '
static uint32_t uint32_bits(double n) {
 if(n > -2147483649.0 && n < 2147483648.0) return (uint32_t)(int32_t)n;
 if(!isfinite(n)) return 0;
 double bits=fmod(trunc(n),4294967296.0);
 return (uint32_t)(bits<0 ? bits+4294967296.0 : bits);
}
static int32_t signed_bits(uint32_t bits) {
 return bits<=INT32_MAX ? (int32_t)bits : -1-(int32_t)~bits;
}
static int32_t arithmetic_shift(uint32_t bits,uint32_t count) {
 return signed_bits(bits<=INT32_MAX ? bits>>count : ~(~bits>>count));
}
// libm pow covers the Number cases apart from these ECMAScript NaNs.
static double number_pow(double base,double exponent) {
 if(isnan(exponent) || (isinf(exponent) && fabs(base)==1)) return NAN;
 return pow(base,exponent);
}
'

fn native_number_binary(op OpCode, left string, right string) string {
	if op in [.bitwise_and, .bitwise_or, .bitwise_xor, .left_shift, .right_shift, .unsigned_right_shift] {
		a := 'uint32_bits(${left})'
		b := 'uint32_bits(${right})'
		return match op {
			.bitwise_and { 'num(signed_bits(${a}&${b}))' }
			.bitwise_or { 'num(signed_bits(${a}|${b}))' }
			.bitwise_xor { 'num(signed_bits(${a}^${b}))' }
			.left_shift { 'num(signed_bits(${a}<<(${b}&31)))' }
			.right_shift { 'num(arithmetic_shift(${a},${b}&31))' }
			else { 'num(${a}>>(${b}&31))' }
		}
	}
	return match op {
		.mod_ { 'num(fmod(${left},${right}))' }
		.exp { 'num(number_pow(${left},${right}))' }
		.add, .sub, .mul, .div { 'num(${left} ${native_number_operator(op)} ${right})' }
		else { 'boolean(${left} ${native_number_operator(op)} ${right})' }
	}
}
