module main

import dom
import html

$if macos {
	import math
}

import painting
import os

const retain_native_media_paint = os.getenv('VOX_RETAIN_NATIVE_MEDIA_PAINT') != ''
const retained_native_media_paint_diagnostics = os.getenv('VOX_RETAINED_NATIVE_MEDIA_PAINT_DIAGNOSTICS') != ''
// A decoded frame can advance the playback clock while repeating its pixels.
// Keep the visual identity in that case; preserve all ordinary media callbacks.
const skip_equal_native_video_writes = os.getenv('VOX_DISABLE_EQUAL_NATIVE_VIDEO_REUSE') == ''
const equal_native_video_write_diagnostics = os.getenv('VOX_EQUAL_NATIVE_VIDEO_WRITES_DIAGNOSTICS') != ''

$if macos {
	fn C.native_scroll_raster_diagnostic_time() f64
}

#flag darwin -framework CoreVideo
#flag darwin -framework CoreMedia

fn C.native_media_open(&char) voidptr
fn C.native_media_close(voidptr)
fn C.native_media_status(voidptr) i32
fn C.native_media_error(voidptr) &char
fn C.native_media_time(voidptr) f64
fn C.native_media_ended(voidptr) i32
fn C.native_media_take_ended(voidptr) i32
fn C.native_media_duration(voidptr) f64
fn C.native_media_audio(voidptr) i32
fn C.native_media_width(voidptr) i32
fn C.native_media_height(voidptr) i32
fn C.native_media_buffer_count(voidptr) i32
fn C.native_media_buffer_edge(voidptr, i32, i32) f64
fn C.native_media_buffering(voidptr) i32
fn C.native_media_play(voidptr, f64)
fn C.native_media_pause(voidptr)
fn C.native_media_volume(voidptr, f64)
fn C.native_media_seek(voidptr, f64, i32)
fn C.native_media_copy_frame(voidptr, &i32, &i32) &u8
fn C.native_media_free_frame(&u8)

@[heap]
struct BrowserMediaPlayback {
	media   &html.HTMLMediaElement
	element &dom.Element
mut:
	handle          voidptr
	metadata_loaded bool
	frame           ?&painting.MediaVideoFrame
}

fn browser_native_media_type(type_ string) html.CanPlayTypeResult {
	essence := type_.all_before(';').trim_space().to_lower()
	if essence !in ['video/mp4', 'video/quicktime', 'audio/mp4', 'audio/aac', 'audio/mpeg', 'audio/mp3',
		'audio/wav', 'audio/x-wav', 'audio/flac', 'application/vnd.apple.mpegurl',
		'application/x-mpegurl', 'audio/mpegurl', 'audio/x-mpegurl'] {
		return .empty
	}
	return .maybe
}

fn (mut player BrowserMediaPlayback) close() {
	$if macos {
		if player.handle != unsafe { nil } { C.native_media_close(player.handle) }
	}
	player.handle = unsafe { nil }
	player.frame = none
	player.metadata_loaded = false
}

fn (player &BrowserMediaPlayback) ranges() []html.MediaBufferedRange {
	mut ranges := []html.MediaBufferedRange{}
	$if macos {
		if player.handle == unsafe { nil } { return ranges }
		for index in 0 .. int(C.native_media_buffer_count(player.handle)) {
			ranges << html.MediaBufferedRange{
				start: C.native_media_buffer_edge(player.handle, i32(index), 0)
				end:   C.native_media_buffer_edge(player.handle, i32(index), 1)
			}
		}
	}
	return ranges
}

fn (mut player BrowserMediaPlayback) update_frame(pixels &u8, width int, height int) bool {
	return player.update_frame_with_pixel_reuse(pixels, width, height, skip_equal_native_video_writes)
}

