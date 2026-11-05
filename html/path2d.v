// Copyright (c) 2023, MacDue <macdue@dueutil.tech>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Path2D.cpp.
// Path2D is a PlatformObject that also mixes in CanvasPath; here it embeds CanvasPath and gains
// all of its path-building methods.
module html

import math
import svg

// https://html.spec.whatwg.org/multipage/canvas.html#path2d
@[heap]
pub struct Path2D {
	CanvasPath
}

pub type Path2DConstructorArgument = Path2D | string

pub fn Path2D.construct_impl(path ?Path2DConstructorArgument) !&Path2D {
	argument := path or { return Path2D.create() }
	match argument {
		Path2D {
			return Path2D.create_from_path(&argument)
		}
		string {
			return Path2D.create_from_svg_path_data(argument)
		}
	}
}

// path is not given → an empty Path2D.
pub fn Path2D.create() &Path2D {
	return &Path2D{}
}

// path is a Path2D → a copy of its subpaths.
pub fn Path2D.create_from_path(other &Path2D) &Path2D {
	mut output := &Path2D{}
	output.CanvasPath.set_path(other.path())
	return output
}

// path is a string → parse as SVG 2 path data.
pub fn Path2D.create_from_svg_path_data(path_data string) &Path2D {
	path_instructions := svg.parse_path_data(path_data)
	svg_path := svg_path_to_canvas_gfx_path(path_instructions)
	mut output := &Path2D{}
	if !svg_path.is_empty() {
		// Preserve the last point before moving the path into output: the final
		// move_to is a new one-point subpath required by Path2D's constructor.
		last_point := svg_path.last_point()
		output.CanvasPath.set_path(svg_path)
		output.move_to(last_point.x, last_point.y)
	}
	return output
}

fn svg_path_scalar(value f64, single_precision bool) f64 {
	return if single_precision { f64(f32(value)) } else { value }
}

fn svg_path_point(data []f64, offset int, current FloatPoint, absolute bool, single_precision bool) FloatPoint {
	mut point := FloatPoint{svg_path_scalar(data[offset], single_precision), svg_path_scalar(data[offset + 1], single_precision)}
	if !absolute {
		point = FloatPoint{svg_path_scalar(point.x + current.x, single_precision), svg_path_scalar(point.y + current.y, single_precision)}
	}
	return point
}

fn svg_path_reflected_control(current FloatPoint, previous FloatPoint, single_precision bool) FloatPoint {
	if !single_precision {
		return FloatPoint{2 * current.x - previous.x, 2 * current.y - previous.y}
	}
	// Blink's SVGPathBuilder reflects PointF as current + (current - control).
	// Round the subtraction before adding; converting only the final packed
	// segment loses the current point used by subsequent relative commands.
	return FloatPoint{svg_path_scalar(current.x + svg_path_scalar(current.x - previous.x, true), true), svg_path_scalar(current.y + svg_path_scalar(current.y - previous.y, true), true)}
}

// Literal translation of SVG::Path::to_gfx_path(), used by Path2D's string
// constructor. Keeping this conversion here avoids making the SVG package
// depend on HTML's Gfx-path model.
fn svg_path_to_canvas_gfx_path(path svg.Path) CanvasGfxPath {
	return svg_path_to_canvas_gfx_path_with_precision(path, false)
}

