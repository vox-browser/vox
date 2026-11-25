module cpuraster

import math
import os
import runtime

const glyph_blend_batch_size = 128
const glyph_blend_pixels_per_lane = 4096
const serial_glyph_blend = os.getenv('VOX_SERIAL_GLYPH_BLEND') == '1'
const glyph_blend_diagnostics = os.getenv('VOX_GLYPH_BLEND_DIAGNOSTICS') == '1'

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
	blitter &PipelineBlitter
	blits   []GlyphMaskBlit
	bounds  IRect
	lanes   int
mut:
	threads [4]u64
}

// Each stripe replays the masks in their original order. A mask that crosses
// a stripe boundary supplies only the pixels in that stripe.
fn blend_glyph_mask_stripes(context voidptr, first i32, end i32) {
	mut work := unsafe { &GlyphMaskBlend(context) }
	extent := work.bounds
	columns := extent.width() >= extent.height()
	for lane in int(first) .. int(end) {
		$if macos && !cpuraster_freetype ? {
			if glyph_blend_diagnostics {
				C.pthread_threadid_np(unsafe { nil }, &work.threads[lane])
			}
		}
		band := if columns {
			width := extent.width()
			IRect{extent.left + width * lane / work.lanes, extent.top, extent.left + width * (lane + 1) / work.lanes, extent.bottom}
		} else {
			height := extent.height()
			IRect{extent.left, extent.top + height * lane / work.lanes, extent.right, extent.top + height * (lane + 1) / work.lanes}
		}
		for blit in work.blits {
			clip := blit.clip.intersect(band) or { continue }
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
	}
}

fn (batch &GlyphMaskBatch) blend_parallel(blitter &PipelineBlitter) bool {
	mut lanes := math.min(int(batch.pixels / glyph_blend_pixels_per_lane),
		int(C.VOX_SCAN_WORKERS_MAX))
	if lanes < 2 { return false }
	mut bounds := batch.blits[0].clip
	for index in 1 .. batch.blits.len {
		clip := &batch.blits[index].clip
		bounds = IRect{math.min(bounds.left, clip.left), math.min(bounds.top, clip.top), math.max(bounds.right, clip.right), math.max(bounds.bottom, clip.bottom)}
	}
	span := math.max(bounds.width(), bounds.height())
	lanes = math.min(lanes, math.min(span, runtime.nr_cpus()))
	if lanes < 2 { return false }
	mut work := GlyphMaskBlend{
		// The worker dispatch joins while the blitter and masks are borrowed.
		blitter: unsafe { blitter }
		blits:   batch.blits
		bounds:  bounds
		lanes:   lanes
	}
	C.vox_scan_workers_run(&work, i32(lanes), i32(lanes), blend_glyph_mask_stripes)
	if glyph_blend_diagnostics {
		mut threads := []u64{}
		for thread_id in work.threads {
			if thread_id != 0 && thread_id !in threads { threads << thread_id }
		}
		eprintln('VOX_GLYPH_BLEND masks=${batch.blits.len} pixels=${batch.pixels} threads=${threads.len}')
	}
	return true
}
