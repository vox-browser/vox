module layout

import cpuraster
import dom
import os
import platform
import processmetrics

const serial_ascii_layout_shaping = os.getenv('VOX_SERIAL_ASCII_LAYOUT_SHAPING') == '1'
const eager_ascii_layout_shaping = os.getenv('VOX_EAGER_ASCII_LAYOUT_SHAPING') == '1'
const two_lane_ascii_layout_shaping = os.getenv('VOX_TWO_LANE_ASCII_LAYOUT_SHAPING') == '1'
const ascii_layout_shaping_jobs = 64

fn prepare_first_layout_ascii_shapes(document &dom.Document, root &Node) platform.ASCIIShapeScope {
	$if macos && prealloc {
		if serial_ascii_layout_shaping || document.font_rendering_policy() != .chromium
			|| document.native_storage() == unsafe { nil } || document.is_svg_image_document()
			|| document_layout_result(document) != none {
			return platform.ASCIIShapeScope{}
		}
		stage := processmetrics.begin_thread_instruction_substage('layout_ascii_shape_preparation')
		defer { stage.finish() }
		mut requests := []platform.ASCIIShapeRequest{cap: ascii_layout_shaping_jobs}
		collect_first_layout_ascii_shapes(root, mut requests)
		if requests.len < 8 { return platform.ASCIIShapeScope{} }
		jobs := platform.prepare_ascii_shape_jobs(requests)
		if jobs.len < 8 { return platform.ASCIIShapeScope{} }
		// Keep the dispatch overhead bounded for small cold batches.
		lanes := if two_lane_ascii_layout_shaping || jobs.len < 16 {
			2
		} else if jobs.len < 24 {
			3
		} else {
			4
		}
		if cpuraster.run_raster_ranges_with_caller(jobs.data, jobs.len, lanes,
			platform.shape_ascii_job_range) == 0 {
			return platform.ASCIIShapeScope{}
		}
		if !eager_ascii_layout_shaping { return platform.stage_ascii_shape_jobs(jobs) }
		platform.store_ascii_shape_jobs(jobs)
	}
	return platform.ASCIIShapeScope{}
}

fn collect_first_layout_ascii_shapes(node &Node, mut requests []platform.ASCIIShapeRequest) {
	if text := node.as_text_node() {
		source := text.source_text_
		// The normal Chromium run takes the same cache key for a complete
		// simple text context. Long and complex contexts stay with the iterator.
		if source.len < 20 || source.len > 160 || !source.is_ascii() || !source.contains(' ')
			|| !((source[0] >= `A` && source[0] <= `Z`) || (source[0] >= `a` && source[0] <= `z`)) {
			return
		}
		rendered := text.text_for_rendering()
		if rendered != source { return }
		for byte in source {
			if byte < 32 || byte == 127 { return }
		}
		context := chromium_collapsed_context_text(text, rendered)
		requests << platform.ASCIIShapeRequest{
			text: context.text
			font: text.Node.first_available_font()
		}
		return
	}
	for child in node.children() {
		if requests.len >= ascii_layout_shaping_jobs { return }
		collect_first_layout_ascii_shapes(child, mut requests)
	}
}
