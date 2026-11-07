module layout

import css
import math

// PaintPropertyTreeBuilder::UpdateForPaintOffsetTranslation() rounds a
// transformed box's paint offset and keeps the fractional part only along
// axes that a scale-or-translation transform leaves unscaled; rotations
// discard it entirely. The box's content and its transform origin then both
// sit at the rounded offset. Returns the shift to that offset. Painted SVG
// roots already place their content there; GitHub's header carets are
// rotate(90deg) octicons at x=247.15625.
fn chromium_discarded_transform_subpixel_offset(matrix css.FloatMatrix4x4, x f64, y f64,
	scale f64) (f64, f64) {
	scale_or_translation := matrix.m12 == 0 && matrix.m21 == 0 && matrix.m13 == 0
		&& matrix.m23 == 0 && matrix.m31 == 0 && matrix.m32 == 0 && matrix.m41 == 0
		&& matrix.m42 == 0 && matrix.m43 == 0 && matrix.m44 == 1
	discard_x := !scale_or_translation || matrix.m11 != 1
	discard_y := !scale_or_translation || matrix.m22 != 1
	dx := if discard_x { math.round(x * scale) / scale - x } else { 0.0 }
	dy := if discard_y { math.round(y * scale) / scale - y } else { 0.0 }
	return dx, dy
}
