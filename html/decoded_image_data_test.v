@[has_globals]
module html

import dom

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
		BitmapDecodedImageFrame{ bitmap: bitmap, duration: 40 },
	], 2, true)
	assert data.frame_count() == 1
	assert data.loop_count() == 2
	assert data.is_animated()
	assert data.bitmap(0)? == bitmap
	assert data.bitmap(1) == none
	assert data.frame_duration(0) == 40
	assert data.frame_duration(1) == 0
	assert data.intrinsic_width()? == 320
	assert data.intrinsic_height()? == 200
	assert data.intrinsic_aspect_ratio()? == 1.6
	assert data.frame_rect(0)? == BitmapRect{
		width:  320
		height: 200
	}
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
	mut data := AnimatedDecodedImageData.create(77, 6, 3, 64, 32, [u32(10), 20, 30, 40, 50, 60], [
		frame0,
	], record_decoded_image_request, record_decoded_image_stop)
	assert data.bitmap(0)? == frame0
	// A missing frame falls back to the last displayed bitmap.
	assert data.bitmap(4)? == frame0
	assert data.notify_frame_advanced(1) == 1
	assert decoded_image_requests == ['77:2:4']
	animated_decoded_image_deliver_frames_for_session(77, [frame1])
	assert data.bitmap(2)? == frame1
	assert data.frame_duration(2) == 30
	assert data.intrinsic_aspect_ratio()? == 2.0
	data.finalize()
	assert decoded_image_stops == [i64(77)]
}
