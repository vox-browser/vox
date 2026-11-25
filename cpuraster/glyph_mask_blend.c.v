module cpuraster

import math
import os

const glyph_blend_batch_size = 128
const glyph_blend_histogram_cells = 16
const glyph_blend_pixels_per_lane = 2048
const previous_glyph_blend_pixels_per_lane = 4096
const previous_glyph_blend_run_min = 24
const serial_glyph_blend = os.getenv('VOX_SERIAL_GLYPH_BLEND') == '1'
const previous_glyph_blend_budget = os.getenv('VOX_PREVIOUS_GLYPH_BLEND_BUDGET') == '1'
const glyph_blend_diagnostics = os.getenv('VOX_GLYPH_BLEND_DIAGNOSTICS') == '1'
const glyph_blend_dispatch_apply = os.getenv('VOX_GLYPH_BLEND_DISPATCH_APPLY') == '1'
const balance_glyph_blend_stripes = os.getenv('VOX_BALANCE_GLYPH_BLEND_STRIPES') == '1'

struct GlyphMaskBlit {
	mask Mask
	clip IRect
}

struct GlyphMaskBatch {
mut:
	blits  []GlyphMaskBlit
	pixels i64
}

fn (mut batch GlyphMaskBatch) add(mask Mask, clip IRect) {
	batch.blits << GlyphMaskBlit{mask, clip}
	batch.pixels += i64(clip.width()) * clip.height()
}

fn (mut batch GlyphMaskBatch) flush(mut blitter Blitter) {
	if batch.blits.len == 0 { return }
	mut parallel := false
	if mut blitter is PipelineBlitter {
		parallel = batch.blend_parallel(blitter)
	}
	if !parallel {
		for blit in batch.blits {
			blitter.blit_mask(&blit.mask, blit.clip)
		}
	}
	batch.blits.clear()
	batch.pixels = 0
}

struct GlyphMaskBlend {
	blitter        &PipelineBlitter
	blits          []GlyphMaskBlit
	bounds         IRect
	lanes          int
	record_threads bool
mut:
	edges         [5]int
	threads       [4]u64
	stripe_pixels [4]i64
}

// Estimate cumulative mask pixels along the stripe axis. Partial cells
// receive their exact pixel counts. A difference array accounts for fully
// covered cells without walking every cell for each mask.
fn glyph_blend_stripe_edges(blits []GlyphMaskBlit, bounds IRect, lanes int, balance bool) [5]int {
	columns := bounds.width() >= bounds.height()
	origin := if columns { bounds.left } else { bounds.top }
	span := if columns { bounds.width() } else { bounds.height() }
	mut edges := [5]int{}
	for lane in 0 .. lanes + 1 {
		edges[lane] = origin + span * lane / lanes
	}
	if !balance { return edges }
	step := (span - 1) / glyph_blend_histogram_cells + 1
	mut pixels := [glyph_blend_histogram_cells]i64{}
	mut coverage_delta := [glyph_blend_histogram_cells]i64{}
	mut total := i64(0)
	for blit in blits {
		clip := blit.clip
		low := (if columns { clip.left } else { clip.top }) - origin
		high := (if columns { clip.right } else { clip.bottom }) - origin
		cross := i64(if columns { clip.height() } else { clip.width() })
		first, last := low / step, (high - 1) / step
		total += i64(high - low) * cross
		if first == last {
			pixels[first] += i64(high - low) * cross
		} else {
			pixels[first] += i64((first + 1) * step - low) * cross
			pixels[last] += i64(high - last * step) * cross
			coverage_delta[first + 1] += cross
			coverage_delta[last] -= cross
		}
	}
	mut covered := i64(0)
	mut before := i64(0)
	mut lane := 1
	for cell in 0 .. glyph_blend_histogram_cells {
		covered += coverage_delta[cell]
		count := pixels[cell] + covered * step
		if count == 0 { continue }
		cell_width := math.min(step, span - cell * step)
		for lane < lanes {
			goal := total * lane / lanes
			if goal > before + count { break }
			cut := origin + cell * step + int(((goal - before) * cell_width + count / 2) / count)
			edges[lane] = math.min(math.max(cut, edges[lane - 1] + 1), origin + span - (lanes - lane))
			lane++
		}
		if lane == lanes { break }
		before += count
	}
	return edges
}

