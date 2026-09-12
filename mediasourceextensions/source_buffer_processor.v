// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SourceBufferProcessor.{h,cpp}. Demuxing is introduced by the
// following WebM translation slice; this initial processor preserves the input,
// append-state, eviction, and reset boundaries used by SourceBuffer.
module mediasourceextensions

pub enum AppendState {
	waiting_for_segment
	parsing_init_segment
	parsing_media_segment
}

@[heap]
pub struct SourceBufferProcessor {
mut:
	updating_         bool
	input_buffer_     []u8
	append_state_     AppendState
	mode_             AppendMode
	buffer_full_flag_ bool
}

pub fn SourceBufferProcessor.create() &SourceBufferProcessor {
	return &SourceBufferProcessor{}
}

pub fn (processor &SourceBufferProcessor) updating() bool {
	return processor.updating_
}

pub fn (mut processor SourceBufferProcessor) set_updating(value bool) {
	processor.updating_ = value
}

pub fn (processor &SourceBufferProcessor) mode() AppendMode {
	return processor.mode_
}

pub fn (processor &SourceBufferProcessor) is_buffer_full() bool {
	return processor.buffer_full_flag_
}

pub fn (mut processor SourceBufferProcessor) append_to_input_buffer(bytes []u8) {
	processor.input_buffer_ << bytes
}

pub fn (processor &SourceBufferProcessor) input_buffer_length() int {
	return processor.input_buffer_.len
}

// The first implementation has no container parser yet, so every parse enters
// the append-error path. The next upstream commit supplies WebM demuxing.
pub fn (_ &SourceBufferProcessor) run_segment_parser_loop() bool {
	return false
}

// https://w3c.github.io/media-source/#sourcebuffer-reset-parser-state
pub fn (mut processor SourceBufferProcessor) reset_parser_state() {
	processor.input_buffer_.clear()
	processor.append_state_ = .waiting_for_segment
}

// https://w3c.github.io/media-source/#sourcebuffer-coded-frame-eviction
pub fn (_ &SourceBufferProcessor) run_coded_frame_eviction() {
	// Track-buffer eviction is added with coded-frame processing.
}
