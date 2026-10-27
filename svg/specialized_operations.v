// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Gradient, pattern, root viewport, decoded-image, and page-client entry points.
module svg

import math

pub fn attribute_style_properties() []string {
	return ['fill', 'clip-path', 'clip-rule', 'color', 'color-interpolation',
		'color-interpolation-filters', 'cursor', 'cx', 'cy', 'd', 'direction', 'display',
		'dominant-baseline', 'fill-opacity', 'fill-rule', 'filter', 'flood-color', 'flood-opacity',
		'font-family', 'font-size', 'font-style', 'font-variant', 'font-weight', 'font-stretch',
		'height', 'image-rendering', 'letter-spacing', 'mask', 'mask-type', 'opacity', 'overflow',
		'paint-order', 'pointer-events', 'r', 'rx', 'ry', 'shape-rendering', 'stop-color',
		'stop-opacity', 'stroke', 'stroke-dasharray', 'stroke-dashoffset', 'stroke-linecap',
		'stroke-linejoin', 'stroke-miterlimit', 'stroke-opacity', 'stroke-width', 'vector-effect',
		'text-anchor', 'text-decoration', 'text-rendering', 'text-overflow', 'transform',
		'gradientTransform', 'patternTransform', 'transform-origin', 'unicode-bidi', 'visibility',
		'white-space', 'width', 'word-spacing', 'writing-mode', 'x', 'y']
}

pub fn normalized_diagonal_length(width f64, height f64) f64 {
	return math.sqrt((width * width + height * height) / 2)
}

pub fn parse_channel_selector(value string) ChannelSelector {
	return channel_selector(value)
}

pub fn parse_stitch_tiles(value string) StitchType {
	return stitch_type(value)
}

pub fn parse_turbulence_type(value string) TurbulenceType {
	return turbulence_type(value)
}

pub fn parse_type(value ?string) ComponentTransferType {
	return parse_component_transfer_type(value or { '' })
}

pub fn string_to_compositing_operator(value string) CompositeOperator {
	return composite_operator(value)
}

pub fn to_painting_spread_method(value SpreadMethod) SpreadMethod {
	return value
}

pub fn to_svg_fill_rule(value string) FillRule {
	return if value == 'evenodd' { .evenodd } else { .nonzero }
}

pub fn transform_from_transform_list(values []Transform) AffineTransform {
	return compose_transforms(values)
}

pub fn (gradient &LinearGradient) linked_linear_gradient(gradients map[string]LinearGradient) ?ResolvedLinearGradient {
	return resolve_linear_gradient(gradient.id, gradients)
}

pub fn (gradient &LinearGradient) start_x() NumberPercentage {
	return gradient.x1 or { percentage(0) }
}

pub fn (gradient &LinearGradient) start_x_impl() NumberPercentage {
	return gradient.start_x()
}

pub fn (gradient &LinearGradient) start_y() NumberPercentage {
	return gradient.y1 or { percentage(0) }
}

pub fn (gradient &LinearGradient) start_y_impl() NumberPercentage {
	return gradient.start_y()
}

pub fn (gradient &LinearGradient) end_x() NumberPercentage {
	return gradient.x2 or { percentage(100) }
}

pub fn (gradient &LinearGradient) end_x_impl() NumberPercentage {
	return gradient.end_x()
}

pub fn (gradient &LinearGradient) end_y() NumberPercentage {
	return gradient.y2 or { percentage(0) }
}

pub fn (gradient &LinearGradient) end_y_impl() NumberPercentage {
	return gradient.end_y()
}

pub fn (gradient &LinkedRadialGradient) linked_radial_gradient(gradients map[string]LinkedRadialGradient) ?ResolvedRadialGradient {
	return resolve_radial_gradient(gradient.id, gradients)
}

pub fn (gradient &LinkedRadialGradient) start_circle_x() NumberPercentage {
	return gradient.fx or { gradient.cx or { percentage(50) } }
}

pub fn (gradient &LinkedRadialGradient) start_circle_x_impl() NumberPercentage {
	return gradient.start_circle_x()
}

pub fn (gradient &LinkedRadialGradient) start_circle_y() NumberPercentage {
	return gradient.fy or { gradient.cy or { percentage(50) } }
}

