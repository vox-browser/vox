module html

import dom

fn test_image_bitmap_dimensions_close_and_serialization() {
	bitmap_data := &dom.Bitmap_{
		width:      2
		height:     3
		pitch:      8
		format:     1
		alpha_type: 2
		data:       [u8(1), 2, 3, 4]
	}
	mut image := ImageBitmap.create()
	image.set_bitmap(bitmap_data)
	assert image.width() == 2
	assert image.height() == 3
	assert image.primary_interface() == .image_bitmap
	copy := image_bitmap_deserialization_steps(image.serialization_steps())!
	assert copy.width() == 2
	assert copy.height() == 3
	assert copy.bitmap()?.data == [u8(1), 2, 3, 4]
	image.close()
	assert image.width() == 0
	assert image.height() == 0
	assert image.bitmap() == none
}

fn test_image_bitmap_transfer_detaches_sender() {
	mut sender := ImageBitmap.create()
	sender.set_bitmap(&dom.Bitmap_{
		width:  4
		height: 5
		pitch:  16
		data:   [
			u8(9),
		]
	})
	holder := sender.transfer_steps()
	assert sender.is_detached()
	assert sender.width() == 0
	receiver := image_bitmap_transfer_receiving_steps(holder)!
	assert !receiver.is_detached()
	assert receiver.width() == 4
	assert receiver.height() == 5
}

fn test_image_bitmap_deserializer_rejects_truncation() {
	if _ := image_bitmap_deserialization_steps([u8(1), 2]) {
		assert false
	}
}
