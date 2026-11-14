// Copyright 2025 The Chromium Authors. BSD license: layout/resources/chromium/LICENSE.
// Port of the retained Chromium superellipse and border-alignment geometry.
module ggshape

import gg.canvas
import math

fn C.sqrtf(f32) f32
fn C.exp2f(f32) f32
fn C.log2f(f32) f32
fn C.powf(f32, f32) f32

fn contour_add(a canvas.Point, b canvas.Point) canvas.Point {
	return canvas.Point{a.x + b.x, a.y + b.y}
}

fn contour_sub(a canvas.Point, b canvas.Point) canvas.Point {
	return canvas.Point{a.x - b.x, a.y - b.y}
}

fn contour_scale(a canvas.Point, amount f32) canvas.Point {
	return canvas.Point{a.x * amount, a.y * amount}
}

fn contour_length(a canvas.Point) f32 { return C.sqrtf(a.x * a.x + a.y * a.y) }

fn contour_normalized(a canvas.Point) canvas.Point {
	length := contour_length(a)
	return if length > 0 { canvas.Point{a.x / length, a.y / length} } else { canvas.Point{} }
}

fn contour_clamp(value f32, low f32, high f32) f32 {
	return if value < low {
		low
	} else if value > high {
		high
	} else {
		value
	}
}

fn contour_map(center canvas.Point, first canvas.Point, second canvas.Point, u f32, v f32) canvas.Point {
	return contour_add(contour_add(center, contour_scale(first, u)), contour_scale(second, v))
}

