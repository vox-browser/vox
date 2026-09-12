module html

import platform

// Returns true for an empty type, or for a MIME type that the image decoder is
// known to support. Keep this shared by picture/source and CSS image-set().
pub fn is_supported_image_type(type_ string) bool {
	return platform.is_supported_image_type(type_)
}
