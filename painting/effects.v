module painting

import math

pub enum BlendMode {
	normal
	multiply
	screen
	overlay
	darken
	lighten
	color_dodge
	color_burn
	hard_light
	soft_light
	difference
	exclusion
	hue
	saturation
	color
	luminosity
	plus_darker
	plus_lighter
}

pub enum CompositingAndBlendingOperator {
	normal
	destination_in
	multiply
	screen
	overlay
	darken
	lighten
	color_dodge
	color_burn
	hard_light
	soft_light
	difference
	exclusion
	hue
	saturation
	color
	luminosity
	plus_darker
	plus_lighter
}

pub fn mix_blend_mode_to_compositing_and_blending_operator(mode BlendMode) CompositingAndBlendingOperator {
	return match mode {
		.normal { .normal }
		.multiply { .multiply }
		.screen { .screen }
		.overlay { .overlay }
		.darken { .darken }
		.lighten { .lighten }
		.color_dodge { .color_dodge }
		.color_burn { .color_burn }
		.hard_light { .hard_light }
		.soft_light { .soft_light }
		.difference { .difference }
		.exclusion { .exclusion }
		.hue { .hue }
		.saturation { .saturation }
		.color { .color }
		.luminosity { .luminosity }
		.plus_darker { .plus_darker }
		.plus_lighter { .plus_lighter }
	}
}

pub enum ColorFilterType {
	brightness
	contrast
	grayscale
	invert
	opacity
	saturate
	sepia
}

pub struct BlurFilter {
pub:
	radius f64
}

pub struct DropShadowFilter {
pub:
	offset_x f64
	offset_y f64
	radius   f64
	color    Color
}

pub struct ColorFilter {
pub:
	operation ColorFilterType
	amount    f64
}

pub struct HueRotateFilter {
pub:
	angle_degrees f64
}

pub type ResolvedFilterOperation = BlurFilter | ColorFilter | DropShadowFilter | HueRotateFilter

pub struct GfxFilterOperation {
pub:
	kind            string
	first           f64
	second          f64
	third           f64
	color           Color
	color_operation ColorFilterType
}

// Gfx::Filter is a tree, not a flat list. CSS filter functions happen to form
// a chain, while SVG filters can name earlier results and combine any number of
// inputs. Keep that graph intact across the layout/painting boundary.
pub struct GfxFilterColorTable {
pub:
	channel string
	values  []u8
}

pub struct GfxFilterNode {
pub:
	id                int
	kind              string
	input_ids         []int
	parameters        map[string]f64
	string_parameters map[string]string
	image_url         string
	color             Color
	matrix            []f64
	color_tables      []GfxFilterColorTable
}

pub struct GfxFilter {
pub:
	// Operations are in composition order; later CSS operations wrap earlier ones.
	operations []GfxFilterOperation
	// SVG graph nodes are in construction order. Input -1 is SourceGraphic,
	// which is the result of the CSS operation chain when both are present.
	nodes   []GfxFilterNode
	root_id ?int
	// SVG content-generating primitives are evaluated over this target region.
	// The transparent display-list trigger carries the same rectangle, matching
	// StackingContext::paint() and SVGSVGPaintable::paint_svg_box().
	bounds ?Rect
}

// A same-document SVG graph and its target bounds have one retained lifetime.
// Ordinary and CSS-function-only filters carry no graph payload.
struct ResolvedSVGFilterSnapshot {
	filter ?GfxFilter
	bounds ?Rect
}

pub struct ResolvedCSSFilter {
	svg_filter_data &ResolvedSVGFilterSnapshot = unsafe { nil }
pub:
	operations []ResolvedFilterOperation
}

pub fn ResolvedCSSFilter.with_svg_filter(operations []ResolvedFilterOperation, svg_filter ?GfxFilter, bounds ?Rect) ResolvedCSSFilter {
	if svg_filter == none && bounds == none {
		return ResolvedCSSFilter{
			operations: operations
		}
	}
	return ResolvedCSSFilter{
		operations:      operations
		svg_filter_data: &ResolvedSVGFilterSnapshot{
			filter: svg_filter
			bounds: bounds
		}
	}
}

pub fn (filter ResolvedCSSFilter) svg_filter_bounds() ?Rect {
	if isnil(filter.svg_filter_data) { return none }
	return filter.svg_filter_data.bounds
}

