module platform

import os

const parallel_ascii_shape_diagnostics = os.getenv('VOX_PARALLEL_ASCII_SHAPE_DIAGNOSTICS') == '1'

pub struct ASCIIShapeRequest {
pub:
	text string
	font &Font
}

pub struct ASCIIShapeJob {
	request  ASCIIShapeRequest
	font_key string
	face     voidptr
	hb_font  voidptr
mut:
	buffer    voidptr
	thread_id u64
}

// Resolve the normal cache and native font keys on the owner thread. The
// synchronous batch borrows font handles while the owner leaves them alone.
pub fn prepare_ascii_shape_jobs(requests []ASCIIShapeRequest) []ASCIIShapeJob {
	mut jobs := []ASCIIShapeJob{cap: requests.len}
	mut seen := map[string]bool{}
	mut cache := shared_shaping_cache()
	params := ShapeParams.new(.ltr, 0, 0)
	for request in requests {
		font := request.font
		if font.font_rendering_policy != .chromium || font.source_path != ''
			|| !request.text.is_ascii() || request.text.len == 0
			|| font.synthesize_ascii_caps || text_uses_emoji_fallback(request.text) {
			continue
		}
		key := shaping_cache_font_key(font)
		if cache.lookup(key, request.text, params) != none { continue }
		identity := key + '\x00' + request.text
		if identity in seen { continue }
		face := document_harfbuzz_face(font) or { continue }
		hb_font := scaled_harfbuzz_font_with_tracking(face, font.point_size, font.shaping_resolution(),
			font.variations(), system_font_matching_supported(), font.tracking_size()) or { continue }
		C.hb_font_make_immutable(hb_font)
		seen[identity] = true
		jobs << ASCIIShapeJob{ request: request, font_key: key, face: face, hb_font: hb_font }
	}
	return jobs
}

// Each worker reads the immutable font and writes its own native buffers.
// The caller owns the job array and retains the strings until every range joins.
pub fn shape_ascii_job_range(context voidptr, first i32, end i32) {
	jobs := unsafe { &ASCIIShapeJob(context) }
	thread_id := if parallel_ascii_shape_diagnostics { native_thread_identity() } else { u64(0) }
	for index in int(first) .. int(end) {
		mut job := unsafe { &jobs[index] }
		buffer := C.hb_buffer_create()
		if buffer == unsafe { nil } { continue }
		fill_harfbuzz_ascii_buffer(buffer, job.request.text, false)
		C.hb_shape(job.hb_font, buffer, unsafe { nil }, 0)
		if C.hb_buffer_allocation_successful(buffer) == 0 {
			C.hb_buffer_destroy(buffer)
			continue
		}
		job.buffer = buffer
		job.thread_id = thread_id
	}
}

// Put the decoded shape in the same cache used by width queries and full
// glyph runs. A failed worker leaves its key available to the normal shaper.
pub fn store_ascii_shape_jobs(jobs []ASCIIShapeJob) int {
	mut cache := shared_shaping_cache()
	params := ShapeParams.new(.ltr, 0, 0)
	caller := if parallel_ascii_shape_diagnostics { native_thread_identity() } else { u64(0) }
	mut stored := 0
	mut off_thread := 0
	for index in 0 .. jobs.len {
		mut job := unsafe { &jobs[index] }
		if job.buffer == unsafe { nil } { continue }
		shaped := decode_harfbuzz_shape(job.buffer, job.face, job.hb_font, 0, 0, 0,
			job.request.text, job.request.font, .ltr, [], job.request.text.len, true, false)
		job.buffer = unsafe { nil }
		cache.store(job.font_key, job.request.text, params, CachedShape{
			...cached_shape_from(shaped)
			parallel_prepared: parallel_ascii_shape_diagnostics
		})
		stored++
		if parallel_ascii_shape_diagnostics && job.thread_id != caller { off_thread++ }
	}
	if parallel_ascii_shape_diagnostics {
		eprintln('VOX_LAYOUT_ASCII_SHAPES jobs=${jobs.len} stored=${stored} off_thread=${off_thread}')
	}
	return stored
}