// Each stripe replays the masks in their original order. A mask that crosses
// a stripe boundary supplies only the pixels in that stripe.
fn blend_glyph_mask_stripes(context voidptr, first i32, end i32) {
	mut work := unsafe { &GlyphMaskBlend(context) }
	extent := work.bounds
	columns := extent.width() >= extent.height()
	for lane in int(first) .. int(end) {
		$if macos && !cpuraster_freetype ? {
			if work.record_threads {
				C.pthread_threadid_np(unsafe { nil }, &work.threads[lane])
			}
		}
		band := if columns {
			IRect{work.edges[lane], extent.top, work.edges[lane + 1], extent.bottom}
		} else {
			IRect{extent.left, work.edges[lane], extent.right, work.edges[lane + 1]}
		}
		mut pixels := i64(0)
		for blit in work.blits {
			clip := blit.clip.intersect(band) or { continue }
			if work.record_threads { pixels += i64(clip.width()) * clip.height() }
			// The caller supplies validated, clipped operations and owned
			// glyph masks. The scan writes only the pixels within clip.
			scan := PipelineMaskScan{
				blitter:      work.blitter
				coverage:     blit.mask.image
				source_pitch: blit.mask.row_bytes
				clip:         clip
				offsets:      MaskRowOffsets{blit.mask.index(clip.left, clip.top), work.blitter.offset(clip.left, clip.top)}
			}
			scan_pipeline_mask(&scan, 0, i32(clip.height()))
		}
		if work.record_threads { work.stripe_pixels[lane] = pixels }
	}
}

fn (mut work GlyphMaskBlend) draw() bool {
	work.edges = glyph_blend_stripe_edges(work.blits, work.bounds, work.lanes,
		balance_glyph_blend_stripes)
	$if macos {
		if !glyph_blend_dispatch_apply {
			// Submit background stripes explicitly. dispatch_apply can run
			// every stripe inline, especially for a short batch.
			return C.vox_scan_workers_with_caller(&work, i32(work.lanes), i32(work.lanes),
				blend_glyph_mask_stripes)
		}
	}
	C.vox_scan_workers_run(&work, i32(work.lanes), i32(work.lanes), blend_glyph_mask_stripes)
	return true
}

fn (batch &GlyphMaskBatch) blend_parallel(blitter &PipelineBlitter) bool {
	pixels_per_lane := if previous_glyph_blend_budget {
		previous_glyph_blend_pixels_per_lane
	} else {
		glyph_blend_pixels_per_lane
	}
	requested_lanes := int(batch.pixels / pixels_per_lane)
	if requested_lanes < 2 { return false }
	mut bounds := batch.blits[0].clip
	for index in 1 .. batch.blits.len {
		clip := &batch.blits[index].clip
		bounds = IRect{math.min(bounds.left, clip.left), math.min(bounds.top, clip.top), math.max(bounds.right, clip.right), math.max(bounds.bottom, clip.bottom)}
	}
	span := math.max(bounds.width(), bounds.height())
	lanes := raster_range_lanes(span, requested_lanes)
	if lanes < 2 { return false }
	mut work := GlyphMaskBlend{
		// The worker dispatch joins while the blitter and masks are borrowed.
		blitter:        unsafe { blitter }
		blits:          batch.blits
		bounds:         bounds
		lanes:          lanes
		record_threads: glyph_blend_diagnostics
	}
	if !work.draw() { return false }
	if glyph_blend_diagnostics {
		mut threads := []u64{}
		for thread_id in work.threads {
			if thread_id != 0 && thread_id !in threads { threads << thread_id }
		}
		eprintln('VOX_GLYPH_BLEND masks=${batch.blits.len} pixels=${batch.pixels} threads=${threads.len}')
		eprintln('VOX_GLYPH_BLEND_STRIPES balanced=${balance_glyph_blend_stripes} pixels=${work.stripe_pixels[..lanes]}')
	}
	return true
}
