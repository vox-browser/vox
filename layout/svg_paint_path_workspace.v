module layout

import html
import painting
import platform
import svg

struct SVGPaintPathProjection {
	packed_segments []f32
	bounds ?painting.Rect
}

// Canvas segments and flattened contours are only inputs to native path
// packing and gradient bounds. Keep the packed vector, then retire the builders
// and hit-test contours rather than retaining them in every paint projection.
fn svg_paint_path_projection(path svg.Path, rule painting.WindingRule, pack bool) SVGPaintPathProjection {
	$if prealloc {
		mut scratch := platform.begin_thread_scratch('SVG paint path projection')
		work := svg_paint_path_projection_in_workspace(path, rule, pack)
		scratch.leave()
		owned := SVGPaintPathProjection{
			packed_segments: work.packed_segments.clone()
			bounds: work.bounds
		}
		scratch.finish()
		return owned
	}
	return svg_paint_path_projection_in_workspace(path, rule, pack)
}

fn svg_paint_path_projection_in_workspace(path svg.Path, rule painting.WindingRule, pack bool) SVGPaintPathProjection {
	visual := painting_clip_path_from_canvas_path(html.canvas_gfx_path_from_svg_path(path), rule)
	return SVGPaintPathProjection{
		packed_segments: if pack { compatibility_pack_clip_path_segments(visual) } else { []f32{} }
		bounds: painting_clip_path_bounds(visual)
	}
}