pub fn (gradient &LinkedRadialGradient) start_circle_y_impl() NumberPercentage {
	return gradient.start_circle_y()
}

pub fn (gradient &LinkedRadialGradient) start_circle_radius() NumberPercentage {
	if radius := gradient.fr {
		if radius.value >= 0 {
			return radius
		}
	}
	return percentage(0)
}

pub fn (gradient &LinkedRadialGradient) start_circle_radius_impl() NumberPercentage {
	return gradient.start_circle_radius()
}

pub fn (gradient &LinkedRadialGradient) end_circle_x() NumberPercentage {
	return gradient.cx or { percentage(50) }
}

pub fn (gradient &LinkedRadialGradient) end_circle_x_impl() NumberPercentage {
	return gradient.end_circle_x()
}

pub fn (gradient &LinkedRadialGradient) end_circle_y() NumberPercentage {
	return gradient.cy or { percentage(50) }
}

pub fn (gradient &LinkedRadialGradient) end_circle_y_impl() NumberPercentage {
	return gradient.end_circle_y()
}

pub fn (gradient &LinkedRadialGradient) end_circle_radius() NumberPercentage {
	if radius := gradient.r {
		if radius.value >= 0 {
			return radius
		}
	}
	return percentage(50)
}

pub fn (gradient &LinkedRadialGradient) end_circle_radius_impl() NumberPercentage {
	return gradient.end_circle_radius()
}

pub fn (pattern &Pattern) linked_pattern(patterns map[string]Pattern) ?ResolvedPattern {
	return resolve_pattern(pattern.id, patterns)
}

pub fn (pattern &Pattern) pattern_x() NumberPercentage {
	return pattern.x or { number(0) }
}

pub fn (pattern &Pattern) pattern_x_impl() NumberPercentage {
	return pattern.pattern_x()
}

pub fn (pattern &Pattern) pattern_y() NumberPercentage {
	return pattern.y or { number(0) }
}

pub fn (pattern &Pattern) pattern_y_impl() NumberPercentage {
	return pattern.pattern_y()
}

pub fn (pattern &Pattern) pattern_width() NumberPercentage {
	return pattern.width or { number(0) }
}

pub fn (pattern &Pattern) pattern_width_impl() NumberPercentage {
	return pattern.pattern_width()
}

pub fn (pattern &Pattern) pattern_height() NumberPercentage {
	return pattern.height or { number(0) }
}

pub fn (pattern &Pattern) pattern_height_impl() NumberPercentage {
	return pattern.pattern_height()
}

pub fn (pattern &Pattern) pattern_units() Units {
	return pattern.units or { Units.object_bounding_box }
}

pub fn (pattern &Pattern) pattern_units_impl() Units {
	return pattern.pattern_units()
}

pub fn (pattern &Pattern) pattern_content_units() Units {
	return pattern.content_units or { Units.user_space_on_use }
}

pub fn (pattern &Pattern) pattern_content_units_impl() Units {
	return pattern.pattern_content_units()
}

pub fn (pattern &Pattern) pattern_transform() []Transform {
	return pattern.transform or { []Transform{} }
}

pub fn (pattern &Pattern) pattern_transform_impl() []Transform {
	return pattern.pattern_transform()
}

pub fn (pattern &Pattern) pattern_content_element(patterns map[string]Pattern) ?string {
	return pattern_content_id(pattern.id, patterns)
}

pub fn (pattern &Pattern) pattern_content_element_impl(patterns map[string]Pattern) ?string {
	return pattern.pattern_content_element(patterns)
}

pub fn (element &Element) linked_gradient() string {
	return local_fragment_identifier(element.href()) or { '' }
}

pub fn (element &Element) gradient_units() Units {
	return parse_units(element.attributes['gradientUnits'] or { '' }) or { Units.object_bounding_box }
}

pub fn (element &Element) gradient_units_impl() Units {
	return element.gradient_units()
}

pub fn (element &Element) gradient_transform() []Transform {
	return parse_transform(element.attributes['gradientTransform'] or { '' }) or { []Transform{} }
}

pub fn (element &Element) gradient_transform_impl() []Transform {
	return element.gradient_transform()
}

pub fn (element &Element) gradient_paint_transform() AffineTransform {
	return compose_transforms(element.gradient_transform())
}

