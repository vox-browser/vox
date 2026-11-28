module ggshape

import cpuraster
import gg.canvas

const svg_canvas_dash_limit = 2048

pub struct SVGPathDash {
pub:
	intervals []f64
	offset    f64
}

fn dash_svg_geometry(geometry canvas.Path, pattern SVGPathDash, matrix [9]f32,
	non_scaling bool) !canvas.Path {
	source := cpuraster.Path{
		verbs: geometry.verbs.map(match it {
			.move { cpuraster.PathVerb.move }
			.line { .line }
			.quad { .quad }
			.conic { .conic }
			.cubic { .cubic }
			.close { .close }
		})
		points:  geometry.points.map(cpuraster.Point{it.x, it.y})
		weights: geometry.weights
	}
	transform := if non_scaling {
		cpuraster.Matrix{}
	} else {
		cpuraster.Matrix{matrix[0], matrix[3], matrix[1], matrix[4], matrix[2], matrix[5]}
	}
	dashed := cpuraster.dash_centerline(source, pattern.intervals.map(f32(it)), f32(pattern.offset),
		transform, svg_canvas_dash_limit)!
	return canvas.Path{
		verbs: dashed.verbs.map(match it {
			.move { canvas.PathVerb.move }
			.line { .line }
			.quad { .quad }
			.conic { .conic }
			.cubic { .cubic }
			.close { .close }
		})
		points:    dashed.points.map(canvas.Point{it.x, it.y})
		weights:   dashed.weights
		fill_type: geometry.fill_type
	}
}
