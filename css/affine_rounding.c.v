// AK/Math.h::round_to<int>(float), used by Gfx::AffineTransform::map(IntPoint).
module css

#include "affine_rounding.h"

fn C.libweb_v_css_affine_round_to_int(value f32) int

fn affine_round_to_int(value f32) int {
	return C.libweb_v_css_affine_round_to_int(value)
}