// SVG graphics paint their user space already mapped to the page, while their
// filter region and primitive lengths stay in that user space. Map both so a
// stdDeviation of 16 inside scale(.1) blurs by 1.6px over the scaled region.
pub fn (filter ResolvedCSSFilter) mapped_from_user_space(transform Affine) ResolvedCSSFilter {
	if isnil(filter.svg_filter_data) || transform == Affine{} {
		return filter
	}
	snapshot := filter.svg_filter_data
	mapped_bounds := if bounds := snapshot.bounds {
		?Rect(affine_mapped_bounds(transform, bounds))
	} else {
		?Rect(none)
	}
	mut mapped_filter := ?GfxFilter(none)
	if svg := snapshot.filter {
		mapped_filter = GfxFilter{
			...svg
			nodes: svg.nodes.map(svg_filter_node_from_user_space(it, transform))
			bounds: if bounds := svg.bounds { ?Rect(affine_mapped_bounds(transform, bounds)) } else { ?Rect(none) }
		}
	}
	return ResolvedCSSFilter{
		operations: filter.operations
		svg_filter_data: &ResolvedSVGFilterSnapshot{
			filter: mapped_filter
			bounds: mapped_bounds
		}
	}
}

fn affine_mapped_bounds(transform Affine, rect Rect) Rect {
	xs := [rect.x, rect.x + rect.width]
	ys := [rect.y, rect.y + rect.height]
	mut left := math.inf(1)
	mut top := math.inf(1)
	mut right := math.inf(-1)
	mut bottom := math.inf(-1)
	for x in xs {
		for y in ys {
			mapped_x := transform.a * x + transform.c * y + transform.e
			mapped_y := transform.b * x + transform.d * y + transform.f
			left = math.min(left, mapped_x)
			top = math.min(top, mapped_y)
			right = math.max(right, mapped_x)
			bottom = math.max(bottom, mapped_y)
		}
	}
	return Rect{left, top, right - left, bottom - top}
}

fn svg_filter_node_from_user_space(node GfxFilterNode, transform Affine) GfxFilterNode {
	mut parameters := node.parameters.clone()
	match node.kind {
		'blur', 'erode', 'dilate' {
			parameters['radius_x'] = (node.parameters['radius_x'] or { 0.0 }) * math.hypot(transform.a, transform.b)
			parameters['radius_y'] = (node.parameters['radius_y'] or { 0.0 }) * math.hypot(transform.c, transform.d)
		}
		'offset' {
			dx := node.parameters['dx'] or { 0.0 }
			dy := node.parameters['dy'] or { 0.0 }
			parameters['dx'] = transform.a * dx + transform.c * dy
			parameters['dy'] = transform.b * dx + transform.d * dy
		}
		'displacement-map' {
			parameters['scale'] = (node.parameters['scale'] or { 0.0 }) * math.sqrt(math.abs(transform.a * transform.d - transform.b * transform.c))
		}
		else {
			return node
		}
	}
	return GfxFilterNode{
		...node
		parameters: parameters
	}
}

pub fn (filter ResolvedCSSFilter) has_filters() bool {
	return filter.operations.len > 0 || filter.has_svg_filters()
}

pub fn (filter ResolvedCSSFilter) has_svg_filters() bool {
	return !isnil(filter.svg_filter_data) && filter.svg_filter_data.filter != none
}

pub fn (filter ResolvedCSSFilter) to_gfx_filter(device_scale f64) ?GfxFilter {
	mut operations := []GfxFilterOperation{}
	mut nodes := []GfxFilterNode{}
	mut root_id := ?int(none)
	mut bounds := ?Rect(none)
	for operation in filter.operations {
		match operation {
			BlurFilter {
				operations.prepend(GfxFilterOperation{
					kind: 'blur'
					first: operation.radius * device_scale
					second: operation.radius * device_scale
				})
			}
			DropShadowFilter {
				operations.prepend(GfxFilterOperation{
					kind: 'drop-shadow'
					first: operation.offset_x * device_scale
					second: operation.offset_y * device_scale
					third: operation.radius * device_scale
					color: operation.color
				})
			}
			ColorFilter {
				operations.prepend(GfxFilterOperation{
					kind: 'color'
					first: operation.amount
					color_operation: operation.operation
				})
			}
			HueRotateFilter {
				operations.prepend(GfxFilterOperation{
					kind: 'hue-rotate'
					first: operation.angle_degrees
				})
			}
		}
	}
	snapshot := filter.svg_filter_data
	if !isnil(snapshot) {
		if svg := snapshot.filter {
			for operation in svg.operations.reverse() {
				operations.prepend(operation)
			}
			nodes = svg.nodes.clone()
			root_id = svg.root_id
			bounds = snapshot.bounds
		}
	}
	if operations.len == 0 && root_id == none {
		return none
	}
	return GfxFilter{
		operations: operations
		nodes: nodes
		root_id: root_id
		bounds: bounds
	}
}