pub fn (element &Element) spread_method() SpreadMethod {
	return parse_spread_method(element.attributes['spreadMethod'] or { '' }) or { SpreadMethod.pad }
}

pub fn (element &Element) spread_method_impl() SpreadMethod {
	return element.spread_method()
}

pub fn (element &Element) color_space() string {
	return element.attributes['color-interpolation'] or { 'sRGB' }
}

pub fn (element &Element) for_each_color_stop() []Stop {
	mut stops := []Stop{}
	for child in element.children {
		if child.tag == 'stop' {
			stops << Stop{ offset: child.stop_offset(), color: child.stop_color(), opacity: child.stop_opacity() }
		}
	}
	return normalized_stops(stops)
}

pub fn (element &Element) for_each_color_stop_impl() []Stop {
	return element.for_each_color_stop()
}

pub fn (element &Element) add_color_stops() []Stop {
	return element.for_each_color_stop()
}

pub fn (transfer &ComponentTransfer) amplitude() f64 {
	return transfer.amplitude
}

pub fn (transfer &ComponentTransfer) exponent() f64 {
	return transfer.exponent
}

pub fn (transfer &ComponentTransfer) intercept() f64 {
	return transfer.intercept
}

pub fn (transfer &ComponentTransfer) slope() f64 {
	return transfer.slope
}

pub fn (transfer &ComponentTransfer) table_values() []f64 {
	return transfer.table_values
}

pub fn (transfer &ComponentTransfer) table_float_values() []f32 {
	return transfer.table_values.map(f32(it))
}

pub fn (transfer &ComponentTransfer) type_from_attribute() ComponentTransferType {
	return transfer.type_
}

pub fn DecodedImageData.create(viewbox ?ViewBox, width ?f64, height ?f64) DecodedImageData {
	return DecodedImageData{
		viewbox: viewbox
		width: width
		height: height
		vector_content_identity_: DecodedImageData.next_vector_content_identity()
	}
}

// The host renderer stores the resulting raster and retained display list on
// this portable decoded-image record. Empty data still represents a document
// for which no painting surface has been produced.
pub fn (image &DecodedImageData) surface() []u8 {
	return image.surface_bytes.clone()
}

pub fn (image &DecodedImageData) render_to_surface() []u8 {
	return image.surface()
}

pub fn (mut image DecodedImageData) render_to_surface_sized(width int, height int) []u8 {
	if width <= 0 || height <= 0 || image.surface_bytes.len == 0 {
		return []u8{}
	}
	key := '${width}x${height}'
	if surface := image.cached_rendered_surfaces_[key] {
		return surface.clone()
	}
	if image.cached_rendered_surfaces_.len > 10 {
		for cached_key, _ in image.cached_rendered_surfaces_ {
			image.cached_rendered_surfaces_.delete(cached_key)
			break
		}
	}
	surface := image.surface_bytes.clone()
	image.cached_rendered_surfaces_[key] = surface
	return surface.clone()
}

pub fn (image &DecodedImageData) record_display_list() []string {
	return image.display_list_commands.clone()
}

pub fn (mut image DecodedImageData) prune_cached_display_list_resources() {
	if client := image.page_client_ {
		mut mutable_client := client
		mutable_client.prune_cached_display_list_resources()
	}
}

pub fn (image &DecodedImageData) append_cached_display_list_resources(mut retained_resources map[string]bool) {
	for _, cached in image.cached_display_lists_ {
		for resource in cached.referenced_resources {
			retained_resources[resource] = true
		}
	}
}

pub fn (image &DecodedImageData) append_paint_command_cache_source_resources(mut retained_resources map[string]bool) {
	for resource in image.paint_cache_source_resource_ids_ {
		retained_resources[resource] = true
	}
}

