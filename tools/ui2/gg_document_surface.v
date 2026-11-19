module canvas

import math
import sokol.gfx

// Map the distance from the common center to the interval between the
// two circles before the shader applies repeat or mirror tiling.
fn concentric_tile_gradient(start_radius f32, end_radius f32, center Point, g Gradient) !Gradient {
	span := end_radius - start_radius
	if g.tile_mode !in [.repeat, .mirror]
		|| !is_finite_f32(center.x) || !is_finite_f32(center.y) || !(start_radius > 0
		&& span > gradient_degenerate_threshold && is_finite_f32(span)) {
		return error('gg.canvas: two-point conical gradients are not supported')
	}
	bias := -start_radius / span
	if !is_finite_f32(bias) {
		return error('gg.canvas: invalid focal radius offset')
	}
	return Gradient{
		...g
		kind:        .radial
		p0:          center
		radius:      span
		radial_bias: bias
	}
}

// For nested circles the larger root of |p - t*d|^2 = (r0 + t*span)^2
// is the gradient position. Align x with d and absorb its quadratic scale
// into the vertex transform, leaving length(p) - focus*p.x + bias.
fn nested_circle_gradient(start Point, start_radius f32, end Point, end_radius f32, g Gradient) !Gradient {
	span := f64(end_radius) - f64(start_radius)
	dx := f64(end.x) - f64(start.x)
	dy := f64(end.y) - f64(start.y)
	distance := math.sqrt(dx * dx + dy * dy)
	if span == distance && span > f64(gradient_degenerate_threshold) && math.is_finite(span) {
		if g.tile_mode == .decal {
			return error('gg.canvas: unsupported tile mode for this tangent gradient')
		}
		return tangent_circle_gradient(start, start_radius, dx, dy, span, g)
	}
	if !(span - distance > f64(gradient_degenerate_threshold)) || !math.is_finite(span) {
		return error('gg.canvas: focal circle must be strictly inside the outer circle')
	}
	focus := distance / span
	if f32(focus) >= 1 {
		return error('gg.canvas: focal circle is tangent at shader precision')
	}
	bias := -f64(start_radius) / span
	denominator := (1 - focus) * (1 + focus)
	x_scale := 1 / (span * denominator)
	y_scale := 1 / (span * math.sqrt(denominator))
	cosine := dx / distance
	sine := dy / distance
	xx, xy := cosine * x_scale, sine * x_scale
	yx, yy := -sine * y_scale, cosine * y_scale
	tx := -xx * f64(start.x) - xy * f64(start.y) - focus * bias / denominator
	ty := -yx * f64(start.x) - yy * f64(start.y)
	unit := [f32(xx), f32(xy), f32(tx), f32(yx), f32(yy), f32(ty), 0, 0, 1]!
	if !unit.all(is_finite_f32(it)) || !is_finite_f32(f32(bias)) {
		return error('gg.canvas: invalid focal gradient transform')
	}
	return Gradient{
		...g
		kind:         .radial
		p0:           start
		radius:       f32(span)
		radial_unit:  Matrix.values(unit)
		radial_focus: f32(focus)
		radial_bias:  f32(bias)
	}
}

// With internal tangency the quadratic term vanishes. Use the shared
// point of tangency as the origin and scale both axes by 1 / (2 * span).
fn tangent_circle_gradient(start Point, start_radius f32, dx f64, dy f64, span f64, g Gradient) !Gradient {
	xx, xy := (dx / span) / (2 * span), (dy / span) / (2 * span)
	tx := -xx * f64(start.x) - xy * f64(start.y) + f64(start_radius) / (2 * span)
	ty := xy * f64(start.x) - xx * f64(start.y)
	unit := [f32(xx), f32(xy), f32(tx), f32(-xy), f32(xx), f32(ty), 0, 0, 1]!
	bias := f32(-f64(start_radius) / span)
	if !unit.all(is_finite_f32(it)) || !is_finite_f32(bias) {
		return error('gg.canvas: invalid tangent gradient transform')
	}
	return Gradient{
		...g
		kind:           .radial
		p0:             start
		radius:         f32(span)
		radial_unit:    Matrix.values(unit)
		radial_bias:    bias
		radial_tangent: true
		radial_average: g.tile_mode == .repeat && start_radius == 0
	}
}

// The normalized stops cover [0, 1]. Integrate the premultiplied stop
// colors, weighting each endpoint by half the length of its interval.
fn gradient_average_color(colors []Color4f, positions []f32) Color4f {
	mut sums := [4]f64{}
	mut previous := colors[0].premul()
	for i in 1 .. colors.len {
		color := colors[i].premul()
		weight := if positions.len == 0 {
			0.5 / f64(colors.len - 1)
		} else {
			(f64(positions[i]) - f64(positions[i - 1])) * 0.5
		}
		sums[0] += (f64(previous.r) + f64(color.r)) * weight
		sums[1] += (f64(previous.g) + f64(color.g)) * weight
		sums[2] += (f64(previous.b) + f64(color.b)) * weight
		sums[3] += (f64(previous.a) + f64(color.a)) * weight
		previous = color
	}
	return Color4f{f32(sums[0]), f32(sums[1]), f32(sums[2]), f32(sums[3])}
}

