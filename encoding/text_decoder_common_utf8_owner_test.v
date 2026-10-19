module encoding

import encoding.hex
import json2
import os

pub struct Utf8CommonOwnerSourceStep {
pub:
	input_hex      string
	last           bool
	status         string
	output_hex     string
	life_cycle     string
	code_point     u32
	bytes_seen     int
	bytes_needed   int
	lower_boundary u8
	upper_boundary u8
	panic          bool
}

pub struct Utf8CommonOwnerSourceSequence {
pub:
	remove_bom bool
	mode       int
	steps      []Utf8CommonOwnerSourceStep
}

fn utf8_common_owner_source_life_cycle(name string) Utf8DecoderLifeCycle {
	return match name {
		'AtUtf8Start' { Utf8DecoderLifeCycle.at_utf8_start }
		'SeenUtf8First' { Utf8DecoderLifeCycle.seen_utf8_first }
		'SeenUtf8Second' { Utf8DecoderLifeCycle.seen_utf8_second }
		'Converting' { Utf8DecoderLifeCycle.converting }
		'Finished' { Utf8DecoderLifeCycle.finished }
		else { panic('unexpected actual Source UTF8 life cycle ' + name) }
	}
}

fn test_source_common_utf8_retained_owner_matches_actual_native_string_calls() {
	cases := json2.decode[[]Utf8CommonOwnerSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_streaming_sequences.json')!)!
	mut checked := 0
	for item in cases {
		if item.mode < 2 { continue }
		mut common := new_text_decoder_common('utf-8', TextDecoderOptions{ fatal: item.mode == 3, ignore_bom: !item.remove_bom })
		assert !common.utf8_decoder_present_
		common.set_decoder_to_new_instance_of_encoding_decoder()
		for step in item.steps {
			if step.panic { break }
			mut output := TextDecoderOutputQueue{}
			input := hex.decode(step.input_hex)!
			if _ := common.process_an_item(input, step.last, mut output) {
				assert step.status == 'input_empty'
				assert common.serialize_io_queue(mut output)!.bytes() == hex.decode(step.output_hex)!
			} else {
				assert item.mode == 3 && step.status == 'malformed'
				assert err.msg() == 'TypeError: Decoding failed'
				// Source C++ append_decoded_output withholds a failed
				// bridge's partial callback bytes from the actual queue.
				assert common.serialize_io_queue(mut output)! == ''
			}
			assert common.utf8_decoder_.life_cycle == utf8_common_owner_source_life_cycle(step.life_cycle)
			assert common.utf8_decoder_.variant.code_point == step.code_point
			assert common.utf8_decoder_.variant.bytes_seen == step.bytes_seen && common.utf8_decoder_.variant.bytes_needed == step.bytes_needed
			assert common.utf8_decoder_.variant.lower_boundary == step.lower_boundary && common.utf8_decoder_.variant.upper_boundary == step.upper_boundary
			assert common.pending_input.len == 0 && !common.bom_seen
			checked++
		}
	}
	assert checked == 1876
}

fn test_source_stream_consumer_retains_bom_and_variant_slots_until_real_flush() {
	mut stream := TextDecoderStream.create('utf-8', TextDecoderOptions{})!
	assert stream.decode_and_enqueue_chunk([u8(0xef)])! == ''
	assert stream.utf8_decoder_.life_cycle == .seen_utf8_first
	assert stream.decode_and_enqueue_chunk([u8(0xbb)])! == ''
	assert stream.utf8_decoder_.life_cycle == .seen_utf8_second
	assert stream.decode_and_enqueue_chunk([u8(0xbf), `X`, 0xe1, 0x80])! == 'X'
	assert stream.utf8_decoder_.life_cycle == .converting
	assert stream.utf8_decoder_.variant.bytes_needed == 2
	assert stream.utf8_decoder_.variant.bytes_seen == 1
	assert stream.pending_input.len == 0
	assert stream.decode_and_enqueue_chunk([u8(`A`), 0])!.bytes() == [u8(0xef), 0xbf, 0xbd, `A`,
		0]
	assert stream.flush_and_enqueue()! == ''
	assert stream.utf8_decoder_.life_cycle == .finished
	assert stream.chunks() == ['X', '\ufffdA\x00']

	mut preserve := TextDecoderStream.create('utf-8', TextDecoderOptions{ ignore_bom: true })!
	assert preserve.decode_and_enqueue_chunk([u8(0xef)])! == ''
	assert preserve.utf8_decoder_.life_cycle == .converting
	assert preserve.utf8_decoder_.variant.bytes_needed == 2
	assert preserve.decode_and_enqueue_chunk([u8(0xbb), 0xbf])! == '\ufeff'
}

fn test_source_common_fatal_does_not_append_failed_callback_output_and_keeps_owner_state() {
	mut common := new_text_decoder_common('utf-8', TextDecoderOptions{ fatal: true })
	common.set_decoder_to_new_instance_of_encoding_decoder()
	mut output := TextDecoderOutputQueue{}
	common.process_an_item([u8(`A`)], false, mut output)!
	if _ := common.process_an_item([u8(`B`), 0xff], false, mut output) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Decoding failed'
	}
	assert common.serialize_io_queue(mut output)! == 'A'
	assert common.utf8_decoder_.life_cycle == .converting
	assert common.utf8_decoder_.variant.bytes_needed == 0
	common.set_decoder_to_new_instance_of_encoding_decoder()
	assert common.utf8_decoder_.life_cycle == .at_utf8_start
	assert common.utf8_decoder_.variant.code_point == 0
}

fn test_source_common_utf8_requires_its_actual_decoder_owner_before_processing() {
	if os.getenv('VOX2_UTF8_COMMON_UNINITIALIZED') == '1' {
		mut common := new_text_decoder_common('utf-8', TextDecoderOptions{})
		mut output := TextDecoderOutputQueue{}
		common.process_an_item([u8(`A`)], false, mut output) or { panic(err) }
		panic('Source Common VERIFY unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_UTF8_COMMON_UNINITIALIZED'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: TextDecoderCommon owns its StreamingDecoder'), output
}
