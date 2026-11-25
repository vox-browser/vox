module platform

import os

#include "@DIR/shaping_preparation.h"
fn C.vox_ascii_shape_batch_get() voidptr
fn C.vox_ascii_shape_batch_set(voidptr)

const parallel_ascii_shape_diagnostics = os.getenv('VOX_PARALLEL_ASCII_SHAPE_DIAGNOSTICS') == '1'
const serial_ascii_strike_advances = os.getenv('VOX_SERIAL_ASCII_STRIKE_ADVANCES') == '1'
const serial_ascii_glyph_decode = os.getenv('VOX_SERIAL_ASCII_GLYPH_DECODE') == '1'
const ascii_shape_strike_max_glyphs = 160

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
	strike   ChromiumNativeStrike
	decoding HarfBuzzDecodeParams
mut:
	buffer    voidptr
	advances  []f32
	advance_count int
	glyphs []Glyph
	glyph_count int
	trailing_whitespace TrailingWhitespace
	thread_id u64
	next_for_text int
}

@[heap]
struct ASCIIShapeBatch {
	jobs            []ASCIIShapeJob
	first_by_text   map[string]int
	font_generation u64
	previous        &ASCIIShapeBatch
	join_workers    fn (voidptr) bool = unsafe { nil }
mut:
	staged          int
	worker_ticket   voidptr
}

pub struct ASCIIShapeScope {
mut:
	batch &ASCIIShapeBatch = unsafe { nil }
}

@[params]
pub struct ASCIIShapeStageOptions {
pub:
	worker_ticket voidptr
	join_workers  fn (voidptr) bool = unsafe { nil }
}

fn active_ascii_shape_batch() &ASCIIShapeBatch {
	return unsafe { &ASCIIShapeBatch(C.vox_ascii_shape_batch_get()) }
}

fn (job &ASCIIShapeJob) prepared() bool {
	return job.glyph_count > 0 || job.buffer != unsafe { nil }
}

fn (mut job ASCIIShapeJob) take() ASCIIShapeJob {
	result := *job
	job.buffer = unsafe { nil }
	job.glyph_count = 0
	return result
}

fn (batch &ASCIIShapeBatch) report_jobs() int {
	caller := native_thread_identity()
	mut staged := 0
	mut off_thread := 0
	mut strikes := 0
	mut strikes_off_thread := 0
	mut decoded := 0
	mut decoded_off_thread := 0
	mut threads := map[u64]bool{}
	for index in 0 .. batch.jobs.len {
		job := unsafe { &batch.jobs[index] }
		if !job.prepared() { continue }
		staged++
		threads[job.thread_id] = true
		if job.thread_id != caller { off_thread++ }
		if job.advance_count > 0 {
			strikes++
			if job.thread_id != caller { strikes_off_thread++ }
		}
		if job.glyph_count > 0 {
			decoded++
			if job.thread_id != caller { decoded_off_thread++ }
		}
	}
	eprintln('VOX_LAYOUT_ASCII_SHAPES jobs=${batch.jobs.len} staged=${staged} off_thread=${off_thread} strikes=${strikes} strikes_off_thread=${strikes_off_thread} decoded=${decoded} decoded_off_thread=${decoded_off_thread} threads=${threads.len}')
	return staged
}

// The layout owns the inputs until finish(). With a worker ticket, only read
// the immutable keys until the first matching cache miss joins the workers.
pub fn stage_ascii_shape_jobs(jobs []ASCIIShapeJob, options ASCIIShapeStageOptions) ASCIIShapeScope {
	assert options.worker_ticket == unsafe { nil } || (jobs.len > 0 && options.join_workers != unsafe { nil })
	mut first_by_text := map[string]int{}
	mut staged := 0
	for index in 0 .. jobs.len {
		mut job := unsafe { &jobs[index] }
		if options.worker_ticket == unsafe { nil } && !job.prepared() { continue }
		text := job.request.text
		job.next_for_text = first_by_text[text]
		first_by_text[text] = index + 1
		staged++
	}
	if staged == 0 { return ASCIIShapeScope{} }
	batch := &ASCIIShapeBatch{
		jobs: jobs
		first_by_text: first_by_text
		font_generation: harfbuzz_cache_generation
		previous: active_ascii_shape_batch()
		staged: staged
		worker_ticket: options.worker_ticket
		join_workers: options.join_workers
	}
	if parallel_ascii_shape_diagnostics && options.worker_ticket == unsafe { nil } {
		batch.report_jobs()
	}
	C.vox_ascii_shape_batch_set(batch)
	return ASCIIShapeScope{batch: batch}
}

fn (mut batch ASCIIShapeBatch) join_pending_workers(reason string) {
	if batch.worker_ticket == unsafe { nil } { return }
	ready := batch.join_workers(batch.worker_ticket)
	batch.worker_ticket = unsafe { nil }
	if parallel_ascii_shape_diagnostics {
		batch.staged = batch.report_jobs()
		eprintln('VOX_LAYOUT_ASCII_SHAPE_JOIN reason=${reason} ready=${ready}')
	}
}