pub fn (mut image DecodedImageData) record_display_list_at_scale(css_size ViewportSize, raster_scale f64, color_scheme string) []string {
	key := RenderKey{
		css_size: css_size
		raster_scale: raster_scale
		color_scheme: color_scheme
	}
	cache_key := render_key_string(key)
	if cached := image.cached_display_lists_[cache_key] {
		return cached.commands.clone()
	}
	if image.cached_display_lists_.len > 10 {
		for stale_key, _ in image.cached_display_lists_ {
			image.cached_display_lists_.delete(stale_key)
			break
		}
		image.prune_cached_display_list_resources()
	}
	if image.color_scheme_ != color_scheme {
		image.color_scheme_ = color_scheme
		image.cached_rendered_frames.clear()
		image.cached_rendered_surfaces_.clear()
	}
	if client := image.page_client_ {
		mut mutable_client := client
		mutable_client.begin_recording_display_list()
	}
	image.begin_recording_display_list()
	commands := image.display_list_commands.clone()
	image.cached_display_lists_[cache_key] = CachedSVGDisplayList{
		commands: commands
		referenced_resources: image.referenced_resource_ids_.clone()
	}
	image.end_recording_display_list()
	if client := image.page_client_ {
		mut mutable_client := client
		mutable_client.end_recording_display_list()
	}
	image.prune_cached_display_list_resources()
	return commands.clone()
}

fn svg_raster_dimension(local_size f64, scale f64) int {
	effective_scale := if scale > 0 { scale } else { 1.0 }
	value := int(math.round(local_size * effective_scale))
	return if value < 1 { 1 } else if value > 16384 { 16384 } else { value }
}

pub fn (mut image DecodedImageData) image_paint(request SVGImagePaintRequest) ?SVGImagePaint {
	if request.destination.width <= 0 || request.destination.height <= 0 {
		return none
	}
	raster_width := svg_raster_dimension(request.destination.width, request.accumulated_scale.width)
	raster_height := svg_raster_dimension(request.destination.height, request.accumulated_scale.height)
	if image.has_active_view_box() {
		css_size := ViewportSize{ width: raster_width, height: raster_height }
		return SVGImagePaint{
			display_list_commands: image.record_display_list_at_scale(css_size, 1, request.color_scheme)
			css_size: css_size
			list_width: raster_width
			list_height: raster_height
		}
	}
	css_width := svg_raster_dimension(request.destination.width, 1)
	css_height := svg_raster_dimension(request.destination.height, 1)
	css_size := ViewportSize{ width: css_width, height: css_height }
	mut raster_scale := math.max(request.accumulated_scale.width, request.accumulated_scale.height)
	if raster_scale <= 0 {
		raster_scale = 1
	}
	maximum_scale := 16384.0 / math.max(css_size.width, css_size.height)
	raster_scale = math.min(raster_scale, maximum_scale)
	list_width := svg_raster_dimension(css_size.width, raster_scale)
	list_height := svg_raster_dimension(css_size.height, raster_scale)
	return SVGImagePaint{
		display_list_commands: image.record_display_list_at_scale(css_size, raster_scale, request.color_scheme)
		css_size: css_size
		raster_scale: raster_scale
		list_width: list_width
		list_height: list_height
	}
}

pub fn (image &DecodedImageData) paint() []u8 {
	return image.surface()
}

pub fn (_ &DecodedImageData) svg_document() string {
	return 'svg'
}

pub fn (primitive &FilterPrimitive) this_svg_element() FilterPrimitive {
	return *primitive
}

pub struct SVGPageClient {
pub:
	id_       u64
	headless_ bool
mut:
	device_pixels_per_css_pixel_     f64 = 1
	registered_svg_image_data_       []&DecodedImageData
	current_svg_image_data_          ?&DecodedImageData
	frame_request_suppression_count_ uint
	display_list_recording_count_    uint
	has_pending_resource_prune_      bool
	completed_resource_prune_count_  u64
	retained_display_list_resources_ map[string]bool
	display_list_resource_storage_   map[string]bool
	next_cross_process_id_           u64 = 1
}

pub fn SVGPageClient.create(id u64, headless bool) &SVGPageClient {
	return &SVGPageClient{ id_: id, headless_: headless }
}

pub fn (_ &SVGPageClient) is_svg_page_client() bool {
	return true
}

pub fn (_ &SVGPageClient) id() u64 {
	panic('SVGPageClient::id VERIFY_NOT_REACHED')
}

pub fn (client &SVGPageClient) is_headless() bool {
	return client.headless_
}

pub fn (_ &SVGPageClient) is_connection_open() bool {
	return false
}

pub fn (_ &SVGPageClient) device_pixel_ratio() f64 {
	return 1
}

pub fn (client &SVGPageClient) device_pixels_per_css_pixel() f64 {
	return client.device_pixels_per_css_pixel_
}

