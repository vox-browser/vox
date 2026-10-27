module main

import encoding.base64

// An 8x4 4:2:0 JPEG; the expected pixels are libjpeg-turbo's default decode.
const native_jpeg_test_image = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAoHBwgHBgoICAgLCgoLDhgQDg0NDh0VFhEYIx8lJCIfIiEmKzcvJik0KSEiMEExNDk7Pj4+JS5ESUM8SDc9Pjv/2wBDAQoLCw4NDhwQEBw7KCIoOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozv/wAARCAAEAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwCs0XmXFrF5joJknuSUONkiP5aley/KoyBwfpxRRRXPi6tSnZQk1rLZ26lQoUq0YyqRUnZbq/TzP//Z'

const native_jpeg_test_icc_image = '/9j/4AAQSkZJRgABAQAAAQABAAD/4gJcSUNDX1BST0ZJTEUAAQEAAAJMbGNtcwRAAABtbnRyUkdCIFhZWiAH6gAKABEABwAiAAZhY3NwQVBQTAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA9tYAAQAAAADTLWxjbXMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAtkZXNjAAABCAAAADZjcHJ0AAABQAAAAEx3dHB0AAABjAAAABRjaGFkAAABoAAAACxyWFlaAAABzAAAABRiWFlaAAAB4AAAABRnWFlaAAAB9AAAABRyVFJDAAACCAAAACBnVFJDAAACCAAAACBiVFJDAAACCAAAACBjaHJtAAACKAAAACRtbHVjAAAAAAAAAAEAAAAMZW5VUwAAABoAAAAcAHMAUgBHAEIAIABiAHUAaQBsAHQALQBpAG4AAG1sdWMAAAAAAAAAAQAAAAxlblVTAAAAMAAAABwATgBvACAAYwBvAHAAeQByAGkAZwBoAHQALAAgAHUAcwBlACAAZgByAGUAZQBsAHlYWVogAAAAAAAA9tYAAQAAAADTLXNmMzIAAAAAAAEMQgAABd7///MlAAAHkwAA/ZD///uh///9ogAAA9wAAMBuWFlaIAAAAAAAAG+gAAA49QAAA5BYWVogAAAAAAAAJJ8AAA+EAAC2w1hZWiAAAAAAAABilwAAt4cAABjZcGFyYQAAAAAAAwAAAAJmZgAA8qcAAA1ZAAAT0AAACltjaHJtAAAAAAADAAAAAKPXAABUewAATM0AAJmaAAAmZgAAD1z/2wBDAAoHBwgHBgoICAgLCgoLDhgQDg0NDh0VFhEYIx8lJCIfIiEmKzcvJik0KSEiMEExNDk7Pj4+JS5ESUM8SDc9Pjv/2wBDAQoLCw4NDhwQEBw7KCIoOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozv/wAARCAAEAAgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwCs0XmXFrF5joJknuSUONkiP5aley/KoyBwfpxRRRXPi6tSnZQk1rLZ26lQoUq0YyqRUnZbq/TzP//Z'

fn test_native_jpeg_decoding_matches_libjpeg_turbo_defaults() {
	$if macos {
		bitmap := native_jpeg_bitmap(base64.decode(native_jpeg_test_image)) or {
			panic('libjpeg-turbo is unavailable')
		}
		assert bitmap.width == 8 && bitmap.height == 4 && bitmap.pitch == 32
		assert bitmap.native_rows_are_top_down
		assert bitmap.data == [u8(105), 80, 120, 255, 164, 125, 146, 255, 115, 42, 27, 255, 255, 207,
		193, 255, 139, 115, 147, 255, 13, 34, 91, 255, 75, 135, 205, 255, 99, 181, 255, 255, 189,
		188, 228, 255, 118, 101, 120, 255, 54, 1, 0, 255, 149, 96, 78, 255, 167, 149, 173, 255, 95,
		113, 163, 255, 0, 28, 86, 255, 62, 128, 189, 255, 56, 106, 143, 255, 124, 151, 168, 255, 123,
		107, 82, 255, 152, 125, 98, 255, 90, 84, 96, 255, 79, 90, 122, 255, 109, 135, 170, 255, 19,
		51, 89, 255, 76, 150, 185, 255, 0, 49, 63, 255, 231, 234, 207, 255, 148, 133, 102, 255, 0, 0,
		5, 255, 127, 135, 158, 255, 148, 162, 188, 255, 107, 123, 148, 255]
	}
}