fn join_pending_ascii_shape_batches() {
	// Idle cache maintenance can retire the shared HarfBuzz handles. Join
	// every active scope before destroying them, including an outer layout.
	mut batch := active_ascii_shape_batch()
	for batch != unsafe { nil } {
		batch.join_pending_workers('font_cache')
		batch = batch.previous
	}
}

pub fn (mut scope ASCIIShapeScope) finish() {
	mut batch := scope.batch
	if batch == unsafe { nil } { return }
	assert voidptr(active_ascii_shape_batch()) == voidptr(batch)
	batch.join_pending_workers('scope_exit')
	C.vox_ascii_shape_batch_set(batch.previous)
	mut discarded := 0
	for index in 0 .. batch.jobs.len {
		mut job := unsafe { &batch.jobs[index] }
		if !job.prepared() { continue }
		if job.buffer != unsafe { nil } { C.hb_buffer_destroy(job.buffer) }
		job.buffer = unsafe { nil }
		job.glyph_count = 0
		discarded++
	}
	if parallel_ascii_shape_diagnostics {
		eprintln('VOX_LAYOUT_ASCII_SHAPE_SCOPE consumed=${batch.staged - discarded} discarded=${discarded}')
	}
	scope.batch = unsafe { nil }
}

fn take_ascii_shape_job(font_key string, text string, params ShapeParams) ?ASCIIShapeJob {
	if params.text_type != .ltr || params.letter_spacing_bits != 0 || params.word_spacing_bits != 0 {
		return none
	}
	mut batch := active_ascii_shape_batch()
	if batch == unsafe { nil } || batch.font_generation != harfbuzz_cache_generation { return none }
	mut link := batch.first_by_text[text]
	for link > 0 {
		mut job := unsafe { &batch.jobs[link - 1] }
		if job.font_key == font_key {
			batch.join_pending_workers('first_use')
			if job.prepared() { return job.take() }
		}
		link = job.next_for_text
	}
	return none
}

fn ascii_harfbuzz_decode_params(text string, font &Font) HarfBuzzDecodeParams {
	return HarfBuzzDecodeParams{
		text: text
		font: font
		text_type: .ltr
		text_length_in_code_units: text.len
		is_ascii: true
	}
}

// Resolve the normal cache and native font keys on the owner thread. The
// batch borrows font handles until the worker group joins.
pub fn prepare_ascii_shape_jobs(requests []ASCIIShapeRequest) []ASCIIShapeJob {
	mut jobs := []ASCIIShapeJob{cap: requests.len}
	mut seen := map[string]bool{}
	mut strikes := map[string]ChromiumNativeStrike{}
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
		mut strike := ChromiumNativeStrike{}
		mut advances := []f32{}
		mut glyphs := []Glyph{}
		$if macos {
			if !serial_ascii_strike_advances && request.text.len <= ascii_shape_strike_max_glyphs {
				strike = if existing := strikes[key] {
					existing
				} else {
					resolved := chromium_native_strike(font, face, true) or { ChromiumNativeStrike{} }
					strikes[key] = resolved
					resolved
				}
				if strike.path != '' {
					advances = []f32{len: request.text.len}
					if !serial_ascii_glyph_decode {
						glyphs = []Glyph{len: request.text.len}
					}
				}
			}
		}
		seen[identity] = true
		jobs << ASCIIShapeJob{
			request: request
			font_key: key
			face: face
			hb_font: hb_font
			strike: strike
			decoding: ascii_harfbuzz_decode_params(request.text, font)
			advances: advances
			glyphs: glyphs
		}
	}
	return jobs
}

// Each worker reads the immutable font and writes its own native buffer,
// advances and glyphs. The caller allocates both V arrays.
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
		$if macos {
			if job.advances.len > 0 {
				source := harfbuzz_buffer_glyphs(buffer)
				if source.count > 0 && source.count <= job.advances.len {
					mut ids := [ascii_shape_strike_max_glyphs]u16{}
					if job.strike.shape_advances(job.hb_font, source.infos, source.positions, source.count,
						&ids[0], job.advances.data) {
						job.advance_count = source.count
						if source.count <= job.glyphs.len {
							job.trailing_whitespace = source.decode_into(mut job.glyphs,
								job.decoding, job.advances)
							job.glyph_count = source.count
							C.hb_buffer_destroy(buffer)
							job.buffer = unsafe { nil }
						}
					}
				}
			}
		}
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
		if !job.prepared() { continue }
		result := job.take()
		cache.publish_ascii_shape_job(result, result.font_key, result.request.text, result.request.font, params)
		stored++
		if parallel_ascii_shape_diagnostics && job.thread_id != caller { off_thread++ }
	}
	if parallel_ascii_shape_diagnostics {
		eprintln('VOX_LAYOUT_ASCII_SHAPES jobs=${jobs.len} stored=${stored} off_thread=${off_thread}')
	}
	return stored
}
