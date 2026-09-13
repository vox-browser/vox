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
	assert image.external_memory_size() == 8

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

	client.set_current_svg_image_data(first)
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