fn test_native_jpeg_decoding_leaves_profiles_and_other_formats_to_stb() {
	assert native_jpeg_bitmap(base64.decode(native_jpeg_test_icc_image)) == none
	assert native_jpeg_bitmap('GIF89a'.bytes()) == none
	assert native_jpeg_bitmap([]u8{}) == none
}

// A 7x5 4:2:0 JPEG: TurboJPEG pads the luma plane to 8x6, so the decoder packs
// the rows before handing Y, Cb and Cr to the GPU conversion, as Brave does for
// both baseline and progressive streams.
const native_jpeg_test_odd_baseline = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAAFAAcDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwBb6LybKSSI7XGMHGe4ooor3sHgcO6esEcbr1adOmoSaXL0bXVn/9k='

const native_jpeg_test_444 = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAEAAYDAREAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDiqZ+tn//Z'

const native_jpeg_test_odd_progressive = '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wgARCAAFAAcDASIAAhEBAxEB/8QAFAABAAAAAAAAAAAAAAAAAAAAAP/EABUBAQEAAAAAAAAAAAAAAAAAAAME/9oADAMBAAIQAxAAAAELx//EABYQAQEBAAAAAAAAAAAAAAAAAAIBEf/aAAgBAQABBQJzB//EABkRAQACAwAAAAAAAAAAAAAAAAIAARESQf/aAAgBAwEBPwHdEnF8n//EABcRAQADAAAAAAAAAAAAAAAAAAMAEjH/2gAIAQIBAT8BEDrk/8QAFRABAQAAAAAAAAAAAAAAAAAAAQD/2gAIAQEABj8CUv/EABYQAAMAAAAAAAAAAAAAAAAAAAABMf/aAAgBAQABPyGUGf/aAAwDAQACAAMAAAAQ8//EABcRAQADAAAAAAAAAAAAAAAAAAEAQVH/2gAIAQMBAT8QTDBhS2f/xAAWEQEBAQAAAAAAAAAAAAAAAAABACH/2gAIAQIBAT8QRo3/xAAXEAEBAQEAAAAAAAAAAAAAAAARAQBB/9oACAEBAAE/EFSIUezf/9k='

fn test_native_jpeg_yuv_decoding_packs_padded_planes_of_baseline_and_progressive_streams() {
	$if macos {
		baseline := base64.decode(native_jpeg_test_odd_baseline)
		mut width := 0
		mut height := 0
		mut size := 0
		mut chroma_subsampling := -1
		planes := C.native_decode_jpeg_yuv(baseline.data, uint(baseline.len), &width, &height,
			&size, &chroma_subsampling)
		assert planes != unsafe { nil }
		assert width == 7 && height == 5 && size == 35 + 2 * 12 && chroma_subsampling == 2
		mut decoded := []u8{len: size}
		unsafe { vmemcpy(decoded.data, planes, size) }
		C.native_free_jpeg_pixels(planes)
		assert decoded == [u8(119), 121, 113, 115, 111, 138, 111, 120, 125, 122, 130, 127, 147, 107,
			135, 139, 135, 142, 134, 139, 77, 147, 148, 143, 151, 142, 140, 65, 147, 148, 145, 159, 156,
			160, 88, 62, 73, 89, 103, 119, 130, 147, 163, 160, 172, 190, 208, 49, 113, 219, 164, 52,
			100, 178, 89, 79, 121, 190, 94]
		// Progressive encoding of the same coefficients decodes to the same planes.
		progressive := base64.decode(native_jpeg_test_odd_progressive)
		progressive_planes := C.native_decode_jpeg_yuv(progressive.data, uint(progressive.len),
			&width, &height, &size, &chroma_subsampling)
		assert progressive_planes != unsafe { nil }
		mut progressive_decoded := []u8{len: size}
		unsafe { vmemcpy(progressive_decoded.data, progressive_planes, size) }
		C.native_free_jpeg_pixels(progressive_planes)
		assert progressive_decoded == decoded
		// A 4:4:4 stream keeps full-resolution chroma planes.
		full := base64.decode(native_jpeg_test_444)
		full_planes := C.native_decode_jpeg_yuv(full.data, uint(full.len), &width, &height, &size,
			&chroma_subsampling)
		assert full_planes != unsafe { nil }
		assert width == 6 && height == 4 && size == 3 * 24 && chroma_subsampling == 0
		C.native_free_jpeg_pixels(full_planes)
	}
}
