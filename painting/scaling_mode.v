module painting

import css

// CSS::to_gfx_scaling_mode(). Smooth image rendering uses mipmapped
// bilinear sampling only while shrinking in both dimensions; crisp-edges and
// pixelated always retain nearest-neighbor sampling.
pub fn to_gfx_scaling_mode(css_value css.ImageRendering, source IntSize, target IntSize) ScalingMode {
	return match css_value {
		.auto_, .high_quality, .smooth {
			if target.width < source.width && target.height < source.height {
				ScalingMode.bilinear_mipmap
			} else {
				ScalingMode.bilinear
			}
		}
		.crisp_edges, .pixelated { ScalingMode.nearest_neighbor }
	}
}