pub fn (mut client SVGPageClient) set_device_pixels_per_css_pixel(value f64) {
	client.device_pixels_per_css_pixel_ = value
}

pub fn (_ &SVGPageClient) zoom_level() f64 {
	return 1
}

pub fn (_ &SVGPageClient) screen_rect() Rect {
	return Rect{}
}

pub fn (_ &SVGPageClient) screen_count() int {
	return 1
}

pub fn (_ &SVGPageClient) preferred_color_scheme() string {
	return 'auto'
}

pub fn (_ &SVGPageClient) preferred_contrast() string {
	return 'auto'
}

pub fn (_ &SVGPageClient) preferred_motion() string {
	return 'auto'
}

pub fn (_ &SVGPageClient) palette() string {
	return 'default'
}

pub fn (_ &SVGPageClient) display_list_player_type() string {
	return 'software'
}

pub fn (client &SVGPageClient) page() u64 {
	return client.id_
}

pub fn (client &SVGPageClient) window() u64 {
	return client.id_
}

pub fn (_ &SVGPageClient) input_event_queue() []u64 {
	panic('SVGPageClient::input_event_queue VERIFY_NOT_REACHED')
}

pub fn (mut _ SVGPageClient) report_finished_handling_input_event(_ u64) {}

pub fn (_ &SVGPageClient) request_file(_ string) ?string {
	return none
}

pub fn (mut client SVGPageClient) allocate_cross_process_id() u64 {
	result := client.next_cross_process_id_
	client.next_cross_process_id_++
	return result
}

pub fn (mut client SVGPageClient) allocate_navigable_id() u64 {
	return client.allocate_cross_process_id()
}

pub fn (mut client SVGPageClient) register_svg_image_data(mut image DecodedImageData) {
	image.ensure_vector_content_identity()
	image.page_client_ = client
	for registered in client.registered_svg_image_data_ {
		if registered == &image {
			return
		}
	}
	client.registered_svg_image_data_ << &image
}

pub fn (client &SVGPageClient) registered_svg_image_count() int {
	return client.registered_svg_image_data_.len
}

pub fn (mut client SVGPageClient) set_current_svg_image_data(image ?&DecodedImageData) {
	client.current_svg_image_data_ = image
}

pub fn (client &SVGPageClient) current_svg_image_data() ?&DecodedImageData {
	return client.current_svg_image_data_
}

pub fn (mut client SVGPageClient) suppress_frame_requests() {
	client.frame_request_suppression_count_++
}

pub fn (mut client SVGPageClient) unsuppress_frame_requests() {
	assert client.frame_request_suppression_count_ > 0
	client.frame_request_suppression_count_--
}

pub fn (mut client SVGPageClient) request_frame() {
	if client.frame_request_suppression_count_ > 0 {
		return
	}
	if current := client.current_svg_image_data_ {
		mut image := current
		image.did_request_frame()
		return
	}
	for registered in client.registered_svg_image_data_ {
		mut image := registered
		image.did_request_frame()
	}
}

pub fn (mut client SVGPageClient) begin_recording_display_list() {
	client.display_list_recording_count_++
}

pub fn (mut client SVGPageClient) prune_cached_display_list_resources() {
	if client.display_list_recording_count_ > 0 {
		client.has_pending_resource_prune_ = true
		return
	}
	client.prune_cached_display_list_resources_now()
}

pub fn (mut client SVGPageClient) prune_cached_display_list_resources_now() {
	mut retained_resources := map[string]bool{}
	for registered in client.registered_svg_image_data_ {
		registered.append_cached_display_list_resources(mut retained_resources)
		registered.append_paint_command_cache_source_resources(mut retained_resources)
	}
	client.retained_display_list_resources_.clear()
	copy_referenced_resources_to(mut client.retained_display_list_resources_, client.display_list_resource_storage_, retained_resources.keys())
	client.completed_resource_prune_count_++
}

pub fn (mut client SVGPageClient) end_recording_display_list() {
	assert client.display_list_recording_count_ > 0
	client.display_list_recording_count_--
	if client.display_list_recording_count_ > 0 || !client.has_pending_resource_prune_ {
		return
	}
	client.has_pending_resource_prune_ = false
	client.prune_cached_display_list_resources_now()
}

pub fn (client &SVGPageClient) completed_resource_prune_count() u64 {
	return client.completed_resource_prune_count_
}

