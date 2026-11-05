module main

import layout
import math

struct RoundedUnderlayOffset {
	valid bool
	x f64
	y f64
}

// The native combined draw uses the consumer's matrix for both shapes. A
// background can have a local paint offset while its border stays in page
// coordinates, even for an identity CSS transform. Preserve their device
// geometry by expressing the background in the consumer's coordinate space.
fn rounded_underlay_offset(background &layout.PaintCommand, consumer &layout.PaintCommand) RoundedUnderlayOffset {
	from := normalized_paint_transform(background.transform)
	to := normalized_paint_transform(consumer.transform)
	for i in 0 .. 6 {
		if math.is_nan(from[i]) || math.is_inf(from[i], 0)
			|| math.is_nan(to[i]) || math.is_inf(to[i], 0) { return RoundedUnderlayOffset{} }
	}
	if from == to { return RoundedUnderlayOffset{valid: true} }
	// A translated local frame preserves rounded geometry. Other relative
	// transforms, or clip-outs in different frames, need separate paint passes.
	if background.clip_outs.len != 0 || consumer.clip_outs.len != 0 { return RoundedUnderlayOffset{} }
	for i in 0 .. 4 {
		if from[i] != to[i] { return RoundedUnderlayOffset{} }
	}
	determinant := to[0] * to[3] - to[1] * to[2]
	if determinant == 0 || math.is_nan(determinant) || math.is_inf(determinant, 0) {
		return RoundedUnderlayOffset{}
	}
	x := from[4] - to[4]
	y := from[5] - to[5]
	dx := (to[3] * x - to[2] * y) / determinant
	dy := (to[0] * y - to[1] * x) / determinant
	if math.is_nan(dx) || math.is_inf(dx, 0) || math.is_nan(dy) || math.is_inf(dy, 0) {
		return RoundedUnderlayOffset{}
	}
	return RoundedUnderlayOffset{valid: true, x: dx, y: dy}
}

fn rounded_underlay_rect(background &layout.PaintCommand, consumer &layout.PaintCommand,
	radius f32) [12]f32 {
	offset := rounded_underlay_offset(background, consumer)
	return [f32(background.x + offset.x), f32(background.y + offset.y),
		f32(background.width), f32(background.height),
		radius, radius, radius, radius, radius, radius, radius, radius]!
}