fn gradient_fields(fields string, shading Shading) string {
	if shading.is_linear() {
		return fields
	}
	radial_fields := 'float range_6;\nfloat radialBias;\nfloat radialFocus;\n'
	return fields.replace('float range_6;\n', if shading.is_tangent() {
		radial_fields + 'float tangentOutsideAlpha;\n'
	} else {
		radial_fields
	})
}

// Non-production builds read shared shader snippets at runtime. Keep the
// added field and its use together in the compiled shader generator.
fn gradient_conical_body(body string, shading Shading) string {
	if shading.is_linear() {
		return body
	}
	uniforms := '_globals._anonInterface0->combinedUniformData[_globals.uniformSsboIndex]'
	coords := if shading.is_translucent() { 'LocalMatrix_3_Var' } else { 'LocalMatrix_2_Var' }
	if shading.is_tangent() {
		return body.replace('float _34_b = length(_in.${coords}) + ${uniforms}.radialBias;\nfloat2 _35_g = float2(_34_b, 1.0);',
			'float2 focalCoords = _in.${coords};
float4 focalColor = float4(${uniforms}.paintColor.xyz, ${uniforms}.tangentOutsideAlpha);
if (focalCoords.x > 0.0) {
    float2 _35_g = float2(focalCoords.x + focalCoords.y * focalCoords.y / focalCoords.x + ${uniforms}.radialBias, 1.0);').replace('float4 _42_a = _37_sk_csxform_prealpha * ${uniforms}.paintColor.w;',
			'    focalColor = _37_sk_csxform_prealpha;
}
float4 _42_a = focalColor * ${uniforms}.paintColor.w;')
	}
	return body.replace(' + ${uniforms}.radialBias;',
		' + (${uniforms}.radialBias - ${uniforms}.radialFocus * _in.${coords}.x);')
}

// A pixel-aligned gradient rectangle with a rectangular hole can use the
// same OpenGL shader after the hole leaves the viewport. Zero inverse
// radius and selected edges give full coverage without changing draw order.
fn document_unclipped_gradient_uniforms(uniforms PaintUniforms) PaintUniforms {
	return PaintUniforms{
		...uniforms
		clipped: true
		clip: AnalyticClipUniforms{
			radius_plus_half: [f32(1), 0]!
			edge_select:      [f32(1), 1, 1, 1]!
		}
	}
}

// take_document_image flushes a surface and transfers ownership of its color
// attachment. Free the surface before sampling the image and destroy the image
// after its queued draws have been submitted.
pub fn (mut s GpuSurface) take_document_image() !gfx.Image {
	if s.color.id == 0 {
		return error('gg.canvas: surface has no color attachment')
	}
	s.flush()!
	image := s.color
	s.color = gfx.Image{}
	return image
}

fn (s &GpuSurface) check_document_region(pixels voidptr, pitch int, x int, y int, width int, height int) ! {
	// Region transfers use the Metal blit path; OpenGL transfers swizzle whole
	// surfaces through write_pixels() and read_pixels().
	if s.ctx.is_gl {
		return error('gg.canvas: region transfers require the Metal backend')
	}
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || x < 0 || y < 0
		|| x > s.width - width || y > s.height - height || pitch < width * 4 {
		return error('gg.canvas: invalid pixel region ${x},${y} ${width}x${height}')
	}
}

// write_document_region replaces one rectangle of the surface with BGRA8
// premultiplied pixels and discards pending draws, like write_pixels() for
// that rectangle. `pixels` addresses the rectangle's first pixel and its rows
// are `pitch` bytes apart. Pixels outside the rectangle keep their previous
// contents, which are undefined on a new surface: use it only when the later
// draws and read_document_region() stay inside the rectangle.
pub fn (mut s GpuSurface) write_document_region(pixels voidptr, pitch int, x int, y int, width int, height int) ! {
	if s.layer != unsafe { nil } {
		return error('gg.canvas: cannot write pixels under a layer')
	}
	s.check_document_region(pixels, pitch, x, y, width, height)!
	s.reset_draws()
	if !gfx.write_image(s.color, x, y, width, height, pixels, pitch) {
		return error('gg.canvas: could not upload pixels')
	}
	s.load = true
}

// read_document_region renders the pending draws like read_pixels() and
// copies one rectangle of the surface into BGRA8 premultiplied `pixels`,
// whose rows are `pitch` bytes apart.
pub fn (mut s GpuSurface) read_document_region(pixels voidptr, pitch int, x int, y int, width int, height int) ! {
	s.check_document_region(pixels, pitch, x, y, width, height)!
	s.flush()!
	if !gfx.read_image(s.color, x, y, width, height, pixels, pitch) {
		return error('gg.canvas: could not read back the surface')
	}
	if s.ctx.owns_gfx {
		gfx.commit()
	}
}
