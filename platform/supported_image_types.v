module platform

pub fn is_supported_image_type(type_ string) bool {
	essence := type_.split(';')[0].trim_space().to_lower()
	if essence == '' {
		return true
	}
	return essence in ['image/avif', 'image/bmp', 'image/gif', 'image/vnd.microsoft.icon',
		'image/x-icon', 'image/jpeg', 'image/jpg', 'image/pjpeg', 'image/jxl', 'image/png',
		'image/apng', 'image/x-png', 'image/tiff', 'image/tinyvg', 'image/webp', 'image/svg+xml']
}
