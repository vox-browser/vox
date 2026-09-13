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
	video_rect         Rect
	border_radii       BorderRadiiData
	border_widths      PixelBox
	image_rendering    css.ImageRendering
	object_fit         css.ObjectFit
	object_position    css.Position
	resolution_context css.LengthResolutionContext
	natural_media_size ?IntSize
}

pub struct VideoPaintResult {
pub:
	content    DisplayListCommand
	clip_rect  IntRect
	clip_radii CornerRadii
}

// Direct translation of VideoPaintable::paint()'s foreground representation
// switch. Video frames remain in their source until display-list playback.
pub fn (paintable VideoPaintable) paint(representation VideoRepresentation, bitmap_id string,
	bitmap_size ?IntSize, video_frame_source ?&VideoFrameSource,
	converter DevicePixelConverter) ?VideoPaintResult {
	video_rect := converter.rounded_device_rect(paintable.video_rect)
	if video_rect.is_empty() {
		return none
	}
	mut clip_radii := paintable.border_radii
	clip_radii.shrink(paintable.border_widths.top, paintable.border_widths.right, paintable.border_widths.bottom, paintable.border_widths.left)
	content := match representation {
		.video_frame, .first_video_frame {
			source := video_frame_source or { return none }
			current_frame := source.current_frame()
			source_size := if frame := current_frame {
				IntSize{int(frame.width), int(frame.height)}
			} else {
				paintable.natural_media_size or { return none }
			}
			destination := get_replaced_box_painting_area(paintable.video_rect, Size{f64(source_size.width), f64(source_size.height)}, paintable.object_fit, paintable.object_position, paintable.resolution_context, converter) or { return none }
			DisplayListCommand(DrawVideoFrameSource{
				destination: destination
				source: source
				scaling: to_gfx_scaling_mode(paintable.image_rendering, source_size, IntSize{destination.width, destination.height})
			})
		}
		.poster_frame {
			source_size := bitmap_size or { return none }
			destination := get_replaced_box_painting_area(paintable.video_rect, Size{f64(source_size.width), f64(source_size.height)}, paintable.object_fit, paintable.object_position, paintable.resolution_context, converter) or { return none }
			DisplayListCommand(DrawScaledDecodedImageFrame{
				destination: destination
				clip_rect: video_rect
				bitmap_id: bitmap_id
				scaling: to_gfx_scaling_mode(paintable.image_rendering, source_size, IntSize{destination.width, destination.height})
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
