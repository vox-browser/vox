module layout

import dom
import html

$if gcboehm ? { fn C.GC_gcollect() }

@[heap]
struct VprClock {
mut:
	position f64
}

fn vpr_document(position f64, poster bool) (&dom.Document, &dom.Element, &html.HTMLVideoElementModel, &VprClock) {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}video{display:block;width:80px;height:40px}</style><video id="video"></video>')
	element := document.get_element_by_id('video') or { panic('missing video') }
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	mut media := model.media
	clock := &VprClock{position: position}
	media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
		current_time: fn [clock] () f64 { return clock.position }
	})
	media.on_video_track_added(html.MediaTrackMetadata{identifier: 1, pixel_width: 4, pixel_height: 2})
	media.set_ready_state(.have_enough_data)
	model.set_current_frame(&dom.Bitmap_{width: 4, height: 2, pitch: 16,
		data: [u8(0), 0, 255, 255].repeat(8)})
	if poster {
		model.set_poster_fetch_hook(fn (_ dom.URL) !&dom.Bitmap_ {
			return &dom.Bitmap_{width: 4, height: 2, pitch: 16,
				data: [u8(255), 0, 0, 255].repeat(8)}
		})
		model.set_poster('https://video-position.example/poster.png')
	}
	media.set_official_playback_position(position)
	_ = layout_document_typed_in_viewport(document, 240, 160)
	return document, element, model, clock
}

fn vpr_command(mut document dom.Document) PaintCommand {
	list := document.record_display_list() or { panic('missing video display list') }
	for command in display_list_commands(list) {
		if command.kind == 'draw_video' { return command }
	}
	panic('missing video paint command')
}

fn test_video_paint_leaves_poster_when_backend_moves_but_script_time_stays_zero() {
	mut document, element, model, mut clock := vpr_document(0, true)
	defer { document.finalize() }
	mut media := model.media
	initial := vpr_command(mut document)
	assert initial.video_representation == .poster_frame
	poster := initial.video_bitmap or { panic('missing initial poster') }
	assert media.current_time() == 0 && media.paused() && media.show_poster()
	result := document_layout_result(document) or { panic('missing retained layout') }
	root := voidptr(result.root)
	clock.position = 7
	media.update_video_frame_and_timeline()
	assert model.current_representation() == .video_frame
	assert media.current_time() == 0 && media.current_playback_position() == 7
	assert model.natural_element_size()? == html.VideoDimensions{4, 2}
	assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	$if gcboehm ? { C.GC_gcollect() }
	updated := vpr_command(mut document)
	assert updated.video_representation == .video_frame && updated.video_bitmap == none
	source := updated.video_frame_source or { panic('missing live video source') }
	frame := source.current_frame() or { panic('missing live video frame') }
	assert (frame.to_bitmap() or { panic(err) }).data[..4] == [u8(0), 0, 255, 255]
	assert initial.video_representation == .poster_frame
	assert voidptr(initial.video_bitmap?) == voidptr(poster)
	assert poster.data[..4] == [u8(255), 0, 0, 255]
	assert voidptr(result.root) == root && media.current_time() == 0
	assert media.event_count('timeupdate') == 0 && media.event_count('resize') == 0
}

fn test_video_paint_returns_to_poster_while_script_time_retains_nonzero_sample() {
	mut document, element, model, mut clock := vpr_document(7, true)
	defer { document.finalize() }
	mut media := model.media
	initial := vpr_command(mut document)
	assert initial.video_representation == .video_frame && initial.video_bitmap == none
	source := initial.video_frame_source or { panic('missing original video source') }
	assert media.current_time() == 7 && media.paused() && media.show_poster()
	clock.position = 0
	media.update_video_frame_and_timeline()
	assert model.current_representation() == .poster_frame
	assert media.current_time() == 7 && media.current_playback_position() == 0
	assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	updated := vpr_command(mut document)
	assert updated.video_representation == .poster_frame && updated.video_frame_source == none
	poster := updated.video_bitmap or { panic('missing restored poster') }
	assert voidptr(poster) == voidptr(model.poster_frame()?)
	assert poster.data[..4] == [u8(255), 0, 0, 255]
	assert initial.video_representation == .video_frame
	assert voidptr(initial.video_frame_source?) == voidptr(source)
	assert media.current_time() == 7
}

fn test_video_paint_returns_to_first_frame_without_poster_despite_cached_script_time() {
	mut document, element, model, mut clock := vpr_document(7, false)
	defer { document.finalize() }
	mut media := model.media
	initial := vpr_command(mut document)
	assert initial.video_representation == .video_frame
	assert media.current_time() == 7 && model.poster_frame() == none
	clock.position = 0
	media.update_video_frame_and_timeline()
	assert model.current_representation() == .first_video_frame
	assert media.current_time() == 7 && media.current_playback_position() == 0
	assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	updated := vpr_command(mut document)
	assert updated.video_representation == .first_video_frame && updated.video_bitmap == none
	assert voidptr(updated.video_frame_source?) == voidptr(initial.video_frame_source?)
	assert model.natural_element_size()? == html.VideoDimensions{4, 2}
	assert media.paused() && media.show_poster() && media.current_time() == 7
}