pub fn (filter ResolvedCSSFilter) dump() string {
	mut descriptions := []string{}
	for operation in filter.operations {
		descriptions << match operation {
			BlurFilter { 'blur(${operation.radius})' }
			DropShadowFilter {
				'drop-shadow(${operation.offset_x} ${operation.offset_y} ${operation.radius})'
			}
			ColorFilter { '${operation.operation}(${operation.amount})' }
			HueRotateFilter { 'hue-rotate(${operation.angle_degrees}deg)' }
		}
	}
	mut result := if descriptions.len > 0 { 'filters=(${descriptions.join(', ')})' } else { '' }
	if filter.has_svg_filters() {
		result += ' svg_filter'
	}
	return result.trim_space()
}

pub struct ColorStop {
pub mut:
	color           Color
	position        f64
	transition_hint ?f64
}

pub struct ColorStopData {
pub:
	list          []ColorStop
	repeat_length ?f64
	repeating     bool
}

pub enum ColorInterpolationMethod {
	srgb
	linear_srgb
	oklab
	oklch
}

pub struct LinearGradientData {
pub:
	gradient_angle       f64
	color_stops          ColorStopData
	interpolation_method ColorInterpolationMethod
}

pub struct ConicGradientData {
pub:
	start_angle          f64
	color_stops          ColorStopData
	interpolation_method ColorInterpolationMethod
}

pub struct RadialGradientData {
pub:
	color_stops          ColorStopData
	interpolation_method ColorInterpolationMethod
}

fn interpolate_channel(first u8, second u8, amount f64) u8 {
	value := f64(first) + (f64(second) - f64(first)) * amount
	return u8(math.round(math.max(0.0, math.min(255.0, value))))
}

pub fn interpolate_color(first Color, second Color, amount f64) Color {
	return Color{
		r: interpolate_channel(first.r, second.r, amount)
		g: interpolate_channel(first.g, second.g, amount)
		b: interpolate_channel(first.b, second.b, amount)
		a: interpolate_channel(first.a, second.a, amount)
	}
}

fn color_stop_step(first ColorStop, second ColorStop, position f64) f64 {
	if position < first.position {
		return 0.0
	}
	if position > second.position {
		return 1.0
	}
	stop_length := second.position - first.position
	if stop_length <= 0 {
		return 1.0
	}
	p := (position - first.position) / stop_length
	hint := second.transition_hint or { return p }
	if hint >= 1 {
		return 0.0
	}
	if hint <= 0 {
		return 1.0
	}
	return math.pow(p, math.log(0.5) / math.log(hint))
}

pub fn replace_transition_hints_with_normal_color_stops(stops []ColorStop) []ColorStop {
	if stops.len == 0 {
		return []
	}
	assert stops[0].transition_hint == none
	mut expanded := [ColorStop{ color: stops[0].color, position: stops[0].position }]
	for index := 1; index < stops.len; index++ {
		stop := stops[index]
		if hint := stop.transition_hint {
			previous := stops[index - 1]
			distance := stop.position - previous.position
			samples := [hint * 0.33, hint * 0.66, hint, hint + (1.0 - hint) * 0.33,
				hint + (1.0 - hint) * 0.66]
			for sample in samples {
				position := previous.position + sample * distance
				amount := color_stop_step(previous, stop, position)
				expanded << ColorStop{
					color: interpolate_color(previous.color, stop.color, amount)
					position: position
				}
			}
		}
		expanded << ColorStop{
			color: stop.color
			position: stop.position
		}
	}
	return expanded
}

fn color_between_stops(position f64, current ColorStop, previous ColorStop) Color {
	distance := current.position - previous.position
	percentage := if distance == 0 { 0.0 } else { (position - previous.position) / distance }
	return interpolate_color(previous.color, current.color, percentage)
}

pub fn expand_repeat_length(stops []ColorStop, repeat_length f64) []ColorStop {
	if stops.len == 0 || repeat_length <= 0 {
		return stops.clone()
	}
	first_position := stops[0].position
	negative_count := int(math.ceil(first_position / repeat_length))
	positive_count := int(math.ceil((1.0 - first_position) / repeat_length))
	mut expanded := stops.clone()
	for repeat := 1; repeat <= negative_count; repeat++ {
		for source_index := stops.len - 1; source_index >= 0; source_index-- {
			mut stop := stops[source_index]
			stop.position -= repeat_length * f64(repeat)
			if stop.position < 0 {
				first := expanded[0]
				stop.color = color_between_stops(0.0, stop, first)
				stop.position = 0
				expanded.prepend(stop)
				break
			}
			expanded.prepend(stop)
		}
	}
	for repeat := 1; repeat < positive_count; repeat++ {
		for source in stops {
			mut stop := source
			stop.position += repeat_length * f64(repeat)
			if stop.position > 1 {
				last := expanded[expanded.len - 1]
				stop.color = color_between_stops(1.0, stop, last)
				stop.position = 1
				expanded << stop
				break
			}
			expanded << stop
		}
	}
	return expanded
}

