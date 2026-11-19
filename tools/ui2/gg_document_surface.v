module canvas

import sokol.gfx

// Map the distance from the common center to the interval between the
// two circles before the shader applies repeat or mirror tiling.
fn concentric_tile_gradient(start Point, start_radius f32, end Point, end_radius f32, g Gradient) !Gradient {
	span := end_radius - start_radius
	if g.tile_mode !in [.repeat, .mirror] || start.x != end.x || start.y != end.y
		|| !is_finite_f32(start.x) || !is_finite_f32(start.y) || !(start_radius > 0
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
		p0:          start
		radius:      span
		radial_bias: bias
	}
}

fn gradient_fields(fields string, shading Shading) string {
	return if shading.is_linear() {
		fields
	} else {
		fields.replace('float range_6;\n', 'float range_6;\nfloat radialBias;\n')
	}
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
