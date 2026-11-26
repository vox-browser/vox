module canvas

import math
import os
import sokol.gfx

$if macos {
	fn C.vox_gg_metal_begin_shader_libraries() bool
	fn C.vox_gg_metal_submit_shader_library(&char)
	fn C.vox_gg_metal_end_shader_libraries()

	const parallel_document_shader_libraries = os.getenv('VOX_PARALLEL_GG_METAL_SHADER_LIBRARIES') == '1'
		&& os.getenv('VOX_SERIAL_GG_METAL_SHADERS') == ''

	// All solid programs use the same source builder as GPU shader creation.
	// The native queue deduplicates identical source submissions.
	pub fn submit_document_shader_libraries() bool {
		if !parallel_document_shader_libraries { return false }
		gfx.mtl_set_shader_compile_options(graphite_msl_major, graphite_msl_minor, true)
		submitted := C.vox_gg_metal_begin_shader_libraries()
		gfx.mtl_set_shader_compile_options(0, 0, false)
		if !submitted { return false }
		$for entry in RenderStep.values {
			step := RenderStep(entry.value)
			for clipped in [false, true] {
				vs, fs := solid_shader_sources(step, clipped)
				C.vox_gg_metal_submit_shader_library(&char(vs.str))
				if writes_color(step) {
					C.vox_gg_metal_submit_shader_library(&char(fs.str))
				}
			}
		}
		source := load_msaa_from_resolve.to_string()
		C.vox_gg_metal_submit_shader_library(&char(source.str))
		return true
	}

	pub fn finish_document_shader_libraries() {
		C.vox_gg_metal_end_shader_libraries()
	}
}

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
	// Metal and D3D11 accept BGRA regions directly. OpenGL swizzles whole
	// surfaces through write_pixels() and read_pixels().
	if s.ctx.is_gl {
		return error('gg.canvas: region transfers require Metal or D3D11')
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

// Document leaf surfaces. Vox draws many paint leaves on a GPU surface of
// their own and reads the result back. Creating and destroying the surface's
// render targets (color, depth, the multisampled image and the attachments
// a pass that needs MSAA adds) cost more than the leaf's draw, most of it
// outside the calling thread: a rectangle leaf on a tile-sized surface ran
// about 1.8 million instructions with new targets and 0.6 million with
// reused ones.
//
// A released leaf surface keeps its targets here, by size and sample count,
// for the next leaf surface of that size. Each leaf still gets a new
// GpuSurface, so draws, clips, matrices and saves start empty in the
// caller's scope; only image contents carry over. Every pass clears depth
// and either clears color or loads what write_pixels() or
// write_document_region() uploaded, so a leaf that writes or clears its
// surface (or the region it reads back) sees what a new surface shows.
// Same-binary control: VOX_GG_FRESH_LEAF_SURFACES=1.
const retain_fresh_leaf_surfaces = os.getenv('VOX_GG_FRESH_LEAF_SURFACES') != ''
const document_leaf_pool_capacity = 4

struct DocumentLeafTargets {
mut:
	held                bool
	width               int
	height              int
	sample_count        int
	last_use            u64
	color               gfx.Image
	msaa                gfx.Image
	depth               gfx.Image
	attachments         gfx.Attachments
	dynamic_msaa        gfx.Image
	dynamic_depth       gfx.Image
	dynamic_attachments gfx.Attachments
}

struct DocumentLeafPool {
mut:
	entries [document_leaf_pool_capacity]DocumentLeafTargets
	uses    u64
	reused  u64
	created u64
}

const document_leaf_pool = &DocumentLeafPool{}

fn (mut targets DocumentLeafTargets) destroy() {
	if targets.dynamic_msaa.id != 0 {
		gfx.destroy_attachments(targets.dynamic_attachments)
		gfx.destroy_image(targets.dynamic_depth)
		gfx.destroy_image(targets.dynamic_msaa)
	}
	gfx.destroy_attachments(targets.attachments)
	gfx.destroy_image(targets.depth)
	if targets.msaa.id != 0 {
		gfx.destroy_image(targets.msaa)
	}
	gfx.destroy_image(targets.color)
	targets = DocumentLeafTargets{}
}

// Reused and newly created leaf surface targets in this process.
pub fn document_leaf_surface_statistics() (u64, u64) {
	pool := unsafe { document_leaf_pool }
	return pool.reused, pool.created
}

// new_document_leaf_surface is new_surface() for a leaf the caller releases
// with release_document_leaf_surface(). It may reuse the render targets of a
// released surface of the same size and sample count, whose pixels are
// then those of the earlier leaf until the caller writes or clears them.
pub fn (mut ctx GpuContext) new_document_leaf_surface(width int, height int, sample_count int) !&GpuSurface {
	if width <= 0 || height <= 0 {
		return error('gg.canvas: invalid surface size ${width}x${height}')
	}
	if sample_count != 1 && sample_count != 4 {
		return error('gg.canvas: unsupported sample count ${sample_count}')
	}
	mut pool := unsafe { document_leaf_pool }
	if !retain_fresh_leaf_surfaces {
		for i in 0 .. pool.entries.len {
			entry := pool.entries[i]
			if !entry.held || entry.width != width || entry.height != height
				|| entry.sample_count != sample_count {
				continue
			}
			pool.entries[i] = DocumentLeafTargets{}
			if gfx.query_attachments_state(entry.attachments) != .valid {
				mut stale := entry
				stale.destroy()
				break
			}
			pool.reused++
			return &GpuSurface{
				ctx:                 unsafe { ctx }
				width:               width
				height:              height
				texture_width:       width
				texture_height:      height
				sample_count:        sample_count
				transform:           Transform.new(Matrix.identity())
				bounds:              new_bounds_manager(width, height)
				clip:                new_clip_stack(width, height)
				color:               entry.color
				msaa:                entry.msaa
				depth:               entry.depth
				attachments:         entry.attachments
				dynamic_msaa:        entry.dynamic_msaa
				dynamic_depth:       entry.dynamic_depth
				dynamic_attachments: entry.dynamic_attachments
			}
		}
	}
	pool.created++
	return ctx.new_sized_surface(width, height, width, height, sample_count)!
}

// release_document_leaf_surface frees the surface like free(), keeping its
// render targets for a later leaf surface. A surface with an open layer, or
// one that is a layer, is freed.
pub fn (mut s GpuSurface) release_document_leaf_surface() {
	if retain_fresh_leaf_surfaces || s.is_layer || s.layer != unsafe { nil }
		|| s.texture_width != s.width || s.texture_height != s.height || s.color.id == 0 {
		s.free()
		return
	}
	s.free_retired_layers()
	mut pool := unsafe { document_leaf_pool }
	pool.uses++
	mut slot := -1
	for i in 0 .. pool.entries.len {
		if !pool.entries[i].held {
			slot = i
			break
		}
		if slot < 0 || pool.entries[i].last_use < pool.entries[slot].last_use {
			slot = i
		}
	}
	if pool.entries[slot].held {
		pool.entries[slot].destroy()
	}
	pool.entries[slot] = DocumentLeafTargets{
		held:                true
		width:               s.width
		height:              s.height
		sample_count:        s.sample_count
		last_use:            pool.uses
		color:               s.color
		msaa:                s.msaa
		depth:               s.depth
		attachments:         s.attachments
		dynamic_msaa:        s.dynamic_msaa
		dynamic_depth:       s.dynamic_depth
		dynamic_attachments: s.dynamic_attachments
	}
	s.color = gfx.Image{}
	s.msaa = gfx.Image{}
	s.depth = gfx.Image{}
	s.attachments = gfx.Attachments{}
	s.dynamic_msaa = gfx.Image{}
	s.dynamic_depth = gfx.Image{}
	s.dynamic_attachments = gfx.Attachments{}
}
