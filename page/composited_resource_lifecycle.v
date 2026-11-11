// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Page-owned media and canvas lifecycle passes performed around a compositor
// rendering update. The concrete HTML objects are represented by retained
// state records at this module boundary.
module page

import dom

pub fn (p &Page) has_media_element_playing_audio(document &dom.Document) bool {
	document_id := document.unique_id()
	for id, state in p.media_elements {
		// Registrations outlive the documents that made them; only the queried
		// document's own media can be playing in it, and only those owners are
		// known to be alive.
		if state.document_id != document_id {
			continue
		}
		if callbacks := p.media_element_callbacks_[id] {
			if callbacks.is_playing_audio != unsafe { nil } && callbacks.is_playing_audio(callbacks.target, document) {
				return true
			}
			continue
		}
		// Preserve the explicit state-record adapter for owners without a concrete
		// HTML callback; actual media above queries its current Document and state.
		if p.page_mute_state() != .muted && state.playing_audio && !state.muted {
			return true
		}
	}
	return false
}

pub fn (mut p Page) sync_media_element_video_sink_ticking() {
	for id in p.media_elements.keys() {
		mut state := p.media_elements[id]
		state.video_sink_sync_count++
		if state.is_video {
			state.video_paint_facts_push_count++
		}
		p.store_media_element(id, state)
	}
}

pub fn (mut p Page) restore_all_media_element_video_sinks() {
	for id in p.media_elements.keys() {
		mut state := p.media_elements[id]
		if state.has_video_sink {
			state.video_sink_attached = true
			state.video_sink_restore_count++
			p.store_media_element(id, state)
		}
	}
}

pub fn (mut p Page) detach_all_media_element_video_sinks_after_compositor_lost() {
	for id in p.media_elements.keys() {
		mut state := p.media_elements[id]
		if state.has_video_sink {
			state.video_sink_attached = false
			state.video_sink_detach_count++
			p.store_media_element(id, state)
		}
	}
}

pub fn (mut p Page) prepare_canvas_contexts_for_compositing() {
	for id in p.canvas_elements_.keys() {
		mut state := p.canvas_elements_[id]
		state.prepare_call_count++
		if state.dirty {
			state.dirty = false
			state.content_generation++
			if state.context_kind != .none {
				state.context_prepare_count++
			}
		}
		// HTMLCanvasElement pushes paint facts on every preparation pass, even
		// when its content generation did not change.
		state.paint_facts_push_count++
		p.store_canvas_element(id, state)
	}

	// Context preparation only records commands. Flushing here ensures canvas
	// updates reach the compositor even when no other object repaints.
	if p.has_compositor_host() {
		mut host := p.compositor_host()
		host.flush_canvas_2d_stream()
	}
}

pub fn (mut p Page) notify_all_canvas_elements_of_lost_backing_storage() {
	for id in p.canvas_elements_.keys() {
		mut state := p.canvas_elements_[id]
		match state.context_kind {
			.webgl { state.webgl_restore_count++ }
			.canvas_2d { state.backing_storage_loss_count++ }
			.none {}
		}
		p.store_canvas_element(id, state)
	}
}

pub fn (mut p Page) notify_all_webgl_contexts_lost() {
	for id in p.canvas_elements_.keys() {
		mut state := p.canvas_elements_[id]
		if state.context_kind == .webgl {
			state.webgl_context_lost = true
			state.webgl_connection_loss_count++
			p.store_canvas_element(id, state)
		}
	}
}
