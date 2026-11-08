module cpuraster

// Image filters on RGBA_8888 images, as skif::FilterResult evaluates them
// on the raster backend. This first part covers an identity mapping with
// pixel-aligned images, which SkImages::MakeWithFilter() uses.

// SkSpecialImage: a subset of a backing bitmap.
struct SpecialImage {
	backing BlurImage
	subset  IRect
}

fn (s SpecialImage) width() int {
	return s.subset.width()
}

fn (s SpecialImage) height() int {
	return s.subset.height()
}

// SkSpecialImage::makeSubset() with a subset relative to this one.
fn (s SpecialImage) make_subset(r IRect) SpecialImage {
	return SpecialImage{
		backing: s.backing
		subset:  IRect{s.subset.left + r.left, s.subset.top + r.top, s.subset.left + r.right, s.subset.top +
			r.bottom}
	}
}

// SkSpecialImages::AsBitmap(): the subset's pixels.
fn (s SpecialImage) bitmap() BlurImage {
	w := s.width()
	h := s.height()
	mut px := []u8{len: w * h * 4}
	for y in 0 .. h {
		src := ((s.subset.top + y) * s.backing.width + s.subset.left) * 4
		copy(mut px[y * w * 4..(y + 1) * w * 4], s.backing.pixels[src..src + w * 4])
	}
	return BlurImage{px, w, h}
}

// skif's rounding epsilon.
const image_filter_round_epsilon = f32(1e-3)

// MakeFromImage retains the source's alpha type and color space. Raster
// blur passes preserve that storage until a color filter or conversion
// requires an intermediate premultiplied sRGB image.
struct FilterImageInfo {
	premultiplied bool = true
	display_p3 bool
}

fn (info FilterImageInfo) bitmap(image BlurImage) CanvasBitmap {
	return CanvasBitmap{pixels: image.pixels, width: image.width, height: image.height,
		pitch: image.width * 4, premultiplied: info.premultiplied, display_p3: info.display_p3}
}

// LayerSpace<SkSize>::ceil(): SkScalarCeilToInt(size - 1e-3).
fn skif_ceil(v f32) int {
	return float_saturate2int(ceil_f32(v - image_filter_round_epsilon))
}

fn skif_outset(r IRect, dx int, dy int) IRect {
	return IRect{r.left - dx, r.top - dy, r.right + dx, r.bottom + dy}
}

// FilterResult for pixel-aligned images: an image placed at an integer
// origin in layer space (fTransform a translation), decal tiled without a
// deferred matrix filter, visible within its layer bounds. Source-image
// alpha type and color space are retained separately from the raw channels.
struct FilterResult {
	image        SpecialImage
	color_info   FilterImageInfo
	has_image    bool
	// PixelBoundary::kTransparent permits sampling the surrounding pixel
	// instead of anti-aliasing the image edge. Blur output is initialized,
	// but its surrounding pixels are not known to be transparent.
	transparent_boundary bool
	origin_x     int
	origin_y     int
	layer_bounds IRect
}

fn new_filter_result(image SpecialImage, x int, y int) FilterResult {
	return FilterResult{
		image:        image
		has_image:    true
		origin_x:     x
		origin_y:     y
		layer_bounds: IRect{x, y, x + image.width(), y + image.height()}
	}
}

// LayerSpace<SkIRect>::relevantSubset() for decal tiling: the
// intersection, or empty.
fn decal_relevant_subset(r IRect, dst IRect) IRect {
	return r.intersect(dst) or { IRect{} }
}

// FilterResult::subset() at the known integer origin.
fn (f FilterResult) subset(bounds IRect) FilterResult {
	image_bounds := decal_relevant_subset(IRect{f.origin_x, f.origin_y, f.origin_x + f.image.width(), f.origin_y +
		f.image.height()}, bounds)
	if image_bounds.is_empty() {
		return FilterResult{}
	}
	sub := IRect{image_bounds.left - f.origin_x, image_bounds.top - f.origin_y, image_bounds.right - f.origin_x, image_bounds.bottom - f.origin_y}
	return FilterResult{
		...new_filter_result(f.image.make_subset(sub), image_bounds.left, image_bounds.top)
		color_info: f.color_info
		transparent_boundary: f.transparent_boundary
	}
}

fn (f FilterResult) inset_for_save_layer() FilterResult {
	return FilterResult{...f.inset_by_pixel(), transparent_boundary: true}
}

