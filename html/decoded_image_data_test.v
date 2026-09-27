@[has_globals]
module html

import dom
import painting

__global (
	decoded_image_requests []string
	decoded_image_stops    []i64
	decoded_image_updates  int
)

fn record_decoded_image_request(session_id i64, start u32, count u32) {
	decoded_image_requests << '${session_id}:${start}:${count}'
}

fn record_decoded_image_stop(session_id i64) {
	decoded_image_stops << session_id
}

fn record_decoded_image_update() {
	decoded_image_updates++
}

fn test_bitmap_decoded_image_data_accessors() {
	bitmap := &dom.Bitmap_{
		width:  320
		height: 200
		data:   [u8(1), 2, 3, 4]
	}
	data := BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{
			frame:    dom.DecodedImageFrame_.create(bitmap)
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
	assert data.external_memory_size() == 4
	assert !data.has_clients()
	assert !data.is_cors_cross_origin()
	data.set_is_cors_cross_origin(true)
	assert data.is_cors_cross_origin()
	decoded_image_data_register_client(data, 11, record_decoded_image_update)
	assert data.has_clients()
	decoded_image_data_unregister_client(data, 11)
	assert !data.has_clients()
	mut recorder := painting.new_display_list_recorder(painting.new_accumulated_visual_context_tree())
	assert data.paint(mut recorder, 0, painting.IntRect{ width: 10, height: 20 }, painting.IntRect{ width: 10, height: 20 }, .bilinear)
	assert recorder.display_list.commands.len == 1
}

fn test_animated_decoded_image_data_pool_progression_and_delivery() {
	decoded_image_requests = []
	decoded_image_stops = []
	decoded_image_updates = 0
	frame0 := &dom.Bitmap_{
		width:  64
		height: 32
	}
	frame1 := &dom.Bitmap_{
		width:  64
		height: 32
	}
	mut data := AnimatedDecodedImageData.create(77, 6, 3, 64, 32, .display_p3, [
		u32(10),
		20,
		30,
		40,
		50,
		60,
	], [
		frame0,
	], record_decoded_image_request, record_decoded_image_stop)
	assert html_animated_frame_delivery_callback_installed
	registry := AnimatedDecodedImageData.session_registry()
	assert registry[i64(77)] or { panic('missing session') } == data
	assert data.find_slot(0)?.frame?.bitmap() == frame0
	assert data.find_slot(0)?.frame?.color_space() == .display_p3
	assert data.external_memory_size() == 6 * sizeof(u32)
	assert !data.has_clients()
	assert !data.is_cors_cross_origin()
	data.set_is_cors_cross_origin(true)
	assert data.is_cors_cross_origin()
	mut evicted := data.evict_oldest_slot()
	assert evicted.generation == 0
	assert data.frame(0)?.bitmap() == frame0
	// A missing frame falls back to the last displayed bitmap.
	assert data.frame(4)?.bitmap() == frame0
	data.register_client(42, record_decoded_image_update)
	assert data.has_clients()
	assert data.debug_state().client_count == 1
	assert data.debug_state().timer_active
	assert data.animation_timer.interval() == 10
	data.animation_timer.fire()
	assert data.debug_state().frame_index == 1
	assert decoded_image_updates == 1
	assert decoded_image_requests == ['77:2:4']
	AnimatedDecodedImageData.deliver_frames_for_session(77, [frame1])
	assert data.frame(2)?.bitmap() == frame1
	assert data.frame(2)?.color_space() == .display_p3
	assert data.frame_duration(2) == 30
	assert data.intrinsic_aspect_ratio()? == 2.0
	mut recorder := painting.new_display_list_recorder(painting.new_accumulated_visual_context_tree())
	assert data.paint(mut recorder, 2, painting.IntRect{ width: 10, height: 10 }, painting.IntRect{ width: 10, height: 10 }, .nearest_neighbor)
	data.unregister_client(42)
	assert !data.has_clients()
	assert data.debug_state().client_count == 0
	data.finalize()
	assert decoded_image_stops == [i64(77)]
}

fn test_animated_decoded_image_data_stops_at_loop_count_and_restarts() {
	decoded_image_updates = 0
	bitmap := &dom.Bitmap_{ width: 2, height: 1 }
	mut data := AnimatedDecodedImageData.create(78, 2, 1, 2, 1, .srgb, [u32(5), 7], [
		bitmap,
		bitmap,
	], none, none)
	data.register_client(7, record_decoded_image_update)
	assert data.debug_state().timer_active
	data.animation_timer.fire()
	state := data.debug_state()
	assert state.frame_index == 1
	assert state.loops_completed == 1
	assert !state.timer_active
	assert decoded_image_updates == 1

	data.restart_animation()
	restarted := data.debug_state()
	assert restarted.frame_index == 0
	assert restarted.loops_completed == 0
	assert restarted.timer_active
	assert decoded_image_updates == 2
	data.finalize()
}
