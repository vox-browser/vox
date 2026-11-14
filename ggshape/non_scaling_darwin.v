module ggshape

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

import gg.canvas

fn non_scaling_matrix_is_affine(m [9]f32) bool {
	for value in m {
		if !is_finite(value) {
			return false
		}
	}
	return m[6] == 0 && m[7] == 0 && m[8] == 1
}

// transform_non_scaling_path mirrors SkPath::makeTransform() for affine
// matrices. SkMatrix maps the already-built path, including conic control
// points, rather than transforming the SVG tokens before arc conversion.
fn transform_non_scaling_path(path canvas.Path, m [9]f32) !canvas.Path {
	if !non_scaling_matrix_is_affine(m) {
		return error('non-scaling strokes require a finite affine matrix')
	}
	translate := m[0] == 1 && m[4] == 1 && m[1] == 0 && m[3] == 0
	if translate && m[2] == 0 && m[5] == 0 {
		return path
	}
	mut points := []canvas.Point{cap: path.points.len}
	for point in path.points {
		mapped := if translate {
			canvas.Point{point.x + m[2], point.y + m[5]}
		} else if m[1] == 0 && m[3] == 0 {
			// SkMatrix::Scale_pts(): multiply, then translate, without FMA.
			x := point.x * m[0]
			y := point.y * m[4]
			canvas.Point{x + m[2], y + m[5]}
		} else {
			// SkMatrix::Affine_vpts() sums the scale and skew before the
			// translation. Separate each product to match -ffp-contract=off.
			x_scale := point.x * m[0]
			x_skew := point.y * m[1]
			y_scale := point.y * m[4]
			y_skew := point.x * m[3]
			x := x_scale + x_skew
			y := y_scale + y_skew
			canvas.Point{x + m[2], y + m[5]}
		}
		if !is_finite(mapped.x) || !is_finite(mapped.y) {
			return error('non-finite transformed stroke geometry')
		}
		points << mapped
	}
	// SkPathData keeps its oval classification only when rectStaysRect().
	// Copying the path preserves its original verbs and oval metadata; a
	// general affine transform instead creates a general conic path.
	axis_aligned := (m[1] == 0 && m[3] == 0 && m[0] != 0 && m[4] != 0)
		|| (m[0] == 0 && m[4] == 0 && m[1] != 0 && m[3] != 0)
	if axis_aligned {
		return canvas.Path{
			...path
			points: points
		}
	}
	return canvas.Path{
		verbs:     path.verbs
		points:    points
		weights:   path.weights
		fill_type: path.fill_type
	}
}

// non_scaling_inverse follows SkMatrix::invert(), not Graphite Transform's
// 2x2 inverse. SVG image draws concatenate this inverse into an SkM44, so
// even its last float bits affect tessellation, clipping and gradient pixels.
fn non_scaling_inverse(m [9]f32) ?canvas.Matrix {
	mut inv := [9]f32{}
	if m[1] == 0 && m[3] == 0 {
		if m[0] == 1 && m[4] == 1 {
			if m[2] == 0 && m[5] == 0 {
				return canvas.Matrix.values(m)
			}
			return canvas.Matrix.translate(-m[2], -m[5])
		}
		if m[0] == 0 || m[4] == 0 {
			return none
		}
		sx := f32(1) / m[0]
		sy := f32(1) / m[4]
		inv = [sx, f32(0), -m[2] * sx, 0, sy, -m[5] * sy, 0, 0, 1]!
	} else {
		a := f64(m[0]) * f64(m[4])
		b := f64(m[1]) * f64(m[3])
		determinant := a - b
		// SK_ScalarNearlyZero cubed, as used by sk_inv_determinant().
		if abs_f32(f32(determinant)) <= f32(1.0 / 68719476736.0) {
			return none
		}
		scale := 1.0 / determinant
		tx0 := f64(m[1]) * f64(m[5])
		tx1 := f64(m[4]) * f64(m[2])
		ty0 := f64(m[3]) * f64(m[2])
		ty1 := f64(m[0]) * f64(m[5])
		tx := tx0 - tx1
		ty := ty0 - ty1
		inv = [f32(f64(m[4]) * scale), f32(-f64(m[1]) * scale), f32(tx * scale),
			f32(-f64(m[3]) * scale), f32(f64(m[0]) * scale), f32(ty * scale), 0, 0, 1]!
	}
	for value in inv {
		if !is_finite(value) {
			return none
		}
	}
	return canvas.Matrix.values(inv)
}
