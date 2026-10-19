module encoding

import encoding.hex
import json2
import os

pub struct Utf16CommonSourceStep {
pub:
	input_hex      string
	last           bool
	ok             bool
	capacity       int
	bytes          []u8
	life_cycle     string
	lead_surrogate u16
	has_lead_byte  bool
	lead_byte      u8
	be             bool
	pending_bmp    bool
}

pub struct Utf16CommonSourceSequence {
pub:
	be         bool
	remove_bom bool
	fatal      bool
	steps      []Utf16CommonSourceStep
}

fn assert_utf16_common_source_owner(common &TextDecoderCommonMixin, step Utf16CommonSourceStep) {
	assert common.utf16_decoder_present_
	life_cycle := match step.life_cycle {
		'AtUtf16BeStart' { Utf16DecoderLifeCycle.at_utf16_be_start }
		'AtUtf16LeStart' { Utf16DecoderLifeCycle.at_utf16_le_start }
		'SeenUtf16BeFirst' { Utf16DecoderLifeCycle.seen_utf16_be_first }
		'SeenUtf16LeFirst' { Utf16DecoderLifeCycle.seen_utf16_le_first }
		'Converting' { Utf16DecoderLifeCycle.converting }
		'Finished' { Utf16DecoderLifeCycle.finished }
		else { panic('unexpected actual Source UTF16 life cycle ' + step.life_cycle) }
	}
	assert common.utf16_decoder_.life_cycle == life_cycle
	variant := common.utf16_decoder_.variant
	assert variant.lead_surrogate == step.lead_surrogate
	assert variant.be == step.be && variant.pending_bmp == step.pending_bmp
	if byte := variant.lead_byte {
		assert step.has_lead_byte && byte == step.lead_byte
	} else {
		assert !step.has_lead_byte
	}
	assert common.pending_input.len == 0 && !common.bom_seen
}

fn utf16_common_source_sequences() ![]Utf16CommonSourceSequence {
	return json2.decode[[]Utf16CommonSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_common_owners.json')!)!
}

fn run_utf16_common_stream_step(mut stream TextDecoderStream, input []u8, last bool) !string {
	if last { return stream.flush_and_enqueue() }
	return stream.decode_and_enqueue_chunk(input)
}

fn test_source_common_utf16_utf8_items_and_empty_end_of_queue_match_genuine_native_owner() {
	cases := utf16_common_source_sequences()!
	assert cases.len == 1728
	mut checked := 0
	mut withheld_partial := 0
	for item in cases {
		mut common := new_text_decoder_common(if item.be { 'utf-16be' } else { 'utf-16le' }, TextDecoderOptions{ fatal: item.fatal, ignore_bom: !item.remove_bom })
		assert !common.utf16_decoder_present_
		common.set_decoder_to_new_instance_of_encoding_decoder()
		for index, step in item.steps {
			assert step.last == (index == 3)
			input := hex.decode(step.input_hex)!
			if step.last {
				assert input.len == 0
			}
			mut output := TextDecoderOutputQueue{}
			if _ := common.process_an_item(input, step.last, mut output) {
				assert step.ok
				assert common.serialize_io_queue(mut output)!.bytes() == step.bytes
			} else {
				assert !step.ok && item.fatal
				assert err.msg() == 'TypeError: Decoding failed'
				assert common.serialize_io_queue(mut output)! == ''
				if step.bytes.len > 0 { withheld_partial++ }
			}
			assert_utf16_common_source_owner(&common, step)
			checked++
		}
	}
	assert checked == 6912 && withheld_partial == 60
}

fn test_source_utf16_stream_typed_consumer_uses_same_owner_and_withholds_failed_output() {
	cases := utf16_common_source_sequences()!
	mut checked := 0
	for item in cases {
		mut stream := TextDecoderStream.create(if item.be { 'utf-16be' } else { 'utf-16le' }, TextDecoderOptions{ fatal: item.fatal, ignore_bom: !item.remove_bom })!
		mut expected_chunks := []string{}
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			if decoded := run_utf16_common_stream_step(mut stream, input, step.last) {
				assert step.ok && decoded.bytes() == step.bytes
				if decoded != '' { expected_chunks << decoded }
			} else {
				assert !step.ok && item.fatal
				assert err.msg() == 'TypeError: Decoding failed'
				assert stream.chunks() == expected_chunks
				assert_utf16_common_source_owner(&stream.TextDecoderCommonMixin, step)
				checked++
				// A genuine TransformStream would reject this callback. The
				// existing typed consumer has no controller/error lifecycle;
				// exercise only calls through its first failed algorithm.
				break
			}
			assert stream.chunks() == expected_chunks
			assert_utf16_common_source_owner(&stream.TextDecoderCommonMixin, step)
			checked++
		}
	}
	assert checked == 6372
}

fn test_source_utf16_common_fatal_preserves_existing_output_before_failed_callback() {
	cases := utf16_common_source_sequences()!
	mut checked := 0
	for item in cases {
		if !item.fatal { continue }
		mut common := new_text_decoder_common(if item.be { 'utf-16be' } else { 'utf-16le' }, TextDecoderOptions{ fatal: true, ignore_bom: !item.remove_bom })
		common.set_decoder_to_new_instance_of_encoding_decoder()
		for step in item.steps {
			mut output := TextDecoderOutputQueue{}
			output.push('kept')!
			if _ := common.process_an_item(hex.decode(step.input_hex)!, step.last, mut output) {
				assert step.ok
			} else {
				assert !step.ok
				assert err.msg() == 'TypeError: Decoding failed'
				assert common.serialize_io_queue(mut output)! == 'kept'
				if step.bytes.len > 0 { checked++ }
			}
			assert_utf16_common_source_owner(&common, step)
		}
	}
	assert checked == 60
}

fn test_source_utf16_common_and_stream_require_actual_owner_before_processing_in_production() {
	if mode := os.getenv_opt('VOX2_UTF16_COMMON_UNINITIALIZED') {
		label := if mode.ends_with('be') { 'utf-16be' } else { 'utf-16le' }
		mut common := new_text_decoder_common(label, TextDecoderOptions{})
		if mode.starts_with('stream') {
			mut stream := TextDecoderStream{ TextDecoderCommonMixin: common }
			stream.decode_and_enqueue_chunk([u8(0)]) or { panic(err) }
		} else {
			mut output := TextDecoderOutputQueue{}
			common.process_an_item([u8(0)], false, mut output) or { panic(err) }
		}
		panic('Source Common VERIFY unexpectedly returned')
	}
	for mode in ['common_le', 'common_be', 'stream_le', 'stream_be'] {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_UTF16_COMMON_UNINITIALIZED'] = mode
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		assert process.code != 0 && output.contains('Source VERIFY: TextDecoderCommon owns its StreamingDecoder'), output
	}
}