pub fn expand_color_stops_for_painting(stops []ColorStop, repeat_length ?f64) []ColorStop {
	expanded := if length := repeat_length {
		expand_repeat_length(stops, length)
	} else {
		stops.clone()
	}
	return replace_transition_hints_with_normal_color_stops(expanded)
}

pub enum ShadowPlacement {
	outer
	inner
}

pub struct ShadowData {
pub:
	color           Color
	offset_x        f64
	offset_y        f64
	blur_radius     f64
	spread_distance f64
	placement       ShadowPlacement
}

pub struct ResolvedShadow {
pub:
	placement            ShadowPlacement
	color                Color
	blur_radius          int
	content_rect         IntRect
	content_corner_radii CornerRadii
	clip_corner_radii    CornerRadii
	shadow_rect          IntRect
	shadow_corner_radii  CornerRadii
	outer_shadow_rect    IntRect
	inner_shadow_rect    IntRect
	inner_corner_radii   CornerRadii
}

// Direct translation of ShadowPainting.cpp::paint_box_shadow(). The returned
// operations are the source display-list payloads, including the rounded clip
// installed around each command by BorderRadiusCornerClipper.
pub fn paint_box_shadow(bordered_content_rect Rect, borderless_content_rect Rect,
	borders_data BordersData, border_radii BorderRadiiData, layers []ShadowData,
	converter DevicePixelConverter) []ResolvedShadow {
	mut resolved := []ResolvedShadow{cap: layers.len}
	corner_radii := border_radii.as_corners(converter)
	for source_index := layers.len - 1; source_index >= 0; source_index-- {
		layer := layers[source_index]
		offset :=
			IntPoint{converter.rounded_device_pixels(layer.offset_x), converter.rounded_device_pixels(layer.offset_y)}
		blur := converter.rounded_device_pixels(layer.blur_radius)
		spread := converter.rounded_device_pixels(layer.spread_distance)
		if layer.placement == .outer {
			device_content := converter.rounded_device_rect(bordered_content_rect)
			shadow_rect :=
				device_content.inflated(spread, spread, spread, spread).translated(offset)
			mut shadow_corners := corner_radii
			shadow_corners.adjust_for_spread_distance(spread)
			resolved << ResolvedShadow{
				placement: layer.placement
				color: layer.color
				blur_radius: blur
				content_rect: device_content
				content_corner_radii: corner_radii
				clip_corner_radii: corner_radii
				shadow_rect: shadow_rect
				shadow_corner_radii: shadow_corners
			}
		} else {
			device_content := converter.rounded_device_rect(borderless_content_rect)
			mut outer_shadow_rect := device_content.translated(offset)
			inner_shadow_rect := outer_shadow_rect.inflated(-spread, -spread, -spread, -spread)
			outer_shadow_rect = outer_shadow_rect.inflated(blur + offset.y, blur + abs_int(offset.x), blur + abs_int(offset.y), blur + offset.x)
			mut inner_corners := corner_radii
			inner_corners.adjust_for_spread_distance(-spread)
			mut clip_radii := border_radii
			clip_radii.shrink(borders_data.top.width, borders_data.right.width, borders_data.bottom.width, borders_data.left.width)
			resolved << ResolvedShadow{
				placement: layer.placement
				color: layer.color
				blur_radius: blur
				content_rect: device_content
				content_corner_radii: corner_radii
				clip_corner_radii: clip_radii.as_corners(converter)
				outer_shadow_rect: outer_shadow_rect
				inner_shadow_rect: inner_shadow_rect
				inner_corner_radii: inner_corners
			}
		}
	}
	return resolved
}

// Compatibility entry point retained for renderer-independent callers which
// do not distinguish the outer border box from the inner padding box.
pub fn resolve_box_shadows(content_rect Rect, radii BorderRadiiData, layers []ShadowData,
	converter DevicePixelConverter) []ResolvedShadow {
	return paint_box_shadow(content_rect, content_rect, BordersData{}, radii, layers, converter)
}
