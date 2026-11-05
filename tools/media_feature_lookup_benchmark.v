// Component diagnostic through the public parsed-query evaluator.
module main

import css
import dom
import platform
import processmetrics

fn measure_media_feature_queries(name string, sources []string, document &dom.Document, repetitions int) {
	mut queries := []&css.MediaQuery{}
	mut expected := []bool{}
	for source in sources {
		query := css.parse_media_query_from_text(source) or { panic(source) }
		queries << query
		expected << query.evaluate(document)
	}
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for group_start := 0; group_start < repetitions; group_start += 64 {
		mut scratch := platform.begin_thread_scratch('media feature lookup component')
		end := if group_start + 64 < repetitions { group_start + 64 } else { repetitions }
		for _ in group_start .. end {
			for index, query in queries {
				actual := query.evaluate(document)
				assert actual == expected[index]
				checksum += if actual { u64(1) } else { u64(2) }
			}
		}
		scratch.finish()
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"evaluations":${sources.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 1024, 768})
	document.set_display_device_pixel_ratio(2)
	document.set_svg_image_color_scheme('dark')
	measure_media_feature_queries('width', ['(width: 1024px)', '(width > 500px)',
		'(min-device-width: 1024px)'], document, 8192)
	measure_media_feature_queries('early-features', ['(hover: hover)', '(any-hover: hover)',
		'(pointer: fine)', '(color: 8)'], document, 8192)
	measure_media_feature_queries('preferences', ['(prefers-color-scheme: dark)',
		'(prefers-reduced-motion: no-preference)', '(prefers-reduced-transparency: no-preference)',
		'(forced-colors: none)'], document, 8192)
	measure_media_feature_queries('resolution-and-ratio', ['(resolution: 2dppx)', '(aspect-ratio: 4/3)',
		'(device-aspect-ratio > 1)', '(height > 0px)'], document, 8192)
	mut every_feature := []string{}
	$for value in css.MediaFeatureID.values {
		every_feature << '(' + value.name.replace('_', '-') + ')'
	}
	measure_media_feature_queries('every-feature-boolean', every_feature, document, 2048)
}
