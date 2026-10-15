module main

#include "native_layer_presentation_test_darwin.h"

fn C.native_test_layer_frame_scale_capture_and_callbacks() int

fn test_native_layer_frames_preserve_pixels_scale_resize_capture_and_parent_callbacks() {
	$if macos {
		assert C.native_test_layer_frame_scale_capture_and_callbacks() == 1023
	}
}
