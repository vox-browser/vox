module painting

import css

pub enum VideoRepresentation {
	video_frame
	first_video_frame
	poster_frame
	transparent_black
}

pub struct VideoPaintable {
pub:
	video_rect      Rect
	border_radii    BorderRadiiData
	border_widths   PixelBox
	image_rendering css.ImageRendering
}

pub struct VideoPaintResult {
pub:
	content    DisplayListCommand
	clip_rect  IntRect
	clip_radii CornerRadii
}

// Direct translation of VideoPaintable::paint()'s foreground representation
// switch. The media element owns frame selection and external-source updates.
pub fn (paintable VideoPaintable) paint(representation VideoRepresentation, bitmap_id string,
	bitmap_size ?IntSize, converter DevicePixelConverter) ?VideoPaintResult {
	video_rect := converter.rounded_device_rect(paintable.video_rect)
	if video_rect.is_empty() {
		return none
	}
	mut clip_radii := paintable.border_radii
	clip_radii.shrink(paintable.border_widths.top, paintable.border_widths.right, paintable.border_widths.bottom, paintable.border_widths.left)
	content := match representation {
		.video_frame, .first_video_frame {
			source_size := bitmap_size or { IntSize{video_rect.width, video_rect.height} }
			DisplayListCommand(DrawExternalContent{
				destination: video_rect
				source_id: bitmap_id
				scaling: to_gfx_scaling_mode(paintable.image_rendering, source_size, IntSize{video_rect.width, video_rect.height})
			})
		}
		.poster_frame {
			source_size := bitmap_size or { return none }
			DisplayListCommand(DrawScaledBitmap{
				destination: video_rect
				clip_rect: video_rect
				bitmap_id: bitmap_id
				scaling: to_gfx_scaling_mode(paintable.image_rendering, source_size, IntSize{video_rect.width, video_rect.height})
			})
		}
		.transparent_black {
			DisplayListCommand(FillRect{video_rect, transparent})
		}
	}
	return VideoPaintResult{
		content: content
		clip_rect: video_rect
		clip_radii: clip_radii.as_corners(converter)
	}
}
