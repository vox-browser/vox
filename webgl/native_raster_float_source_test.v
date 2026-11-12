// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

import math

struct RasterFloatSourceCase {
	method string
	values [2]f32
	invert bool
}

fn raster_float_source_reset() {
	C.vox_gl_line_width(1)
	C.vox_gl_depth_range(0, 1)
	C.vox_gl_polygon_offset(0, 0)
	C.vox_gl_sample_coverage(1, 0)
	assert C.vox_gl_get_error() == no_error
}

fn raster_float_source_direct(operation RasterFloatSourceCase) {
	a := operation.values
	match operation.method {
		'line' { C.vox_gl_line_width(a[0]) }
		'depth' { C.vox_gl_depth_range(a[0], a[1]) }
		'polygon' { C.vox_gl_polygon_offset(a[0], a[1]) }
		else { C.vox_gl_sample_coverage(a[0], int(operation.invert)) }
	}
}

fn raster_float_source_state() []f32 {
	mut values := []f32{}
	for pname in [line_width, depth_range, polygon_offset_factor, polygon_offset_units,
		sample_coverage_value, sample_coverage_invert] {
		mut result := [f32(0), 0]!
		C.vox_gl_float_parameter(pname, &result[0])
		values << result[0]
		if pname == depth_range { values << result[1] }
	}
	return values
}

fn test_source_float_raster_setters_pass_exact_float_abi_to_owning_actual_driver() {
	nan := f32(math.nan())
	positive_infinity := f32(math.inf(1))
	negative_infinity := f32(math.inf(-1))
	operations := [
		RasterFloatSourceCase{'line', [f32(0), 0]!, false},
		RasterFloatSourceCase{'line', [f32(-1), 0]!, false},
		RasterFloatSourceCase{'line', [f32(1.5), 0]!, false},
		RasterFloatSourceCase{'line', [nan, f32(0)]!, false},
		RasterFloatSourceCase{'line', [positive_infinity, f32(0)]!, false},
		RasterFloatSourceCase{'line', [negative_infinity, f32(0)]!, false},
		RasterFloatSourceCase{'depth', [f32(-2), 3]!, false},
		RasterFloatSourceCase{'depth', [f32(0.8), 0.2]!, false},
		RasterFloatSourceCase{'depth', [nan, f32(0.75)]!, false},
		RasterFloatSourceCase{'depth', [negative_infinity, positive_infinity]!, false},
		RasterFloatSourceCase{'polygon', [f32(0.125), -2.75]!, false},
		RasterFloatSourceCase{'polygon', [nan, positive_infinity]!, false},
		RasterFloatSourceCase{'polygon', [negative_infinity, nan]!, false},
		RasterFloatSourceCase{'sample', [f32(0.625), 0]!, true},
		RasterFloatSourceCase{'sample', [f32(-2), 0]!, true},
		RasterFloatSourceCase{'sample', [nan, f32(0)]!, true},
		RasterFloatSourceCase{'sample', [positive_infinity, f32(0)]!, false},
	]
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		for operation in operations {
			context.native.make_current()
			raster_float_source_reset()
			raster_float_source_direct(operation)
			expected_error := C.vox_gl_get_error()
			expected := raster_float_source_state()
			raster_float_source_reset()
			context.set_error(invalid_operation)
			other.native.make_current()
			a := operation.values
			match operation.method {
				'line' { context.line_width(a[0]) }
				'depth' { context.depth_range(a[0], a[1]) }
				'polygon' { context.polygon_offset(a[0], a[1]) }
				else { context.sample_coverage(a[0], operation.invert) }
			}
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			actual := raster_float_source_state()
			for index, value in expected {
				assert actual[index] == value || (math.is_nan(actual[index]) && math.is_nan(value))
			}
			if expected_error != no_error {
				assert context.get_error() == expected_error
			}
			assert context.get_error() == invalid_operation
			assert context.get_error() == no_error
		}
		assert other.get_error() == no_error
	}
}
