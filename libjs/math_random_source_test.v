module libjs

import json2
import math

pub struct MathRandomSourceCase {
pub:
	seeds []string
	bits  []string
}

fn test_source_random_splitmix_and_xorshift_match_actual_cpp_outputs() {
	cases := json2.decode[[]MathRandomSourceCase]($embed_file('math_random_source_cases.json').to_string())!
	for case_ in cases {
		mut rng := MathXorShift128Plus{
			low:  math_splitmix64(case_.seeds[0].u64())
			high: math_splitmix64(case_.seeds[1].u64())
		}
		for expected in case_.bits {
			value := rng.advance() & ((u64(1) << 53) - 1)
			actual := f64(value) * (1.0 / f64(u64(1) << 53))
			assert math.f64_bits(actual) == expected.u64()
		}
	}
}

fn test_source_random_native_entropy_constructor() {
	mut rng := MathXorShift128Plus{}
	rng.initialize()
	for _ in 0 .. 8 {
		value := rng.advance() & ((u64(1) << 53) - 1)
		assert f64(value) * (1.0 / f64(u64(1) << 53)) < 1
	}
	assert math_random().number >= 0
}