pub fn (mut client SVGPageClient) set_display_list_resource_storage(resources []string) {
	client.display_list_resource_storage_.clear()
	for resource in resources {
		client.display_list_resource_storage_[resource] = true
	}
}

pub fn (client &SVGPageClient) retained_display_list_resources() []string {
	mut resources := client.retained_display_list_resources_.keys()
	resources.sort()
	return resources
}

pub fn (_ &SvgViewport) current_scale() f64 {
	return 1
}

pub fn (mut _ SvgViewport) set_current_scale(_ f64) {}

pub fn (_ &SvgViewport) current_translate() Point {
	return Point{}
}

pub fn (viewport &SvgViewport) active_view_element() ?Element {
	return viewport.active_view_element_
}

pub fn (mut viewport SvgViewport) set_active_view_element(element ?Element) {
	viewport.active_view_element_ = element
}

pub fn (_ &SvgViewport) is_svg_container() bool {
	return true
}

pub fn (_ &SvgViewport) requires_svg_container() bool {
	return false
}

pub fn (mut viewport SvgViewport) set_fallback_view_box_for_svg_as_image(value ?ViewBox) {
	viewport.fallback_viewbox = value
}

pub fn (mut viewport SvgViewport) update_fallback_view_box_for_svg_as_image(width f64, height f64) {
	viewport.fallback_viewbox = if width > 0 && height > 0 {
		ViewBox{ width: width, height: height }
	} else {
		none
	}
}

pub fn (viewport &SvgViewport) width_style_value_from_attribute() ?f64 {
	return viewport.width
}

pub fn (viewport &SvgViewport) height_style_value_from_attribute() ?f64 {
	return viewport.height
}

pub struct NaturalMetrics {
pub:
	width        ?f64
	height       ?f64
	aspect_ratio ?f64
}

pub fn (viewport &SvgViewport) negotiate_natural_metrics() NaturalMetrics {
	width := viewport.width_style_value_from_attribute()
	height := viewport.height_style_value_from_attribute()
	mut aspect_ratio := ?f64(none)
	if width_value := width {
		if height_value := height {
			if width_value != 0 && height_value != 0 {
				aspect_ratio = width_value / height_value
			}
		}
	}
	if aspect_ratio == none {
		if active_view := viewport.active_view_element_ {
			if box := active_view.active_view_box() {
				if box.width != 0 || box.height != 0 {
					aspect_ratio = box.width / box.height
				}
			}
		}
	}
	if aspect_ratio == none {
		if box := viewport.fit.viewbox {
			if box.width != 0 && box.height != 0 {
				aspect_ratio = box.width / box.height
			}
		}
	}
	return NaturalMetrics{ width: width, height: height, aspect_ratio: aspect_ratio }
}

pub fn (_ &SvgViewport) suspend_redraw(_ int) int {
	return 1
}

pub fn (_ &SvgViewport) unsuspend_redraw(_ int) {}

pub fn (_ &SvgViewport) unsuspend_redraw_all() {}

pub fn (_ &SvgViewport) force_redraw() {}

pub fn (_ &SvgViewport) check_intersection(_ Rect, _ Rect) bool {
	return false
}

pub fn (_ &SvgViewport) check_enclosure(_ Rect, _ Rect) bool {
	return false
}

pub fn (_ &SvgViewport) get_intersection_list(_ Rect, _ []Element) []Element {
	return []
}

pub fn (_ &SvgViewport) get_enclosure_list(_ Rect, _ []Element) []Element {
	return []
}

// https://w3c.github.io/svgwg/svg2-draft/struct.html#__svg__SVGSVGElement__createSVGNumber
pub fn (_ &SvgViewport) create_svg_number() SvgNumber {
	return SvgNumber.create(0, false)
}

pub fn (_ &SvgViewport) create_svg_length() SvgLength {
	return SvgLength.create(0, .number, false)
}

pub fn (_ &SvgViewport) create_svg_matrix() AffineTransform {
	return AffineTransform{}
}

pub fn (_ &SvgViewport) create_svg_point() Point {
	return Point{}
}

pub fn (_ &SvgViewport) create_svg_rect() Rect {
	return Rect{}
}

pub fn (_ &SvgViewport) create_svg_transform() Transform {
	return Transform.create()
}
