module layout

import css
import painting

// Decoders report natural dimensions in CSS pixels. Retained background CSS
// and box geometry may already be projected into device layout coordinates.
// Project only the natural sizing input; source bitmap coordinates stay in
// decoded pixels, and an SVG's dimensionless aspect ratio stays unchanged.
pub fn (data &PaintBackgroundLayerData) resolve_image(image_id string, area painting.Rect,
	natural_size css.SizeWithAspectRatio) ?painting.ResolvedBackgroundLayer {
	mut natural := natural_size
	if width := natural.width {
		natural.width = width.scaled(data.layout_coordinate_scale)
	}
	if height := natural.height {
		natural.height = height.scaled(data.layout_coordinate_scale)
	}
	return painting.resolve_background_layer_with_natural_size(data.layer, image_id, area,
		data.resolution_context, natural)
}
