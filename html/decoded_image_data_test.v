@[has_globals]
module html

import dom
import painting

__global (
	decoded_image_requests []string
	decoded_image_stops    []i64
)

fn record_decoded_image_request(session_id i64, start u32, count u32) {
	decoded_image_requests << '${session_id}:${start}:${count}'
}

fn record_decoded_image_stop(session_id i64) {
	decoded_image_stops << session_id
}

fn test_bitmap_decoded_image_data_accessors() {
	bitmap := &dom.ImmutableBitmap_{
		width:  320
		height: 200
	}
	data := BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(bitmap)
			duration: 40
		},
	], 2, true)
	assert data.frame_count() == 1
	assert data.loop_count() == 2
	assert data.is_animated()
	assert data.frame(0)?.bitmap() == bitmap
	assert data.frame(1) == none
	assert data.frame_duration(0) == 40
	assert data.frame_duration(1) == 0
	assert data.intrinsic_width()? == 320
	assert data.intrinsic_height()? == 200
	assert data.intrinsic_aspect_ratio()? == 1.6
	assert data.frame_rect(0)? == BitmapRect{
		width:  320
		height: 200
	}
	mut recorder := painting.new_display_list_recorder(painting.new_accumulated_visual_context_tree())
	assert data.paint(mut recorder, 0, painting.IntRect{ width: 10, height: 20 },
		painting.IntRect{ width: 10, height: 20 }, .bilinear)
	assert recorder.display_list.commands.len == 1
}

fn test_animated_decoded_image_data_pool_progression_and_delivery() {
	decoded_image_requests = []
	decoded_image_stops = []
	frame0 := &dom.ImmutableBitmap_{
		width:  64
		height: 32
	}
	frame1 := &dom.ImmutableBitmap_{
		width:  64
		height: 32
	}
	mut data := AnimatedDecodedImageData.create(77, 6, 3, 64, 32, .display_p3, [u32(10), 20, 30, 40, 50, 60], [
		frame0,
	], record_decoded_image_request, record_decoded_image_stop)
	assert html_animated_frame_delivery_callback_installed
	registry := AnimatedDecodedImageData.session_registry()
	assert registry[i64(77)] or { panic('missing session') } == data
	assert data.find_slot(0)?.frame?.bitmap() == frame0
	assert data.find_slot(0)?.frame?.color_space() == .display_p3
	mut evicted := data.evict_oldest_slot()
	assert evicted.generation == 0
	assert data.frame(0)?.bitmap() == frame0
	// A missing frame falls back to the last displayed bitmap.
	assert data.frame(4)?.bitmap() == frame0
	assert data.notify_frame_advanced(1) == 1
	assert decoded_image_requests == ['77:2:4']
	AnimatedDecodedImageData.deliver_frames_for_session(77, [frame1])
	assert data.frame(2)?.bitmap() == frame1
	assert data.frame(2)?.color_space() == .display_p3
	assert data.frame_duration(2) == 30
	assert data.intrinsic_aspect_ratio()? == 2.0
	mut recorder := painting.new_display_list_recorder(painting.new_accumulated_visual_context_tree())
	assert data.paint(mut recorder, 2, painting.IntRect{ width: 10, height: 10 },
		painting.IntRect{ width: 10, height: 10 }, .nearest_neighbor)
	data.finalize()
	assert decoded_image_stops == [i64(77)]
}
