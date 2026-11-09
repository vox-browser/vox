module cpuraster

// MakeFromImage can retain a subset of a larger bitmap. Rescale's first
// shader pass may sample that backing store when no strict subset is needed.
struct DeferredRescaleImage {
	view FilterImageView
	backing CanvasBitmap
	subset Rect
}

// BoundsScope::kRescale does not apply a layer-space decal. Analyze in the
// unshifted low-resolution coordinates before adding the surface origin.
fn rescale_source_image_shader(source DeferredRescaleImage, transform SkAffine, destination IRect, origin_x int, origin_y int) CanvasShader {
	view := source.view
	bitmap := view.bitmap
	image_bounds := Rect{0, 0, f32(bitmap.width), f32(bitmap.height)}
	output := Rect{f32(destination.left), f32(destination.top), f32(destination.right), f32(destination.bottom)}
	mut sampled := output
	layer := view.layer_bounds
	fills := if filter := view.filter { filter.affects_transparent_black() } else { false }
	if !filter_quad_contains_rect(transform,
		Rect{f32(layer.left), f32(layer.top), f32(layer.right), f32(layer.bottom)}, output).all(it)
		&& (fills || !layer.contains(map_filter_bounds(IRect{0, 0, bitmap.width, bitmap.height}, view.transform))) {
		mapped := map_filter_bounds(layer, transform)
		if clipped := rect_intersect(sampled, Rect{f32(mapped.left), f32(mapped.top), f32(mapped.right), f32(mapped.bottom)}) {
			sampled = clipped
		}
	}
	net := sk_concat(transform, view.transform)
	covered := filter_quad_contains_rect(net, image_bounds, sampled).all(it)
	x_aligned, y_aligned := filter_nearly_integer_axes(net)
	ex := if view.default_sampling && !x_aligned { image_filter_round_epsilon } else { f32(0) }
	ey := if view.default_sampling && !y_aligned { image_filter_round_epsilon } else { f32(0) }
	safe := Rect{f32(.5) + ex, f32(.5) + ey, image_bounds.right - f32(.5) - ex, image_bounds.bottom - f32(.5) - ey}
	centers := Rect{sampled.left + f32(.5), sampled.top + f32(.5), sampled.right - f32(.5), sampled.bottom - f32(.5)}
	edges := filter_quad_contains_rect(net, safe, centers)
	subset := source.subset
	strict := !(edges[0] || subset.top == 0) || !(edges[1] || subset.right == f32(source.backing.width))
		|| !(edges[2] || subset.bottom == f32(source.backing.height)) || !(edges[3] || subset.left == 0)
	backing := if strict { bitmap } else { source.backing }
	local := if strict { view.transform } else {
		sk_concat(view.transform, affine_translate(-subset.left, -subset.top))
	}
	device := sk_concat(affine_translate(-f32(origin_x), -f32(origin_y)), transform)
	total := sk_concat(device, local)
	tile := if covered { TileMode.clamp } else { .decal }
	return if view.default_sampling { new_image_shader(backing, tile, tile, true, total) }
		else if view.smoothing { new_linear_mipmap_image_shader(backing, tile, tile, total, true) }
		else { new_image_shader(backing, tile, tile, false, total) }
}
