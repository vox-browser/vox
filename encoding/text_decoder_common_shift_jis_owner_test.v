module encoding

import encoding.hex
import json2
import os

pub struct ShiftJisCommonSourceStep {
pub:
	input_hex  string
	last       bool
	ok         bool
	capacity   int
	bytes      []u8
	has_lead   bool
	lead       u8
	life_cycle string
}

pub struct ShiftJisCommonSourceSequence {
pub:
	remove_bom bool
	mode       int
	steps      []ShiftJisCommonSourceStep
}

fn shift_jis_common_source_sequences() ![]ShiftJisCommonSourceSequence {
	return json2.decode[[]ShiftJisCommonSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_streaming_sequences.json')!)!
}

fn assert_shift_jis_common_source_owner(common &TextDecoderCommonMixin, step ShiftJisCommonSourceStep) {
	assert common.shift_jis_decoder_present_
	assert common.shift_jis_decoder_.life_cycle.str() == step.life_cycle.to_lower()
	if lead := common.shift_jis_decoder_.variant.lead {
		assert step.has_lead && lead == step.lead
	} else {
		assert !step.has_lead
	}
	assert common.pending_input.len == 0 && !common.bom_seen
}

fn test_source_common_shift_jis_items_and_empty_end_of_queue_match_genuine_native_ffi() {
	cases := shift_jis_common_source_sequences()!
	mut calls := 0
	mut withheld_partial := 0
	for item in cases {
		if item.mode < 2 { continue }
		mut common := new_text_decoder_common('shift_jis', TextDecoderOptions{ fatal: item.mode == 3, ignore_bom: !item.remove_bom })
		assert !common.shift_jis_decoder_present_
		common.set_decoder_to_new_instance_of_encoding_decoder()
		for index, step in item.steps {
			assert step.last == (index == 2)
			input := hex.decode(step.input_hex)!
			if step.last {
				assert input.len == 0
			}
			mut output := TextDecoderOutputQueue{}
			if _ := common.process_an_item(input, step.last, mut output) {
				assert step.ok
				assert common.serialize_io_queue(mut output)!.bytes() == step.bytes
			} else {
				assert !step.ok && item.mode == 3
				assert err.msg() == 'TypeError: Decoding failed'
				assert common.serialize_io_queue(mut output)! == ''
				if step.bytes.len > 0 { withheld_partial++ }
			}
			assert_shift_jis_common_source_owner(&common, step)
			calls++
		}
	}
	assert calls == 852 && withheld_partial == 8
}

fn run_shift_jis_common_stream_step(mut stream TextDecoderStream, input []u8, last bool) !string {
	if last { return stream.flush_and_enqueue() }
	return stream.decode_and_enqueue_chunk(input)
}

fn test_source_shift_jis_stream_typed_consumer_retains_lead_and_withholds_failed_output() {
	cases := shift_jis_common_source_sequences()!
	mut calls := 0
	for item in cases {
		if item.mode < 2 { continue }
		mut stream := TextDecoderStream.create('Shift_JIS', TextDecoderOptions{ fatal: item.mode == 3, ignore_bom: !item.remove_bom })!
		assert stream.encoding() == 'shift_jis'
		mut expected_chunks := []string{}
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			if decoded := run_shift_jis_common_stream_step(mut stream, input, step.last) {
				assert step.ok && decoded.bytes() == step.bytes
				if decoded != '' { expected_chunks << decoded }
			} else {
				assert !step.ok && item.mode == 3
				assert err.msg() == 'TypeError: Decoding failed'
				assert stream.chunks() == expected_chunks
				assert_shift_jis_common_source_owner(&stream.TextDecoderCommonMixin, step)
				calls++
				// A genuine TransformStream rejects this algorithm. The existing typed
				// consumer has no real controller/error lifecycle; stop at first failure.
				break
			}
			assert stream.chunks() == expected_chunks
			assert_shift_jis_common_source_owner(&stream.TextDecoderCommonMixin, step)
			calls++
		}
	}
	assert calls == 742
}

fn test_source_shift_jis_common_error_preserves_existing_queue_before_failed_callback() {
	cases := shift_jis_common_source_sequences()!
	mut withheld_partial := 0
	for item in cases {
		if item.mode != 3 { continue }
		mut common := new_text_decoder_common('shift_jis', TextDecoderOptions{ fatal: true, ignore_bom: !item.remove_bom })
		common.set_decoder_to_new_instance_of_encoding_decoder()
		for step in item.steps {
			mut output := TextDecoderOutputQueue{}
			output.push('kept')!
			if _ := common.process_an_item(hex.decode(step.input_hex)!, step.last, mut output) {
				assert step.ok
			} else {
				assert !step.ok && err.msg() == 'TypeError: Decoding failed'
				assert common.serialize_io_queue(mut output)! == 'kept'
				if step.bytes.len > 0 { withheld_partial++ }
			}
			assert_shift_jis_common_source_owner(&common, step)
		}
	}
	assert withheld_partial == 8
}

fn test_source_shift_jis_common_and_stream_require_actual_owner_in_production() {
	if mode := os.getenv_opt('VOX2_SHIFT_JIS_COMMON_UNINITIALIZED') {
		mut common := new_text_decoder_common('shift_jis', TextDecoderOptions{})
		if mode == 'stream' {
			mut stream := TextDecoderStream{ TextDecoderCommonMixin: common }
			stream.decode_and_enqueue_chunk([u8(0x82)]) or { panic(err) }
		} else {
			mut output := TextDecoderOutputQueue{}
			common.process_an_item([u8(0x82)], false, mut output) or { panic(err) }
		}
		panic('Source Common VERIFY unexpectedly returned')
	}
	for mode in ['common', 'stream'] {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_SHIFT_JIS_COMMON_UNINITIALIZED'] = mode
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		assert process.code != 0 && output.contains('Source VERIFY: TextDecoderCommon owns its StreamingDecoder'), output
	}
}

fn test_source_shift_jis_common_new_instance_replaces_actual_retained_lead_owner() {
	mut common := new_text_decoder_common('shift_jis', TextDecoderOptions{})
	common.set_decoder_to_new_instance_of_encoding_decoder()
	mut output := TextDecoderOutputQueue{}
	common.process_an_item([u8(0x82)], false, mut output)!
	assert common.serialize_io_queue(mut output)! == ''
	assert common.shift_jis_decoder_.variant.lead? == u8(1)
	common.set_decoder_to_new_instance_of_encoding_decoder()
	assert common.shift_jis_decoder_present_
	assert common.shift_jis_decoder_.variant.lead == none
	assert common.shift_jis_decoder_.life_cycle == .converting
	assert common.pending_input.len == 0 && !common.bom_seen
}
