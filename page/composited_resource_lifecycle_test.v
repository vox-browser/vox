module page

import dom

fn test_page_media_lifecycle_is_document_scoped_and_tracks_video_sinks() {
	mut model := Page.create(1.0)!
	first_document := dom.Document.create_for_fragment_parsing()
	second_document := dom.Document.create_for_fragment_parsing()
	model.register_media_element(1, MediaElementState{
		document_id: first_document.unique_id()
		playing_audio: true
		is_video: true
		has_video_sink: true
		video_sink_attached: true
	})
	model.register_media_element(2, MediaElementState{
		document_id: second_document.unique_id()
		playing_audio: true
	})
	assert model.has_media_element_playing_audio(first_document)
	assert model.has_media_element_playing_audio(second_document)
	mut silent_document := dom.Document.create_for_fragment_parsing()
	assert !model.has_media_element_playing_audio(silent_document)

	model.sync_media_element_video_sink_ticking()
	first_media := model.media_elements[1] or { panic('missing first media element') }
	second_media := model.media_elements[2] or { panic('missing second media element') }
	assert first_media.video_sink_sync_count == 1
	assert first_media.video_paint_facts_push_count == 1
	assert second_media.video_sink_sync_count == 1
	assert second_media.video_paint_facts_push_count == 0

	model.detach_all_media_element_video_sinks_after_compositor_lost()
	detached_media := model.media_elements[1] or { panic('missing first media element') }
	untouched_media := model.media_elements[2] or { panic('missing second media element') }
	assert !detached_media.video_sink_attached
	assert detached_media.video_sink_detach_count == 1
	assert untouched_media.video_sink_detach_count == 0
	model.restore_all_media_element_video_sinks()
	restored_media := model.media_elements[1] or { panic('missing first media element') }
	assert restored_media.video_sink_attached
	assert restored_media.video_sink_restore_count == 1
}

fn test_page_canvas_preparation_updates_generations_and_flushes_the_stream() {
	mut model := Page.create(1.0)!
	assert model.canvas_element_state(99) == none
	mut client := model.client()
	client.compositor_supported_ = true
	model.ensure_compositor_host()
	mut host := model.compositor_host()
	host.append_canvas_2d_command('present:7')
	model.register_canvas_element_with_state(7, CanvasElementState{
		context_kind: .canvas_2d
		dirty: true
	})
	model.register_canvas_element_with_state(8, CanvasElementState{
		context_kind: .webgl
	})

	model.prepare_canvas_contexts_for_compositing()
	first := model.canvas_element_state(7) or { panic('missing 2D canvas') }
	assert !first.dirty
	assert first.content_generation == 1
	assert first.context_prepare_count == 1
	assert first.paint_facts_push_count == 1
	assert host.canvas_2d_batches() == [['present:7']]

	model.prepare_canvas_contexts_for_compositing()
	second := model.canvas_element_state(7) or { panic('missing 2D canvas') }
	assert second.content_generation == 1
	assert second.context_prepare_count == 1
	assert second.prepare_call_count == 2
	assert second.paint_facts_push_count == 2

	model.notify_all_canvas_elements_of_lost_backing_storage()
	assert (model.canvas_element_state(7)?).backing_storage_loss_count == 1
	assert (model.canvas_element_state(8)?).webgl_restore_count == 1
	model.notify_all_webgl_contexts_lost()
	assert !(model.canvas_element_state(7)?).webgl_context_lost
	assert (model.canvas_element_state(8)?).webgl_context_lost
	assert (model.canvas_element_state(8)?).webgl_connection_loss_count == 1
}
