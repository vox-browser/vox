module cpuraster

import math

// SkCubics::RootsReal() results from Skia's SkCubics.cpp built with
// -ffp-contract=off, as libskia is. Fusing the solver's products into its
// sums, which clang does by default, changes the last bits of these roots.
fn test_cubic_roots_stay_unfused() {
	cases := [
		[u64(0x3febdcb10368cf70), 0xbfdd27a9d4b99ba0, 0xc0001456b0d2591c, 0xbfcce2514d67fb90,
			0xbff357d26da1b97e, 0x3ffd91f9b29beab4, 0xbfbdb1f330171d36],
		[u64(0x3ffa1274996d7120), 0x400312c87c246308, 0x4001f96bcda3bcec, 0x3fdbc3af04c9a4a0,
			0xbfcf9801a35d6b2c],
	]
	for c in cases {
		roots := cubics_roots_real(math.f64_from_bits(c[0]), math.f64_from_bits(c[1]),
			math.f64_from_bits(c[2]), math.f64_from_bits(c[3]))
		assert roots.map(math.f64_bits(it)) == c[4..]
	}
}
