module libjs

import math
import math.big

// LibCrypto/BigInt/UnsignedBigInteger.h. ECMAScriptNumberValueFor is the
// source's alias of IEEERoundAndTiesToEvenMantissa, represented by .ties_to_even.
enum BigIntDoubleRounding {
	ties_to_even
	toward_zero
}

// UnsignedBigInteger.cpp::to_double and SignedBigInteger.cpp::to_double.
// Preserve the top-53-bit extraction, exact remainder/half comparison and
// mantissa parity before ldexp. math.big supplies the integer operations.
fn big_integer_to_double(integer big.Integer, rounding BigIntDoubleRounding) f64 {
	magnitude := integer.abs()
	bitlen := magnitude.bit_len()
	sign := if integer.signum < 0 { f64(-1) } else { f64(1) }
	if bitlen <= 53 { return f64(big_integer_to_u64(magnitude)) * sign }
	shift := bitlen - 53
	mut shifted := magnitude.right_shift(u32(shift))
	if rounding == .toward_zero {
		return math.ldexp(f64(big_integer_to_u64(shifted)), shift) * sign
	}
	remainder := magnitude - shifted.left_shift(u32(shift))
	half := big.integer_from_int(1).left_shift(u32(shift - 1))
	if remainder > half || (remainder == half && big_integer_to_u64(shifted) & 1 != 0) {
		shifted = shifted + big.integer_from_int(1)
	}
	return math.ldexp(f64(big_integer_to_u64(shifted)), shift) * sign
}
