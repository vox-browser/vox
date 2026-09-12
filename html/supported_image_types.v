module html

// Returns true for an empty type, or for a MIME type that the image decoder is
// known to support. Keep this shared by picture/source and CSS image-set().
pub fn is_supported_image_type(type_ string) bool {
	essence := ascii_lowercase_string(type_.split(';')[0].trim_space())
	if essence == '' {
		return true
	}
	return essence in ['image/bmp', 'image/gif', 'image/vnd.microsoft.icon', 'image/x-icon',
		'image/jpeg', 'image/jpg', 'image/pjpeg', 'image/jxl', 'image/png', 'image/apng',
		'image/x-png', 'image/tiff', 'image/tinyvg', 'image/webp', 'image/svg+xml']
}