fn svg_path_to_canvas_gfx_path_with_precision(path svg.Path, single_precision bool) CanvasGfxPath {
	mut output := CanvasGfxPath{}
	mut previous_control_point := ?FloatPoint(none)
	mut last_instruction := ?svg.PathInstructionType(none)
	for instruction in path.instructions {
		last_point := output.last_point()
		mut clear_last_control_point := true
		match instruction.type_ {
			.move {
				output.move_to(svg_path_point(instruction.data, 0, last_point, instruction.absolute, single_precision))
			}
			.close_path {
				output.close()
			}
			.line {
				output.line_to(svg_path_point(instruction.data, 0, last_point, instruction.absolute, single_precision))
			}
			.horizontal_line {
				x := svg_path_scalar(svg_path_scalar(instruction.data[0], single_precision) + if instruction.absolute {
					0.0
				} else {
					last_point.x
				}, single_precision)
				output.line_to(FloatPoint{x, last_point.y})
			}
			.vertical_line {
				y := svg_path_scalar(svg_path_scalar(instruction.data[0], single_precision) + if instruction.absolute {
					0.0
				} else {
					last_point.y
				}, single_precision)
				output.line_to(FloatPoint{last_point.x, y})
			}
			.elliptical_arc {
				next_point := svg_path_point(instruction.data, 5, last_point, instruction.absolute, single_precision)
				output.elliptical_arc_to(next_point, FloatSize{svg_path_scalar(instruction.data[0], single_precision), svg_path_scalar(instruction.data[1], single_precision)}, svg_path_scalar(instruction.data[2], single_precision) * math.pi / 180.0, instruction.data[3] != 0, instruction.data[4] != 0)
			}
			.quadratic_bezier_curve {
				clear_last_control_point = false
				control_point := svg_path_point(instruction.data, 0, last_point, instruction.absolute, single_precision)
				end_point := svg_path_point(instruction.data, 2, last_point, instruction.absolute, single_precision)
				output.quadratic_bezier_curve_to(control_point, end_point)
				previous_control_point = control_point
			}
			.smooth_quadratic_bezier_curve {
				clear_last_control_point = false
				last_was_quadratic := if previous := last_instruction {
					previous in [.quadratic_bezier_curve, .smooth_quadratic_bezier_curve]
				} else {
					false
				}
				if previous_control_point == none || !last_was_quadratic {
					previous_control_point = last_point
				}
				previous := previous_control_point or { last_point }
				control_point :=
					svg_path_reflected_control(last_point, previous, single_precision)
				end_point := svg_path_point(instruction.data, 0, last_point, instruction.absolute, single_precision)
				output.quadratic_bezier_curve_to(control_point, end_point)
				previous_control_point = control_point
			}
			.curve {
				clear_last_control_point = false
				control_point_1 := svg_path_point(instruction.data, 0, last_point, instruction.absolute, single_precision)
				control_point_2 := svg_path_point(instruction.data, 2, last_point, instruction.absolute, single_precision)
				end_point := svg_path_point(instruction.data, 4, last_point, instruction.absolute, single_precision)
				output.cubic_bezier_curve_to(control_point_1, control_point_2, end_point)
				previous_control_point = control_point_2
			}
			.smooth_curve {
				clear_last_control_point = false
				last_was_curve := if previous := last_instruction {
					previous in [.curve, .smooth_curve]
				} else {
					false
				}
				if previous_control_point == none || !last_was_curve {
					previous_control_point = last_point
				}
				previous := previous_control_point or { last_point }
				control_point_1 :=
					svg_path_reflected_control(last_point, previous, single_precision)
				control_point_2 := svg_path_point(instruction.data, 0, last_point, instruction.absolute, single_precision)
				end_point := svg_path_point(instruction.data, 2, last_point, instruction.absolute, single_precision)
				output.cubic_bezier_curve_to(control_point_1, control_point_2, end_point)
				previous_control_point = control_point_2
			}
		}
		if clear_last_control_point {
			previous_control_point = FloatPoint{}
		}
		last_instruction = instruction.type_
	}
	return output
}

// SVGPathPaintable and SVGMaskable retain SVG::Path until display-list
// recording. Expose the same SVG::Path::to_gfx_path() translation used by the
// Path2D constructor so layout/painting do not serialize and parse path data a
// second time merely to recover exact curves.
pub fn canvas_gfx_path_from_svg_path(path svg.Path) CanvasGfxPath {
	return svg_path_to_canvas_gfx_path(path)
}

// The browser's Chromium painting policy uses float path operands and updates
// the float current/control points after each operation. Keep the ordinary
// Path2D/portable conversion's precision independent of this raster policy.
pub fn canvas_gfx_path_from_svg_path_with_precision(path svg.Path, single_precision bool) CanvasGfxPath {
	return svg_path_to_canvas_gfx_path_with_precision(path, single_precision)
}

// https://html.spec.whatwg.org/multipage/canvas.html#dom-path2d-addpath
// The DOMMatrix2DInit transform is represented as an already-built CanvasAffineTransform
// (m11/m12/m21/m22/m41/m42 → a/b/c/d/e/f); building the matrix from the dictionary is binding-layer.
pub fn (mut a Path2D) add_path(path &Path2D, transform CanvasAffineTransform) {
	// 1. If path has no subpaths, then return.
	if path.path().is_empty() {
		return
	}
	// 3. If any of the transform's used components are infinite or NaN, then return.
	if !is_finite(transform.a) || !is_finite(transform.b) || !is_finite(transform.c)
		|| !is_finite(transform.d) || !is_finite(transform.e) || !is_finite(transform.f) {
		return
	}
	// 4-5. Copy path's subpaths and transform them by matrix.
	working_copy := path.path().copy_transformed(transform)
	// 6. Let (x, y) be the last point of the copy.
	xy := working_copy.last_point()
	// 7. Add all the subpaths in the copy to a.
	a.CanvasPath.path_.append_path(working_copy)
	// 8. Create a new subpath in a with (x, y) as the only point.
	a.move_to(xy.x, xy.y)
}
