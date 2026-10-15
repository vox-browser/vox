module layout

import dom
import html

$if gcboehm ? { fn C.GC_gcollect() }

fn vtd_document(poster_width int) (&dom.Document, &dom.Element, &html.HTMLVideoElementModel) {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}video{display:block;width:80px;height:40px}</style><video id="video"></video>')
	element := document.get_element_by_id('video') or { panic('missing video') }
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	mut media := model.media
	media.set_ready_state(.have_enough_data)
	media.set_paused(false)
	model.set_current_frame(&dom.Bitmap_{width: 4, height: 2, pitch: 16,
		data: [u8(0), 0, 255, 255].repeat(8)})
	model.set_poster_fetch_hook(fn [poster_width] (_ dom.URL) !&dom.Bitmap_ {
		return &dom.Bitmap_{width: poster_width, height: 2, pitch: poster_width * 4,
			data: [u8(255), 0, 0, 255].repeat(poster_width * 2)}
	})
	model.set_poster('https://video-list.example/poster.png')
	_ = layout_document_typed_in_viewport(document, 240, 160)
	return document, element, model
}

fn vtd_track() &html.VideoTrack {
	return html.VideoTrack.create(html.MediaTrackMetadata{identifier: 42}, fn () {}, fn (_ ?&html.VideoTrack) {})
}

fn vtd_command(mut document dom.Document) PaintCommand {
	list := document.record_display_list() or { panic('missing display list') }
	for command in display_list_commands(list) {
		if command.kind == 'draw_video' { return command }
	}
	panic('missing video paint command')
}

fn test_video_track_membership_recomputes_natural_size_without_selection_change() {
	mut document, element, mut model := vtd_document(13)
	defer { document.finalize() }
	mut list := model.media.video_tracks()
	track := vtd_track()
	assert model.current_representation() == .poster_frame
	assert model.natural_element_size()? == html.VideoDimensions{13, 2}
	list.add_track(track)
	assert model.natural_element_size()? == html.VideoDimensions{4, 2}
	assert model.current_representation() == .video_frame
	assert list.selected_index() == -1 && !track.selected
	assert element.as_node().unsafe_layout_node()?.needs_layout_update()
	_ = layout_document_typed_in_viewport(document, 240, 160)
	list.remove_all_tracks()
	assert model.natural_element_size()? == html.VideoDimensions{13, 2}
	assert model.current_representation() == .poster_frame && list.length() == 0
	assert track.video_track_list == none && !track.selected
	assert element.as_node().unsafe_layout_node()?.needs_layout_update()
	assert model.natural_media_size()? == html.VideoDimensions{4, 2}
	assert model.media.event_count('resize') == 0
}

fn test_video_track_insertion_refreshes_equal_size_retained_poster_paint() {
	mut document, element, model := vtd_document(4)
	defer { document.finalize() }
	initial := vtd_command(mut document)
	assert initial.video_representation == .poster_frame
	poster := initial.video_bitmap or { panic('missing retained poster') }
	result := document_layout_result(document) or { panic('missing retained layout') }
	root := voidptr(result.root)
	mut list := model.media.video_tracks()
	track := vtd_track()
	list.add_track(track)
	$if gcboehm ? { C.GC_gcollect() }
	updated := vtd_command(mut document)
	assert updated.video_representation == .video_frame && updated.video_bitmap == none
	source := updated.video_frame_source or { panic('missing retained frame source') }
	frame := source.current_frame() or { panic('missing retained frame') }
	assert (frame.to_bitmap() or { panic(err) }).data[..4] == [u8(0), 0, 255, 255]
	assert model.natural_element_size()? == html.VideoDimensions{4, 2}
	assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	assert voidptr(result.root) == root && list.item(0)? == track && !track.selected
	assert initial.video_representation == .poster_frame
	assert voidptr(initial.video_bitmap?) == voidptr(poster)
	assert poster.data[..4] == [u8(255), 0, 0, 255]
}

fn test_video_track_removal_refreshes_equal_size_retained_video_paint_after_clear() {
	mut document, element, mut model := vtd_document(4)
	defer { document.finalize() }
	mut list := model.media.video_tracks()
	track := vtd_track()
	list.add_track(track)
	// Seed the initial paint explicitly, independently of insertion notification.
	model.update_natural_dimensions()
	initial := vtd_command(mut document)
	assert initial.video_representation == .video_frame
	source := initial.video_frame_source or { panic('missing initial video source') }
	list.remove_all_tracks()
	$if gcboehm ? { C.GC_gcollect() }
	updated := vtd_command(mut document)
	assert updated.video_representation == .poster_frame && updated.video_frame_source == none
	assert voidptr(updated.video_bitmap?) == voidptr(model.poster_frame()?)
	assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	assert model.natural_element_size()? == html.VideoDimensions{4, 2}
	assert list.length() == 0 && list.selected_index() == -1
	assert track.video_track_list == none && !track.selected
	assert initial.video_representation == .video_frame
	assert voidptr(initial.video_frame_source?) == voidptr(source)
	// Reusing a detached track in an ownerless list does not notify its old owner.
	mut standalone := &html.VideoTrackList{}
	standalone.add_track(track)
	standalone.remove_all_tracks()
	assert model.current_representation() == .poster_frame
	assert model.media.event_count('addtrack') == 0 && model.media.event_count('resize') == 0
}
