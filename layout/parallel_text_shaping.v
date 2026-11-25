module layout

import cpuraster
import dom
import os
import platform
import processmetrics

const serial_ascii_layout_shaping = os.getenv('VOX_SERIAL_ASCII_LAYOUT_SHAPING') == '1'
const eager_ascii_layout_shaping = os.getenv('VOX_EAGER_ASCII_LAYOUT_SHAPING') == '1'
const sync_ascii_layout_shaping = os.getenv('VOX_SYNC_ASCII_LAYOUT_SHAPING') == '1'
const two_lane_ascii_layout_shaping = os.getenv('VOX_TWO_LANE_ASCII_LAYOUT_SHAPING') == '1'
const prepare_short_ascii_layout_shapes = os.getenv('VOX_PREPARE_SHORT_ASCII_LAYOUT_SHAPES') == '1'
const wait_ascii_layout_shaping_by_range = os.getenv('VOX_WAIT_ASCII_SHAPING_RANGE') == '1'
const ascii_layout_shaping_jobs = 64
const ascii_layout_short_candidates = 128

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
		mut short_requests := []platform.ASCIIShapeRequest{}
		collect_first_layout_ascii_shapes(root, mut requests, mut short_requests)
		// Keep long runs first. The job limit is applied after cache hits and
		// duplicate requests have been removed.
		if short_requests.len > 0 {
			requests << short_requests
		}
		if requests.len < 8 { return platform.ASCIIShapeScope{} }
		jobs := platform.prepare_ascii_shape_jobs(requests, maximum_jobs: ascii_layout_shaping_jobs)
		if jobs.len < 8 { return platform.ASCIIShapeScope{} }
		// Keep the dispatch overhead bounded for small cold batches.
		lanes := if two_lane_ascii_layout_shaping || jobs.len < 16 {
			2
		} else if jobs.len < 24 {
			3
		} else {
			4
		}
		if !eager_ascii_layout_shaping && !sync_ascii_layout_shaping {
			ticket, _ := cpuraster.start_background_raster_ranges(jobs.data, jobs.len, lanes,
				platform.shape_ascii_job_range, wait_by_index: wait_ascii_layout_shaping_by_range)
			if ticket != unsafe { nil } {
				return platform.stage_ascii_shape_jobs(jobs,
					worker_ticket: ticket
					join_workers: cpuraster.join_background_raster_range
					wait_worker_range: if wait_ascii_layout_shaping_by_range {
						cpuraster.wait_background_raster_range_for_index
					} else {
						unsafe { nil }
					}
				)
			}
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

fn collect_first_layout_ascii_shapes(node &Node, mut requests []platform.ASCIIShapeRequest,
	mut short_requests []platform.ASCIIShapeRequest) {
	if text := node.as_text_node() {
		source := text.source_text_
		if source.len < 8 || source.len > 160 { return }
		first := source[0]
		starts_with_letter := (first >= `A` && first <= `Z`) || (first >= `a` && first <= `z`)
		short := source.len < 20
		if short {
			if !prepare_short_ascii_layout_shapes || short_requests.len >= ascii_layout_short_candidates
				|| (!starts_with_letter && (first < `0` || first > `9`)) {
				return
			}
		} else if !starts_with_letter || !source.contains(' ') {
			return
		}
		if !source.is_ascii() { return }
		rendered := text.text_for_rendering()
		if rendered != source { return }
		for byte in source {
			if byte < 32 || byte == 127 { return }
		}
		context := chromium_collapsed_context_text(text, rendered)
		request := platform.ASCIIShapeRequest{
			text: context.text
			font: text.Node.first_available_font()
		}
		if short {
			short_requests << request
		} else {
			requests << request
		}
		return
	}
	for child in node.children() {
		if requests.len >= ascii_layout_shaping_jobs { return }
		collect_first_layout_ascii_shapes(child, mut requests, mut short_requests)
	}
}
