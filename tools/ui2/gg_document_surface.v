module canvas

import sokol.gfx

// take_document_image flushes a surface and transfers ownership of its color
// attachment. Free the surface before sampling the image and destroy the image
// after its queued draws have been submitted.
pub fn (mut s GpuSurface) take_document_image() !gfx.Image {
	if s.color.id == 0 {
		return error('gg.canvas: surface has no color attachment')
	}
	s.flush()!
	image := s.color
	s.color = gfx.Image{}
	return image
}
