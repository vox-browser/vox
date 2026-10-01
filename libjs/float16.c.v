module libjs

#flag -I @DIR
#include "float16.h"

fn C.vox2_libjs_float16_bits(number f64) u16
fn C.vox2_libjs_float16_from_bits(bits u16) f64

fn float16_bits(number f64) u16 {
	return C.vox2_libjs_float16_bits(number)
}

fn float16_from_bits(bits u16) f64 {
	return C.vox2_libjs_float16_from_bits(bits)
}
