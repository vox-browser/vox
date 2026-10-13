module html

import dom

fn test_drag_event_constructor_is_untrusted_and_retains_raw_mouse_coordinates_and_transfer() {
	mut transfer := DataTransfer.construct()
	transfer.set_data('text/plain', 'before')
	event := DragEvent.construct_impl('drag', DragEventInit{
		MouseEventInit: dom.MouseEventInit{
			EventModifierInit: dom.EventModifierInit{
				UIEventInit: dom.UIEventInit{
					EventInit: dom.EventInit{
						bubbles:    true
						cancelable: true
						composed:   true
					}
					detail: 3
				}
				ctrl_key: true
			}
			screen_x:   10.75
			screen_y:   -10.25
			client_x:   12.75
			client_y:   -12.25
			page_x:     90.5
			page_y:     91.5
			offset_x:   92.5
			offset_y:   93.5
			movement_x: 1.75
			movement_y: -1.25
			button:     -2
			buttons:    65535
		}
		data_transfer: transfer
	}) or { panic(err) }
	// The unchanged constructor fails here; subsequent geometry and ownership
	// assertions become reachable only after constructor trust is corrected.
	assert !event.is_trusted()
	assert event.interface_ == .drag_event
	assert event.type_name() == 'drag'
	assert event.bubbles() && event.cancelable() && event.composed()
	assert event.detail() == 3
	assert event.ctrl_key()
	assert event.screen_x_ == 10.75 && event.screen_y_ == -10.25
	assert event.client_x_ == 12.75 && event.client_y_ == -12.25
	assert event.page_x_ == 12.75 && event.page_y_ == -12.25
	assert event.offset_x_ == 12.75 && event.offset_y_ == -12.25
	assert event.screen_x() == 10 && event.screen_y() == -11
	assert event.client_x() == 12 && event.client_y() == -13
	assert event.x() == 12 && event.y() == -13
	assert event.page_x() == 12 && event.page_y() == -13
	assert event.offset_x() == 12 && event.offset_y() == -13
	assert event.movement_x() == 1.75 && event.movement_y() == -1.25
	assert event.button() == -2 && event.buttons() == 65535
	assert event.target() == none && event.related_target() == none
	assert (event.data_transfer() or { panic('missing DataTransfer') }) == transfer
	transfer.set_data('text/plain', 'after')
	assert (event.data_transfer() or { panic('missing DataTransfer') }).get_data('text/plain') == 'after'
	default_event := DragEvent.construct_impl('drag', DragEventInit{}) or { panic(err) }
	assert !default_event.is_trusted()
	assert default_event.data_transfer() == none
}

fn test_drag_event_internal_create_and_inherited_initializers_preserve_transfer_and_timestamp() {
	mut transfer := DataTransfer.construct()
	mut event := DragEvent.create('dragover', DragEventInit{
		MouseEventInit: dom.MouseEventInit{
			screen_x: 10.75
			screen_y: -10.25
			client_x: 12.75
			client_y: -12.25
		}
		data_transfer: transfer
	}, 20.75, -20.25, 30.75, -30.25)
	assert event.is_trusted()
	assert event.client_x() == 12.75 && event.client_y() == -12.25
	assert event.page_x() == 20.75 && event.page_y() == -20.25
	assert event.offset_x() == 30.75 && event.offset_y() == -30.25
	assert (event.data_transfer() or { panic('missing DataTransfer') }) == transfer
	event.set_time_stamp(125.375)
	event.init_mouse_event('drop', true, true, unsafe { nil }, 4, 50, -50, 60, -60, true,
		false, true, false, 2, none)
	assert !event.is_trusted()
	assert event.interface_ == .drag_event && event.type_name() == 'drop'
	assert event.client_x() == 60 && event.client_y() == -60
	assert event.page_x_ == 20.75 && event.page_y_ == -20.25
	assert event.offset_x_ == 30.75 && event.offset_y_ == -30.25
	assert event.page_x() == 20 && event.page_y() == -21
	assert event.offset_x() == 30 && event.offset_y() == -31
	assert event.time_stamp() == 125.375
	assert (event.data_transfer() or { panic('missing DataTransfer') }) == transfer
	event.init_ui_event('dragenter', false, false, unsafe { nil }, 5)
	assert event.type_name() == 'dragenter' && event.detail() == 5
	assert (event.data_transfer() or { panic('missing DataTransfer') }) == transfer
	event.init_event('dragleave', true, false)
	assert event.type_name() == 'dragleave' && event.interface_ == .drag_event
	assert event.time_stamp() == 125.375
	assert (event.data_transfer() or { panic('missing DataTransfer') }) == transfer
	transfer.set_data('text/plain', 'retained')
	assert (event.data_transfer() or { panic('missing DataTransfer') }).get_data('text/plain') == 'retained'
}