fn (mut player BrowserMediaPlayback) update_frame_with_pixel_reuse(pixels &u8, width int,
	height int, reuse_equal_pixels bool) bool {
	// Reuse the pixel storage between frames, including in the prealloc build.
	// The document is invalidated below before retained painting reads it again.
	mut previous_generation := u64(0)
	if mut frame := player.frame {
		previous_generation = frame.generation
		if mut bitmap := frame.rgba_bitmap {
			if bitmap.width == width && bitmap.height == height {
				if reuse_equal_pixels && bitmap.data.len > 0
					&& unsafe { vmemcmp(bitmap.data.data, pixels, bitmap.data.len) == 0 } {
					$if macos {
						if equal_native_video_write_diagnostics {
							eprintln('VOX_EQUAL_NATIVE_VIDEO_WRITE reused=1 bytes=${bitmap.data.len} generation=${frame.generation} t_us=${C.native_scroll_raster_diagnostic_time():.3f}')
						}
					}
					return true
				}
				unsafe { vmemcpy(bitmap.data.data, pixels, bitmap.data.len) }
				// New pixels behind the same frame object: retained-paint
				// consumers identify them by this counter.
				frame.generation++
				return true
			}
		}
	}
	mut bytes := []u8{len: width * height * 4}
	unsafe { vmemcpy(bytes.data, pixels, bytes.len) }
	mut created := painting.MediaVideoFrame.from_bitmap(&dom.Bitmap_{
		width:                    width
		height:                   height
		pitch:                    width * 4
		data:                     bytes
		native_rows_are_top_down: true
	})
	created.generation = previous_generation + 1
	player.frame = created
	return false
}

// Same-size decoded frames update the retained VideoFrameSource in place.
// Preserve every ordinary pixel invalidation, including the full document
// revision, but do not rebuild unchanged geometry and paint transport.
fn (mut app BrowserApp) invalidate_native_media_frame(mut document dom.Document, stable bool) {
	if retain_native_media_paint && stable {
		if app.document != unsafe { nil } && voidptr(&document) == voidptr(app.document) {
			owner := u64(document.unique_id().value())
			if app.stationary_media_revision_owner != owner {
				app.stationary_media_revision_owner = owner
				app.stationary_media_revision_count = 0
			}
			app.stationary_media_revision_count++
		}
		document.set_needs_repaint_with_invalidation(.no)
		if retained_native_media_paint_diagnostics {
			eprintln('VOX_RETAINED_NATIVE_MEDIA_PAINT generation=${app.paint_generation}')
		}
		return
	}
	document.set_needs_repaint_with_invalidation(.paint_commands)
}

fn (mut app BrowserApp) install_media_playback(element &dom.Element) {
	install_video_poster_fetch_hook(element)
	$if macos {
		if !element.is_html_element() || element.local_name() !in ['audio', 'video'] { return }
		mut media := html.html_media_element_for_dom_element(element) or { return }
		app.install_native_media_player(element)
		// Parsed and fragment-parsed owners only now have a media model, after
		// their src attribute and insertion; run the skipped selection.
		media.queue_resource_selection_if_connected_and_empty()
	}
}

fn (mut app BrowserApp) install_native_media_player(element &dom.Element) {
	$if macos {
		mut media := html.html_media_element_for_dom_element(element) or { return }
		for player in app.media_players {
			if voidptr(player.media) == voidptr(media) { return }
		}
		player := &BrowserMediaPlayback{ media: media, element: element }
		app.media_players << player
		media.set_playback_manager_hooks(html.MediaPlaybackManagerHooks{
			can_play_type:       browser_native_media_type
			reset:               fn [player] () {
				mut p := unsafe { &BrowserMediaPlayback(player) }
				p.close()
			}
			play:                fn [player] () {
				C.native_media_play(player.handle, player.media.playback_rate())
			}
			pause:               fn [player] () { C.native_media_pause(player.handle) }
			set_volume:          fn [player] (volume f64) {
				C.native_media_volume(player.handle, volume)
			}
			set_playback_rate:   fn [player] (rate f32) {
				if !player.media.paused() { C.native_media_play(player.handle, rate) }
			}
			seek:                fn [player] (seconds f64, mode html.MediaPlaybackSeekMode) {
				C.native_media_seek(player.handle, seconds, if mode == .accurate {
					i32(0)
				} else {
					i32(1)
				})
			}
			current_time:        fn [player] () f64 { return C.native_media_time(player.handle) }
			has_ended:           fn [player] () bool { return C.native_media_ended(player.handle) != 0 }
			current_video_frame: fn [player] () ?&painting.MediaVideoFrame { return player.frame }
			buffered_ranges:     fn [player] () []html.MediaBufferedRange { return player.ranges() }
		})
		media.set_fetch_hook(fn [player] (source dom.URL, _ u64) !html.MediaResourceResponse {
			mut p := unsafe { &BrowserMediaPlayback(player) }
			p.close()
			p.handle = C.native_media_open(source.serialize().str)
			if p.handle == unsafe { nil } { return error('Unsupported native media URL') }
			C.native_wake_browser_after(16)
			return html.MediaResourceResponse{ mime_type: 'video/mp4', metadata_pending: true }
		})
	}
}