fn append_contoured_corner(mut path canvas.PathBuilder, rect canvas.RRect,
	parameters [4]f32, reference ?canvas.RRect, index int, move bool) {
	bounds := rect.rect
	radius := rect.radii[index]
	sx := if index == 0 || index == 3 { f32(-1) } else { f32(1) }
	sy := if index < 2 { f32(-1) } else { f32(1) }
	mut outside := canvas.Point{if sx < 0 { bounds.left() } else { bounds.right() }, if sy < 0 {
		bounds.top()
	} else {
		bounds.bottom()
	}}
	mut center := canvas.Point{outside.x - sx * radius.x, outside.y - sy * radius.y}
	mut start := if index == 0 || index == 2 {
		canvas.Point{outside.x, center.y}
	} else {
		canvas.Point{center.x, outside.y}
	}
	mut end := if index == 0 || index == 2 {
		canvas.Point{center.x, outside.y}
	} else {
		canvas.Point{outside.x, center.y}
	}
	mut curvature := if math.is_nan(f64(parameters[index])) {
		f32(2)
	} else {
		C.exp2f(parameters[index])
	}
	if origin := reference {
		if origin.rect != rect.rect || origin.radii != rect.radii {
			r := origin.radii[index]
			if r.x > 0 && r.y > 0 {
				ob := origin.rect
				outer := canvas.Point{if sx < 0 { ob.left() } else { ob.right() }, if sy < 0 {
					ob.top()
				} else {
					ob.bottom()
				}}
				middle := canvas.Point{outer.x - sx * r.x, outer.y - sy * r.y}
				last := if index == 0 || index == 2 {
					canvas.Point{middle.x, outer.y}
				} else {
					canvas.Point{outer.x, middle.y}
				}
				insets := [bounds.top() - ob.top(), ob.right() - bounds.right(),
					ob.bottom() - bounds.bottom(), bounds.left() - ob.left()]!
				v2 := contour_sub(last, outer)
				v3 := contour_sub(middle, last)
				start_radius := contour_length(v2)
				end_radius := contour_length(v3)
				target_start := contour_length(contour_sub(end, outside))
				target_end := contour_length(contour_sub(center, end))
				t1 := if insets[(index + 3) % 4] >= 0 && target_start == 0 {
					insets[(index + 3) % 4]
				} else {
					start_radius - target_start
				}
				t2 := if insets[index] >= 0 && target_end == 0 {
					insets[index]
				} else {
					end_radius - target_end
				}
				parameter := C.log2f(curvature)
				mut half := C.powf(f32(0.5), f32(1) / C.exp2f(math.abs(parameter)))
				if parameter < 0 { half = 1 - half }
				root2 := C.sqrtf(f32(2))
				control := contour_clamp(half / (root2 - 1) - f32(1) / root2, 0, 1)
				difference := contour_clamp(t2 - t1, -start_radius, end_radius)
				mut start_control := control
				mut end_control := control
				if difference != 0 {
					delta := C.sqrtf(start_radius * start_radius + end_radius * end_radius - difference * difference)
					nx := end_radius * difference + start_radius * delta
					ny := -start_radius * difference + end_radius * delta
					bevel := start_radius * ny / (start_radius * ny + end_radius * nx)
					start_control = if parameter < 0 {
						bevel * (2 * control)
					} else {
						1 - (1 - bevel) * (2 * (1 - control))
					}
					end_control = 2 * control - start_control
				}
				first_normal := contour_normalized(canvas.Point{(1 - start_control) * start_radius, start_control * end_radius})
				last_normal := contour_normalized(canvas.Point{end_control * start_radius, (1 - end_control) * end_radius})
				axis2 := contour_normalized(v2)
				axis3 := contour_normalized(v3)
				start_normal := contour_add(contour_scale(axis3, first_normal.x), contour_scale(axis2, first_normal.y))
				end_normal := contour_add(contour_scale(axis3, last_normal.x), contour_scale(axis2, last_normal.y))
				original_outside := contour_sub(contour_sub(outside, contour_scale(axis3, t2)), contour_scale(axis2, t1))
				start = contour_add(contour_add(original_outside, contour_scale(axis3, end_radius)), contour_scale(start_normal, t1))
				end = contour_add(contour_add(original_outside, contour_scale(axis2, start_radius)), contour_scale(end_normal, t2))
				adjusted := contour_sub(end, start)
				height := adjusted.x * axis2.x + adjusted.y * axis2.y
				outside = contour_sub(end, contour_scale(axis2, height))
				center = contour_add(start, contour_scale(axis2, height))
			}
		}
	}
	if move { path.move_to(start.x, start.y) }
	path.line_to(start.x, start.y)
	if curvature < 1 {
		previous := center
		center = outside
		outside = previous
		curvature = f32(1) / f32(math.max(f64(curvature), 0.001))
	}
	if radius.x <= 0 || radius.y <= 0 || curvature >= 1000 {
		path.line_to(outside.x, outside.y)
		path.line_to(end.x, end.y)
	} else if curvature == 1 {
		path.line_to(end.x, end.y)
	} else if curvature == 2 {
		path.conic_to(outside.x, outside.y, end.x, end.y, C.sqrtf(f32(0.5)))
	} else {
		fit := [1.2430920942724248, 2.010479023614843, .32922901179443753, .2823023142212073,
			1.3473704261055421, 2.9149468637949814, .9106507102917086]!
		power := C.log2f(curvature)
		slope := f32(fit[0] + (fit[6] - fit[0]) * .5 * (1 + math.tanh(fit[5] * (f64(power) - fit[1]))))
		base := f32(1 / (1 + math.exp(-f64(slope) * (0 - fit[1]))))
		logistic := f32(1 / (1 + math.exp(-f64(slope) * (f64(power) - fit[1]))))
		tangent := (logistic - base) / (1 - base)
		offset := f32(fit[2] * math.exp(-fit[3] * math.pow(f64(power), fit[4])))
		middle := f32(math.pow(.5, f64(f32(1) / curvature)))
		first := contour_sub(outside, start)
		second := contour_sub(start, center)
		p1 := contour_map(center, first, second, tangent, 1)
		p2 := contour_map(center, first, second, middle - offset, middle + offset)
		mid := contour_map(center, first, second, middle, middle)
		p3 := contour_map(center, first, second, middle + offset, middle - offset)
		p4 := contour_map(center, first, second, 1, tangent)
		path.cubic_to(p1.x, p1.y, p2.x, p2.y, mid.x, mid.y)
		path.cubic_to(p3.x, p3.y, p4.x, p4.y, end.x, end.y)
	}
}

fn contoured_rect_path(rect canvas.RRect, parameters [4]f32, reference ?canvas.RRect) canvas.Path {
	mut builder := canvas.PathBuilder{}
	for index in [1, 2, 3, 0] {
		append_contoured_corner(mut builder, rect, parameters, reference, index, index == 1)
	}
	builder.close()
	return builder.detach()
}

