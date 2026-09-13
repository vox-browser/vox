module page

struct WindowRectCompletionRecorder {
mut:
	rectangles []PixelRect
	ids        []u64
}

fn test_window_rect_completion_preserves_request_identity() {
	mut model := Page.create(2)!
	mut recorder := &WindowRectCompletionRecorder{}
	model.set_window_rect_completion_observer(fn [mut recorder] (rect PixelRect, id u64) {
		recorder.rectangles << rect
		recorder.ids << id
	})
	model.set_window_position(PixelPoint{ x: 30, y: 40 })
	model.set_window_size(PixelSize{ width: 900, height: 700 })
	model.did_complete_window_rect_request(73)
	assert recorder.rectangles == [PixelRect{ x: 30, y: 40, width: 900, height: 700 }]
	assert recorder.ids == [u64(73)]
	model.set_window_rect_completion_observer(none)
	model.did_complete_window_rect_request(74)
	assert recorder.ids == [u64(73)]
}

fn test_window_change_requests_forward_completion_ids() {
	mut client := PageClient.create()
	client.page_did_request_resize_window(PixelSize{ width: 800, height: 600 }, 11)
	client.page_did_request_reposition_window(PixelPoint{ x: 10, y: 20 }, 12)
	client.page_did_request_maximize_window(13)
	assert client.events.map(it.text) == ['800.0,600.0:11', '10.0,20.0:12', '13']
}
