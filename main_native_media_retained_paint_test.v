module main

import dom
import html
import layout
import painting

fn test_native_media_frame_storage_preserves_identity_and_advances_pixels() {
	mut document := html.parse_document('<!doctype html><video id="video"></video>')
	defer { document.finalize() }
	element := document.get_element_by_id('video')?
	media := html.html_media_element_for_dom_element(element)?
	mut player := BrowserMediaPlayback{media: media, element: element}
	mut pixels := [u8(255),0,0,255,0,255,0,255]
	assert !player.update_frame(pixels.data, 2, 1)
	mut source := painting.VideoFrameSource.create()
	source.update(player.frame)
	frame := source.current_frame()?
	command := layout.PaintCommand{kind: 'draw_video', width: 2, height: 1, video_frame_source: source}
	before := scroll_raster_command_hash(&command, 0)
	pixels[0] = 11
	assert player.update_frame(pixels.data, 2, 1)
	assert voidptr(source.current_frame()?) == voidptr(frame)
	assert source.current_frame()?.generation == 2
	assert source.current_frame()?.to_bitmap()!.data[0] == 11
	assert scroll_raster_command_hash(&command, 0) != before
	mut larger := []u8{len: 16, init: 77}
	assert !player.update_frame(larger.data, 2, 2)
	assert player.frame?.generation == 3
	assert voidptr(player.frame?) != voidptr(frame)
}

fn test_native_media_retained_paint_keeps_the_full_revision_and_other_invalidations() {
	mut document := html.parse_document('<!doctype html><div>retained</div>')
	defer { document.finalize() }
	mut app := BrowserApp{document: document}
	app.relayout(200, 232)
	list := document.cached_display_list()?
	revision := document.paint_content_revision()
	generation := app.paint_generation
	app.invalidate_native_media_frame(mut document, true)
	assert document.paint_content_revision() == revision + 1
	if retain_native_media_paint {
		assert voidptr(document.cached_display_list()?) == voidptr(list)
		assert app.stationary_media_revision_count == 1
		if !disable_offscreen_video_stationary_reuse {
			assert app.stationary_document_revision() == revision
		}
		app.begin_frame_preparation()
		app.finish_frame_preparation()
		assert app.paint_generation == generation
		document.set_needs_repaint_with_invalidation(.no)
		if !disable_offscreen_video_stationary_reuse {
			assert app.stationary_document_revision() == revision + 1
		}
	} else {
		assert document.cached_display_list() == none
		assert app.stationary_media_revision_count == 0
	}
	app.invalidate_native_media_frame(mut document, false)
	assert document.cached_display_list() == none
	assert document.paint_content_revision() == revision + 2 + u64(retain_native_media_paint)
}

fn test_retained_video_commands_observe_new_frames_without_transport_replacement() {
	mut document := html.parse_document('<!doctype html><video id="video" style="width:80px;height:40px"></video>')
	defer { document.finalize() }
	element := document.get_element_by_id('video')?
	mut media := html.html_media_element_for_dom_element(element)?
	mut player := &BrowserMediaPlayback{media: media, element: element}
	mut pixels := [u8(255),0,0,255,0,255,0,255]
	assert !player.update_frame(pixels.data, 2, 1)
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_video_frame: fn [player] () ?&painting.MediaVideoFrame { return player.frame }
	})
	media.set_ready_state(.have_current_data)
	media.on_video_track_added(html.MediaTrackMetadata{identifier: 1, pixel_width: 2, pixel_height: 1})
	media.update_video_frame_and_timeline()
	mut app := BrowserApp{document: document}
	app.relayout(200, 232)
	mut video_index := -1
	for index, command in app.paint_commands {
		if command.kind == 'draw_video' && command.video_frame_source != none { video_index = index; break }
	}
	assert video_index >= 0
	list := document.cached_display_list()?
	generation := app.paint_generation
	before := scroll_raster_command_hash(&app.paint_commands[video_index], 0)
	pixels[0] = 17
	stable := player.update_frame(pixels.data, 2, 1)
	assert stable
	app.invalidate_native_media_frame(mut document, stable)
	media.update_video_frame_and_timeline()
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	if retain_native_media_paint {
		assert app.paint_generation == generation
		assert voidptr(document.cached_display_list()?) == voidptr(list)
		assert scroll_raster_command_hash(&app.paint_commands[video_index], 0) != before
	}
}

fn test_retained_media_revision_counts_stay_with_their_document() {
	if !retain_native_media_paint { return }
	mut first := html.parse_document('<!doctype html><div>first</div>')
	mut second := html.parse_document('<!doctype html><div>second</div>')
	defer { second.finalize(); first.finalize() }
	mut app := BrowserApp{document: first}
	app.invalidate_native_media_frame(mut first, true)
	owner := app.stationary_media_revision_owner
	count := app.stationary_media_revision_count
	app.invalidate_native_media_frame(mut second, true)
	assert app.stationary_media_revision_owner == owner && app.stationary_media_revision_count == count
	app.document = second
	assert app.stationary_document_revision() == second.paint_content_revision()
	app.invalidate_native_media_frame(mut second, true)
	assert app.stationary_media_revision_owner != owner && app.stationary_media_revision_count == 1
}
