module css

import dom
import os
import sync.stdatomic

const retain_media_feature_name_chain = os.getenv('VOX_RETAIN_MEDIA_FEATURE_NAME_CHAIN') != ''
const media_feature_lookup_diagnostics = os.getenv('VOX_MEDIA_FEATURE_LOOKUP_DIAGNOSTICS') != ''

__global media_feature_lookup_reported stdatomic.AtomicVal[bool]

// This is a lookup, not a cache: CSSOM edits and document adoption keep using
// the current feature name and current document environment on every call.
fn media_feature_id_for_name(name string) ?MediaFeatureID {
	return match name.len {
		4 {
			match name {
				'grid' { MediaFeatureID.grid }
				'scan' { MediaFeatureID.scan }
				else { none }
			}
		}
		5 {
			match name {
				'hover' { MediaFeatureID.hover }
				'color' { MediaFeatureID.color }
				'width' { MediaFeatureID.width }
				else { none }
			}
		}
		6 {
			match name {
				'height' { MediaFeatureID.height }
				'update' { MediaFeatureID.update }
				else { none }
			}
		}
		7 {
			match name {
				'pointer' { MediaFeatureID.pointer }
				else { none }
			}
		}
		9 {
			match name {
				'any-hover' { MediaFeatureID.any_hover }
				'scripting' { MediaFeatureID.scripting }
				else { none }
			}
		}
		10 {
			match name {
				'monochrome' { MediaFeatureID.monochrome }
				'resolution' { MediaFeatureID.resolution }
				else { none }
			}
		}
		11 {
			match name {
				'any-pointer' { MediaFeatureID.any_pointer }
				'color-gamut' { MediaFeatureID.color_gamut }
				'color-index' { MediaFeatureID.color_index }
				'orientation' { MediaFeatureID.orientation }
				else { none }
			}
		}
		12 {
			match name {
				'display-mode' { MediaFeatureID.display_mode }
				'nav-controls' { MediaFeatureID.nav_controls }
				'device-width' { MediaFeatureID.device_width }
				'aspect-ratio' { MediaFeatureID.aspect_ratio }
				else { none }
			}
		}
		13 {
			match name {
				'dynamic-range' { MediaFeatureID.dynamic_range }
				'forced-colors' { MediaFeatureID.forced_colors }
				'device-height' { MediaFeatureID.device_height }
				else { none }
			}
		}
		14 {
			match name {
				'overflow-block' { MediaFeatureID.overflow_block }
				else { none }
			}
		}
		15 {
			match name {
				'inverted-colors' { MediaFeatureID.inverted_colors }
				'overflow-inline' { MediaFeatureID.overflow_inline }
				else { none }
			}
		}
		16 {
			match name {
				'prefers-contrast' { MediaFeatureID.prefers_contrast }
				else { none }
			}
		}
		17 {
			match name {
				'video-color-gamut' { MediaFeatureID.video_color_gamut }
				else { none }
			}
		}
		19 {
			match name {
				'video-dynamic-range' { MediaFeatureID.video_dynamic_range }
				'device-aspect-ratio' { MediaFeatureID.device_aspect_ratio }
				else { none }
			}
		}
		20 {
			match name {
				'environment-blending' { MediaFeatureID.environment_blending }
				'prefers-color-scheme' { MediaFeatureID.prefers_color_scheme }
				'prefers-reduced-data' { MediaFeatureID.prefers_reduced_data }
				else { none }
			}
		}
		22 {
			match name {
				'prefers-reduced-motion' { MediaFeatureID.prefers_reduced_motion }
				else { none }
			}
		}
		26 {
			match name {
				'vertical-viewport-segments' { MediaFeatureID.vertical_viewport_segments }
				else { none }
			}
		}
		28 {
			match name {
				'horizontal-viewport-segments' { MediaFeatureID.horizontal_viewport_segments }
				'prefers-reduced-transparency' { MediaFeatureID.prefers_reduced_transparency }
				else { none }
			}
		}
		else { none }
	}
}

fn query_media_feature(feature_name string, document ?&dom.Document) ?MediaFeatureValueLocal {
	if retain_media_feature_name_chain {
		return query_media_feature_by_name(feature_name, document)
	}
	// Preserve the old chain's inexpensive first branch for hover queries.
	if feature_name == 'any-hover' || feature_name == 'hover' {
		report_media_feature_lookup()
		return media_feature_ident_value('hover')
	}
	id := media_feature_id_for_name(feature_name) or { return none }
	report_media_feature_lookup()
	return query_media_feature_by_id(id, document)
}

fn report_media_feature_lookup() {
	if media_feature_lookup_diagnostics && media_feature_lookup_reported.compare_and_swap(false, true) {
		eprintln('Vox media feature lookup: length and enum dispatch')
	}
}

fn query_media_feature_by_id(feature_id MediaFeatureID, document ?&dom.Document) ?MediaFeatureValueLocal {
	viewport_width := if doc := document { doc.viewport_rect().width } else { 800.0 }
	viewport_height := if doc := document { doc.viewport_rect().height } else { 600.0 }
	return match feature_id {
		.any_hover, .hover {
			media_feature_ident_value('hover')
		}
		.any_pointer, .pointer {
			media_feature_ident_value('fine')
		}
		.color {
			media_feature_integer_value(8)
		}
		.color_gamut, .video_color_gamut {
			media_feature_ident_value('srgb')
		}
		.color_index, .grid, .monochrome {
			media_feature_integer_value(0)
		}
		.display_mode {
			media_feature_ident_value('browser')
		}
		.dynamic_range, .video_dynamic_range {
			media_feature_ident_value('standard')
		}
		.environment_blending {
			media_feature_ident_value('opaque')
		}
		.forced_colors, .inverted_colors, .scan {
			media_feature_ident_value('none')
		}
		.height, .device_height {
			media_feature_length_value(viewport_height)
		}
		.horizontal_viewport_segments, .vertical_viewport_segments {
			media_feature_integer_value(1)
		}
		.nav_controls {
			media_feature_ident_value('back')
		}
		.orientation {
			media_feature_ident_value(if viewport_width >= viewport_height {
				'landscape'
			} else {
				'portrait'
			})
		}
		.overflow_block, .overflow_inline {
			media_feature_ident_value('scroll')
		}
		.prefers_color_scheme {
			preferred := if doc := document {
				doc.preferred_color_scheme().to_lower()
			} else {
				'auto'
			}
			media_feature_ident_value(if preferred == 'dark' { 'dark' } else { 'light' })
		}
		.prefers_reduced_transparency {
			reduce := if doc := document { doc.prefers_reduced_transparency() } else { false }
			media_feature_ident_value(if reduce { 'reduce' } else { 'no-preference' })
		}
		.prefers_reduced_motion {
			reduce := if doc := document { doc.prefers_reduced_motion() } else { false }
			media_feature_ident_value(if reduce { 'reduce' } else { 'no-preference' })
		}
		.prefers_contrast, .prefers_reduced_data {
			media_feature_ident_value('no-preference')
		}
		.resolution {
			media_feature_resolution_value(if doc := document {
				doc.display_device_pixel_ratio()
			} else {
				1.0
			})
		}
		.scripting {
			media_feature_ident_value('enabled')
		}
		.update {
			media_feature_ident_value('fast')
		}
		.width, .device_width {
			media_feature_length_value(viewport_width)
		}
		.aspect_ratio, .device_aspect_ratio {
			media_feature_ratio_value(if viewport_height != 0 {
				viewport_width / viewport_height
			} else {
				0.0
			})
		}
	}
}