fn (mut app BrowserApp) install_document_media_playback() {
	// Media inserted after load (innerHTML, script-moved parsed fragments) may
	// never get a script wrapper, so configure it from its insertion steps.
	mut document := app.document
	document.set_media_element_inserted_hook(fn [app] (element &dom.Element) {
		// Materializing the owner can build its controls shadow tree, so do not
		// mutate the tree from inside the insertion steps.
		html.queue_an_element_task(element, .dom_manipulation, fn [app, element] () {
			mut owner := unsafe { &BrowserApp(app) }
			if voidptr(element.document()) != voidptr(owner.document)
				|| !element.as_node().is_connected() {
				return
			}
			owner.install_media_playback(element)
		})
	})
	root := unsafe { &dom.ParentNode(app.document) }
	list := root.query_selector_all('audio,video') or { return }
	for index in 0 .. list.length() {
		node := list.item(index) or { continue }
		element := node.as_element() or { continue }
		app.install_media_playback(element)
	}
}

fn (mut app BrowserApp) close_media_playback() {
	for mut player in app.media_players { player.close() }
	app.media_players = []&BrowserMediaPlayback{}
}

fn (mut app BrowserApp) poll_media_playback() {
	$if macos {
		for mut player in app.media_players {
			if player.handle == unsafe { nil } { continue }
			mut media := player.media
			status := C.native_media_status(player.handle)
			if status < 0 {
				message := C.native_media_error(player.handle)
				media.handle_media_source_failure(media.take_pending_play_promises(), if message == unsafe { nil } {
					'Native media playback failed'
				} else {
					unsafe { cstring_to_vstring(message).clone() }
				})
				continue
			}
			if status == 0 {
				C.native_wake_browser_after(16)
				continue
			}
			if !player.metadata_loaded {
				player.metadata_loaded = true
				width := C.native_media_width(player.handle)
				height := C.native_media_height(player.handle)
				duration := C.native_media_duration(player.handle)
				media.complete_pending_media_resource(html.MediaResourceResponse{
					mime_type:    'video/mp4'
					duration:     duration
					buffered_end: if math.is_finite(duration) { duration } else { 0 }
					audio_tracks: if C.native_media_audio(player.handle) != 0 {
						[html.MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
					} else {
						[]html.MediaTrackMetadata{}
					}
					video_tracks: if width > 0 && height > 0 {
						[html.MediaTrackMetadata{ identifier: 2, name: 'Video', pixel_width: u32(width), pixel_height: u32(height) }]
					} else {
						[]html.MediaTrackMetadata{}
					}
				})
				if !media.paused() { C.native_media_play(player.handle, media.playback_rate()) }
			}
			mut width := i32(0)
			mut height := i32(0)
			pixels := C.native_media_copy_frame(player.handle, &width, &height)
			if pixels != unsafe { nil } {
				stable := player.update_frame(pixels, int(width), int(height))
				C.native_media_free_frame(pixels)
				mut document := media.document() or { continue }
				app.invalidate_native_media_frame(mut document, stable)
			}
			media.on_playback_manager_state_change(C.native_media_buffering(player.handle) != 0)
			ended := C.native_media_take_ended(player.handle) != 0
			if ended {
				duration := C.native_media_duration(player.handle)
				if math.is_finite(duration) && duration != media.duration() {
					media.set_duration(duration)
				}
			}
			media.update_video_frame_and_timeline()
			if ended { media.reached_end_of_media_playback() }
			if !media.paused() { media.time_marches_on(.normal_playback) }
			// Continue polling while paused as well: loading, seeks and new frames
			// must complete without a playing clock or a JavaScript timer.
			C.native_wake_browser_after(if media.paused() { 100 } else { 16 })
		}
	}
}