fn contour_polygon(points []canvas.Point) canvas.Path {
	mut path := canvas.PathBuilder{}
	for i, point in points {
		if i == 0 { path.move_to(point.x, point.y) } else { path.line_to(point.x, point.y) }
	}
	return path.detach()
}

fn draw_contoured_shape(mut target canvas.GpuSurface, shape &C.VoxGraphiteShape,
	paint canvas.Paint, width int, height int) ! {
	parameters := shape.contour_parameters
	rect := rounded_rect(shape.rect)
	reference := if shape.has_contour_reference != 0 {
		?canvas.RRect(rounded_rect(shape.contour_reference))
	} else {
		none
	}
	if shape.fill == 11 {
		target.draw_path(contoured_rect_path(rect, parameters, reference), paint)!
		return
	}
	if shape.fill == 13 {
		cutout := rounded_rect(shape.underlay_rect)
		target.clip_path(contoured_rect_path(cutout, parameters, reference), .difference, true)!
		mut offset := canvas.Point{}
		if origin := reference {
			offset = canvas.Point{(rect.rect.left() + rect.rect.right() - origin.rect.left() - origin.rect.right()) * f32(0.5), (rect.rect.top() + rect.rect.bottom() - origin.rect.top() - origin.rect.bottom()) * f32(0.5)}
		}
		mut source_rect := shape.rect
		source_rect[0] -= offset.x
		source_rect[1] -= offset.y
		path := contoured_rect_path(rounded_rect(source_rect), parameters, reference)
		if shape.thickness > 0 {
			mask := shadow_filter_mask(shape, width, height, path, offset)!
			target.set_matrix(canvas.Matrix.identity())
			target.draw_alpha_mask(mask, width, height, paint)!
		} else {
			mut matrix := shape.matrix
			matrix[2] += matrix[0] * offset.x + matrix[1] * offset.y
			matrix[5] += matrix[3] * offset.x + matrix[4] * offset.y
			target.set_matrix(canvas.Matrix.values(matrix))
			target.draw_path(path, paint)!
		}
		return
	}
	outside := rect.outset(shape.thickness * f32(0.5), shape.thickness * f32(0.5))
	inside := rect.inset(shape.thickness * f32(0.5), shape.thickness * f32(0.5))
	target.save()
	target.clip_path(contoured_rect_path(outside, parameters, none), .intersect, true)!
	target.save_layer(none)!
	if shape.has_underlay != 0 {
		background := rounded_rect(shape.underlay_rect)
		target.save()
		if background.rect != outside.rect || background.radii != outside.radii {
			target.clip_path(contoured_rect_path(background, parameters, outside), .intersect, true)!
		}
		target.draw_rect(outside.rect, canvas.Paint{
			color:      shape_color(shape.underlay_rgba, shape.has_float_underlay_color != 0, shape.underlay_float_color)
			anti_alias: true
		})!
		target.restore()
	}
	target.clip_path(contoured_rect_path(inside, parameters, outside), .difference, true)!
	// Hard side clips partition the ring. Fold the opacity into each draw,
	// matching the recorded renderer's save-layer optimization.
	solid := paint
	if parameters.all(it >= 1) {
		box := outside.rect
		mut join := [4]canvas.Point{}
		for i in 0 .. 4 {
			r := outside.radii[i]
			join[i] = canvas.Point{if i == 0 || i == 3 {
				box.left() + (r.x + shape.thickness) / 2
			} else {
				box.right() - (r.x + shape.thickness) / 2
			}, if i < 2 {
				box.top() + (r.y + shape.thickness) / 2
			} else {
				box.bottom() - (r.y + shape.thickness) / 2
			}}
		}
		tl, tr := canvas.Point{box.left(), box.top()}, canvas.Point{box.right(), box.top()}
		br, bl := canvas.Point{box.right(), box.bottom()}, canvas.Point{box.left(), box.bottom()}
		for points in [[tl, join[0], join[1], tr], [bl, join[3], join[2], br],
			[tr, join[1], join[2], br], [tl, join[0], join[3], bl]] {
			target.save()
			target.clip_path(contour_polygon(points), .intersect, false)!
			target.draw_rect(outside.rect, solid)!
			target.restore()
		}
	} else {
		target.draw_rect(outside.rect, solid)!
	}
	target.restore()
	target.restore()
}
