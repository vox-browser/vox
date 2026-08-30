module html

fn test_image_data_dimensions_transparent_black_and_shared_data() {
	image := ImageData.create(2, 3, ImageDataSettings{ color_space: .display_p3 })!
	assert image.width() == 2
	assert image.height() == 3
	assert image.data().len == 24
	assert image.data().all(it == 0)
	assert image.color_space() == .display_p3
	mut bytes := image.data()
	bytes[0] = 255
	assert image.bitmap().data[0] == 255
}

fn test_image_data_from_typed_data_validates_dimensions() {
	mut source := []u8{len: 16}
	source[3] = 255
	image := ImageData.create_with_data(source, 2, none, none)!
	assert image.width() == 2
	assert image.height() == 2
	assert image.data()[3] == 255
	if _ := ImageData.create_with_data([u8(1), 2, 3], 1, none, none) {
		assert false
	}
	if _ := ImageData.create_with_data(source, 3, none, none) {
		assert false
	}
	if _ := ImageData.create(0, 2, none) {
		assert false
	}
}

fn test_image_data_serialization_round_trip() {
	image := ImageData.create_with_data([u8(1), 2, 3, 4, 5, 6, 7, 8], 2, 1, ImageDataSettings{
		color_space: .display_p3
	})!
	decoded := image_data_deserialization_steps(image.serialization_steps())!
	assert decoded.width() == 2
	assert decoded.height() == 1
	assert decoded.data() == image.data()
	assert decoded.color_space() == .display_p3
	if _ := image_data_deserialization_steps(image.serialization_steps()[..5]) {
		assert false
	}
}

fn test_image_data_exact_constructor_overloads() {
	blank := ImageData.construct_impl(ImageDataConstructor(ImageDataSizeConstructor{
		sw: 2
		sh: 1
	}))!
	assert blank.data() == [u8(0), 0, 0, 0, 0, 0, 0, 0]
	backed := ImageData.construct_impl(ImageDataConstructor(ImageDataBufferConstructor{
		data: [u8(1), 2, 3, 4]
		sw:   1
		sh:   1
	}))!
	assert backed.width() == 1
	assert backed.height() == 1
	assert backed.data() == [u8(1), 2, 3, 4]
}