fn (f FilterResult) translated(dx int, dy int) FilterResult {
	b := f.layer_bounds
	return FilterResult{...f, origin_x: f.origin_x + dx, origin_y: f.origin_y + dy,
		layer_bounds: IRect{b.left + dx, b.top + dy, b.right + dx, b.bottom + dy}}
}

// FilterResult::insetByPixel().
fn (f FilterResult) inset_by_pixel() FilterResult {
	b := f.layer_bounds
	return f.subset(IRect{b.left + 1, b.top + 1, b.right - 1, b.bottom - 1})
}

// FilterResult::resolve() of a subset-compatible result: its subset within
// the destination bounds.
fn (f FilterResult) resolve(dst IRect) FilterResult {
	if !f.has_image {
		return FilterResult{}
	}
	bounds := dst.intersect(f.layer_bounds) or { return FilterResult{} }
	return f.subset(bounds)
}

// SkBlurImageFilter::mapSigma() under an identity layer matrix.
fn blur_layer_sigma(sigma f32) f32 {
	s := if sigma < f32(532) { sigma } else { f32(532) }
	if !is_finite_f32(s) || blur_is_identity(s) {
		return 0
	}
	return s
}

// SkBlurImageFilter::onFilterImage() with Builder::blur() on a decal
// source in layer space: the blur reads the source's pixels within the
// sample bounds, writes the desired output plus a pixel of padding, and
// keeps the part inside the desired output. None when the sigma needs the
// rescaling path (above 135).
fn blur_filter_result(source FilterResult, desired IRect, sigma_x_in f32, sigma_y_in f32) ?FilterResult {
	sigma_x := blur_layer_sigma(sigma_x_in)
	sigma_y := blur_layer_sigma(sigma_y_in)
	if sigma_x == 0 && sigma_y == 0 {
		return source
	}
	if sigma_x > image_blur_max_sigma || sigma_y > image_blur_max_sigma {
		return none
	}
	if !source.has_image {
		return FilterResult{}
	}
	rx := skif_ceil(f32(3) * sigma_x)
	ry := skif_ceil(f32(3) * sigma_y)
	max_output := skif_outset(source.layer_bounds, rx, ry)
	output := desired.intersect(max_output) or { return FilterResult{} }
	sample := skif_outset(output, rx, ry)
	// rescale() at scale 1 of a pixel-aligned decal image: its subset in
	// the sample bounds.
	visible := source.layer_bounds.intersect(sample) or { return FilterResult{} }
	low := source.subset(visible)
	if !low.has_image {
		return FilterResult{}
	}
	mut src_relative := IRect{output.left - low.origin_x, output.top - low.origin_y, output.right - low.origin_x, output.bottom - low.origin_y}
	max_low := skif_outset(IRect{0, 0, low.image.width(), low.image.height()}, skif_ceil(f32(3) * sigma_x),
		skif_ceil(f32(3) * sigma_y))
	src_relative = decal_relevant_subset(max_low, src_relative)
	if src_relative.is_empty() {
		return FilterResult{}
	}
	src_relative = skif_outset(src_relative, 1, 1)
	src := low.image.bitmap()
	blurred, subset := blur_8888(sigma_x, sigma_y, src, IRect{0, 0, src.width, src.height},
		src_relative)
	mut result := new_filter_result(SpecialImage{blurred, subset}, src_relative.left, src_relative.top)
	result = result.inset_by_pixel()
	if !result.has_image {
		return FilterResult{}
	}
	shifted := new_filter_result(result.image, result.origin_x + low.origin_x, result.origin_y +
		low.origin_y)
	bounds := desired.intersect(shifted.layer_bounds) or { IRect{} }
	return FilterResult{
		...shifted
		color_info: source.color_info
		layer_bounds: bounds
	}
}

// SkImages::MakeWithFilter() with SkImageFilters::Blur(sigma_x, sigma_y)
// on the subset of src, inside clip: the result's pixels and offset, none
// for an empty result.
pub fn image_with_blur_filter(src BlurImage, subset IRect, clip IRect, sigma_x f32, sigma_y f32) ?(BlurImage, int, int) {
	if clip.is_empty() {
		return none
	}
	source := new_filter_result(SpecialImage{src, subset}, subset.left, subset.top)
	result := blur_filter_result(source, clip, sigma_x, sigma_y)?
	resolved := result.resolve(clip)
	if !resolved.has_image {
		return none
	}
	return resolved.image.bitmap(), resolved.layer_bounds.left, resolved.layer_bounds.top
}
