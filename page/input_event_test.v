module page

import math

fn test_input_clones_strip_native_data_and_drag_files() {
	key := KeyEvent{
		type_:        .key_down
		key:          65
		code_point:   `A`
		browser_data: voidptr(42)
	}
	key_clone := key.clone_without_browser_data()
	assert key_clone.key == 65
	assert key_clone.browser_data == unsafe { nil }

	mouse := MouseEvent{
		type_:        .mouse_move
		position:     PixelPoint{
			x: 2
			y: 3
		}
		browser_data: voidptr(7)
	}
	assert mouse.clone_without_browser_data().browser_data == unsafe { nil }

	drag := DragEvent{
		type_:        .drag_start
		files:        [SelectedFile{ name: 'secret.txt', contents: [u8(1), 2] }]
		browser_data: voidptr(9)
	}
	clone := drag.clone_without_browser_data()
	assert clone.files.len == 0
	assert clone.browser_data == unsafe { nil }
}

fn test_pinch_decode_rejects_non_finite_scale() {
	assert PinchEvent.decode(PixelPoint{}, 1.25)!.scale_delta == 1.25
	if _ := PinchEvent.decode(PixelPoint{}, math.nan()) {
		assert false
	} else {
		assert err.msg() == 'IPC: Invalid scale_delta value'
	}
	if _ := PinchEvent.decode(PixelPoint{}, math.inf(1)) {
		assert false
	} else {
		assert err.msg() == 'IPC: Invalid scale_delta value'
	}
}
