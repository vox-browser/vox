module painting

import dom

fn test_video_frame_resource_identity_tracks_source_lifetime_replacement_and_rewrites() {
	bitmap := &dom.Bitmap_{ width: 1, height: 1, pitch: 4, data: [u8(20), 40, 60, 255] }
	mut frame := MediaVideoFrame.from_bitmap(bitmap)
	mut first := VideoFrameSource.create()
	mut second := VideoFrameSource.create()
	assert first.resource_identity() == VideoFrameResourceIdentity{}
	first.update(frame)
	second.update(frame)
	a := first.resource_identity()
	b := second.resource_identity()
	assert a.source != 0 && a.source != b.source && a.revision != 0
	assert first.resource_identity() == a
	first.update(frame)
	assert first.resource_identity() == a
	frame.generation++
	rewritten := first.resource_identity()
	assert rewritten.source == a.source && rewritten.revision == a.revision
	assert rewritten.generation != a.generation
	first.update(MediaVideoFrame.from_bitmap(bitmap))
	replaced := first.resource_identity()
	assert replaced.source == a.source && replaced.revision != a.revision
	first.clear()
	assert first.resource_identity() == VideoFrameResourceIdentity{}
	first.update(frame)
	assert first.resource_identity().revision != replaced.revision
	// Source literals and exhausted lifetime/revision counters fail closed.
	mut literal := &VideoFrameSource{}
	literal.update(frame)
	assert literal.resource_identity() == VideoFrameResourceIdentity{}
	mut allocator := VideoFrameSourceIdentityAllocator{ last: u64(0xfffffffffffffffe) }
	assert allocator.take() == u64(0xffffffffffffffff)
	assert allocator.take() == 0 && allocator.take() == 0
	first.resource_revision_ = u64(0xffffffffffffffff)
	first.clear()
	first.update(frame)
	assert first.resource_identity() == VideoFrameResourceIdentity{}
}

fn test_video_frame_source_retains_planar_frames_until_playback() {
	first := &MediaVideoFrame{
		timestamp: 1.25
		width: 2
		height: 1
		yuv_data: MediaVideoYUVData{
			y_plane: [u8(16), 235]
			u_plane: [u8(128)]
			v_plane: [u8(128)]
			y_stride: 2
			u_stride: 1
			v_stride: 1
		}
	}
	mut source := VideoFrameSource.create()
	source.update(first)
	retained := source.current_frame() or { panic('frame was not retained') }
	assert retained == first
	assert retained.timestamp == 1.25
	bitmap := retained.to_bitmap() or { panic(err) }
	assert bitmap.data == [u8(0), 0, 0, 255, 255, 255, 255, 255]

	second := &MediaVideoFrame{
		width: 4
		height: 3
	}
	source.update(second)
	assert source.current_frame() or { panic('replacement frame was not retained') } == second
	source.clear()
	assert source.current_frame() == none
}

fn test_video_frame_source_preserves_rgba_fallback_identity() {
	bitmap := &dom.Bitmap_{
		width: 1
		height: 1
		pitch: 4
		data: [u8(10), 20, 30, 255]
	}
	frame := MediaVideoFrame.from_bitmap(bitmap)
	assert frame.width == 1
	assert frame.height == 1
	assert frame.to_bitmap() or { panic(err) } == bitmap
}

fn test_media_video_frame_retains_decoded_color_space() {
	bitmap := &dom.Bitmap_{ width: 2, height: 1 }
	frame := MediaVideoFrame.from_bitmap_with_color_space(bitmap, .display_p3)
	assert frame.rgba_bitmap? == bitmap
	assert frame.decoded_color_space == .display_p3
}

fn test_video_frame_conversion_rejects_truncated_planes() {
	frame := &MediaVideoFrame{
		width: 2
		height: 2
		yuv_data: MediaVideoYUVData{
			y_plane: [u8(16)]
			u_plane: [u8(128)]
			v_plane: [u8(128)]
		}
	}
	if _ := frame.to_bitmap() {
		assert false, 'truncated luma plane should fail conversion'
	} else {
		assert err.msg().contains('luma plane is truncated')
	}
}
