module html

import dom

fn test_drag_event_uses_mouse_coordinates_and_data_transfer() {
	transfer := DataTransfer.construct()
	event := DragEvent.construct_impl('drag', DragEventInit{
		MouseEventInit: dom.MouseEventInit{
			client_x: 12
			client_y: 34
			button:   1
		}
		data_transfer:  transfer
	}) or { panic(err) }
	assert event.interface_ == .drag_event
	assert event.client_x_ == 12
	assert event.page_x_ == 12
	assert event.offset_y_ == 34
	assert event.button_ == 1
	assert event.data_transfer() or { panic('missing DataTransfer') } == transfer
}

fn test_form_data_event_exposes_live_form_data_object() {
	mut data := FormData.create([create_form_data_string_entry('name', 'Ladybird')])
	event := FormDataEvent.construct_impl('formdata', FormDataEventInit{ form_data: data }) or {
		panic(err)
	}
	assert event.interface_ == .form_data_event
	assert event.form_data() or { panic('missing form data') } == data
	data.append(create_form_data_string_entry('second', 'value'))
	assert (event.form_data() or { panic('missing form data') }).entries().len == 2
}
