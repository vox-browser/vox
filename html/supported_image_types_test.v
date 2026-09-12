module html

fn test_supported_image_types_are_shared_and_case_insensitive() {
	assert is_supported_image_type('')
	assert is_supported_image_type('image/avif')
	assert is_supported_image_type('IMAGE/WEBP')
	assert is_supported_image_type('image/png; charset=binary')
	assert !is_supported_image_type('text/plain')
	assert !is_supported_image_type('image/unknown')
}
