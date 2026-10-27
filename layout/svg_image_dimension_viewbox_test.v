module layout

import dom
import html

fn test_svg_image_without_viewbox_stretches_intrinsic_coordinates_in_chromium() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut embedder := html.parse_document('<!doctype html>')
		defer { embedder.finalize() }
		embedder.set_font_rendering_policy(policy)
		for aspect in ['', 'preserveAspectRatio="xMidYMid meet"',
			'preserveAspectRatio="xMaxYMax slice"', 'preserveAspectRatio="none"'] {
			for viewbox in ['', 'viewBox="0 0 4 3"'] {
				mut image := parse_svg_image_document(SVGImageSource{
					source: '<svg xmlns="http://www.w3.org/2000/svg" width="4" height="3" ${aspect} ${viewbox}><path d="M0 0h4v3H0z"/></svg>'
					url: dom.URL{value: 'https://svg-dimensions.test/image.svg'}
				}, 'light', embedder) or { panic('missing SVG image') }
				defer { image.finalize() }
				assert image.font_rendering_policy() == policy
				// Repeated sizing must not turn the synthetic viewport into an
				// authored viewBox or overwrite the image's natural dimensions.
				for size in [[f64(192), 96]!, [f64(96), 144]!, [f64(192), 96]!] {
					_ = run_document_layout(image, size[0], size[1]) or {
						panic('missing SVG layout')
					}
					list := image.record_display_list() or { panic('missing SVG paint') }
					paths := display_list_commands(list).filter(it.kind == 'draw_svg_path')
					assert paths.len == 1
					mut sx := size[0] / 4
					mut sy := size[1] / 3
					mut dx := f64(0)
					mut dy := f64(0)
					stretch := aspect.contains('="none"') || (viewbox == '' && policy == .chromium)
					if !stretch {
						if aspect.contains('slice') {
							sx = if sx > sy { sx } else { sy }
							sy = sx
							dx = size[0] - 4 * sx
							dy = size[1] - 3 * sy
						} else {
							sx = if sx < sy { sx } else { sy }
							sy = sx
							dx = (size[0] - 4 * sx) / 2
							dy = (size[1] - 3 * sy) / 2
						}
					}
					assert paths[0].svg().path_transform == [sx, f64(0), 0, sy, dx, dy]!, '${policy}: ${aspect} ${viewbox}'
					natural := svg_background_natural_size(image)
					assert natural.width?.to_double() == 4
					assert natural.height?.to_double() == 3
				}
			}
		}
	}
}
