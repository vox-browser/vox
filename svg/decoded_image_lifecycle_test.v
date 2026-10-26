module svg

fn test_decoded_svg_image_caches_frames_and_invalidates_identity() {
	mut image := &DecodedImageData{
		viewbox: ViewBox{ width: 20, height: 10 }
		width: 20
		height: 10
		surface_bytes: [u8(1), 2, 3, 4]
		vector_content_identity_: DecodedImageData.next_vector_content_identity()
	}
	initial_identity := image.vector_content_identity()
	assert initial_identity != 0
	assert image.has_active_view_box()

	first := image.current_frame(20, 10) or { panic('missing frame') }
	second := image.default_frame(20, 10) or { panic('missing default frame') }
	assert first == second
	// Upstream retains both the replay surface and its immutable decoded frame.
	assert image.external_memory_size() == 12

	image.did_request_frame()
	assert image.vector_content_identity() != initial_identity
	assert image.has_pending_client_notification()
	assert image.external_memory_size() == 4
	assert image.deliver_pending_client_notification()
	assert !image.deliver_pending_client_notification()
	assert image.delivered_client_notification_count() == 1
}

fn test_decoded_svg_image_ignores_frame_requests_while_recording() {
	mut image := DecodedImageData.create(none, 10, 10)
	initial_identity := image.vector_content_identity()
	assert !image.has_active_view_box()

	image.begin_recording_display_list()
	image.did_request_frame()
	assert image.vector_content_identity() == initial_identity
	assert !image.has_pending_client_notification()
	image.end_recording_display_list()
}

fn test_svg_page_client_routes_and_suppresses_frame_requests() {
	mut first := DecodedImageData.create(none, 10, 10)
	mut second := DecodedImageData.create(none, 20, 20)
	mut client := SVGPageClient.create(7, true)
	client.register_svg_image_data(mut first)
	client.register_svg_image_data(mut second)
	client.register_svg_image_data(mut first)
	assert client.registered_svg_image_count() == 2

	client.suppress_frame_requests()
	client.request_frame()
	assert !first.has_pending_client_notification()
	assert !second.has_pending_client_notification()
	client.unsuppress_frame_requests()

	client.set_current_svg_image_data(&first)
	client.request_frame()
	assert first.has_pending_client_notification()
	assert !second.has_pending_client_notification()
	first.deliver_pending_client_notification()

	client.set_current_svg_image_data(none)
	client.request_frame()
	assert first.has_pending_client_notification()
	assert second.has_pending_client_notification()
}

fn test_svg_page_client_defers_resource_pruning_while_recording() {
	mut client := SVGPageClient.create(1, false)
	client.set_device_pixels_per_css_pixel(2.5)
	assert client.device_pixels_per_css_pixel() == 2.5
	assert client.allocate_cross_process_id() != client.allocate_navigable_id()

	client.begin_recording_display_list()
	client.begin_recording_display_list()
	client.prune_cached_display_list_resources()
	assert client.completed_resource_prune_count() == 0
	client.end_recording_display_list()
	assert client.completed_resource_prune_count() == 0
	client.end_recording_display_list()
	assert client.completed_resource_prune_count() == 1
}

fn test_decoded_svg_image_paint_selects_viewbox_and_css_scaled_recordings() {
	mut viewbox_image := DecodedImageData{
		viewbox: ViewBox{ width: 20, height: 10 }
		display_list_commands: ['draw-vector-content']
		vector_content_identity_: DecodedImageData.next_vector_content_identity()
	}
	viewbox_paint := viewbox_image.image_paint(SVGImagePaintRequest{
		destination: Rect{ width: 20, height: 10 }
		accumulated_scale: ViewportSize{ width: 2, height: 3 }
		color_scheme: 'dark'
	}) or { panic('missing viewBox paint') }
	assert viewbox_paint.css_size == ViewportSize{ width: 40, height: 30 }
	assert viewbox_paint.raster_scale == 1
	assert viewbox_paint.list_width == 40
	assert viewbox_paint.list_height == 30
	assert viewbox_image.color_scheme() == 'dark'
	assert viewbox_image.cached_display_list_count() == 1

	mut viewport_image := DecodedImageData{
		display_list_commands: ['draw-viewport-content']
		vector_content_identity_: DecodedImageData.next_vector_content_identity()
	}
	viewport_paint := viewport_image.image_paint(SVGImagePaintRequest{
		destination: Rect{ width: 20, height: 10 }
		accumulated_scale: ViewportSize{ width: 2, height: 3 }
	}) or { panic('missing viewport paint') }
	assert viewport_paint.css_size == ViewportSize{ width: 20, height: 10 }
	assert viewport_paint.raster_scale == 3
	assert viewport_paint.list_width == 60
	assert viewport_paint.list_height == 30
	assert viewport_image.cached_display_list_count() == 1
	_ = viewport_image.image_paint(SVGImagePaintRequest{
		destination: Rect{ width: 20, height: 10 }
		accumulated_scale: ViewportSize{ width: 2, height: 3 }
	}) or { panic('missing cached viewport paint') }
	assert viewport_image.cached_display_list_count() == 1
}

fn test_decoded_svg_image_prunes_only_unreferenced_display_list_resources() {
	mut image := DecodedImageData{
		display_list_commands: ['paint']
		vector_content_identity_: DecodedImageData.next_vector_content_identity()
	}
	image.set_display_list_resource_ids(['bitmap', 'gradient'], ['glyph'])
	mut client := SVGPageClient.create(12, true)
	client.set_display_list_resource_storage(['bitmap', 'gradient', 'glyph', 'stale'])
	client.register_svg_image_data(mut image)
	_ = image.record_display_list_at_scale(ViewportSize{ width: 10, height: 10 }, 2,
		'light')
	assert client.retained_display_list_resources() == ['bitmap', 'glyph', 'gradient']

	image.invalidate_cached_rendering()
	assert client.retained_display_list_resources() == ['glyph']
	assert surface_external_memory_size(20, 10) == 800
	assert surface_external_memory_size(0, 10) == 0
	traits := RenderKeyTraits{}
	key := RenderKey{ css_size: ViewportSize{ width: 10, height: 10 }, raster_scale: 2 }
	assert traits.equals(key, key)
	assert traits.hash(key) != traits.hash(RenderKey{
		css_size: ViewportSize{ width: 10, height: 10 }
		raster_scale: 3
	})
}
