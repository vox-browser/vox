module compression

pub struct DecompressionOutput {
pub:
	bytes []u8
	error_message string
	complete bool
}

// One decoder per stream. vlib's pure V codecs decode whole streams, so the
// input is buffered and decoded again once it has grown by a quarter (or on
// flush); the total work stays linear in the stream size. Output arrives when
// the stream's end marker does. The output and terminal error are separate: a
// pending reader still receives decoded bytes before trailing input errors it.
@[heap]
pub struct IncrementalDecompressor {
mut:
	format CompressionFormat
	input []u8
	// Buffered length at the last decoding attempt.
	attempted int
	closed bool
	complete bool
	failed bool
}

pub fn IncrementalDecompressor.create(format CompressionFormat) !&IncrementalDecompressor {
	return &IncrementalDecompressor{format: format}
}

pub fn (mut decoder IncrementalDecompressor) close() {
	decoder.input = []u8{}
	decoder.closed = true
}

fn (mut decoder IncrementalDecompressor) push_buffered(input []u8, finish bool) ([]u8, string) {
	decoder.input << input
	buffered := decoder.input.len
	if buffered == 0 || (!finish && decoder.attempted > 0
		&& buffered - decoder.attempted < decoder.attempted / 4) {
		return []u8{}, ''
	}
	decoder.attempted = buffered
	stream := decode_leading_stream(decoder.format, decoder.input) or {
		if stream_error_needs_more_input(decoder.format, err, finish) { return []u8{}, '' }
		return []u8{}, 'TypeError: Invalid compressed input'
	}
	decoder.complete = true
	decoder.input = []u8{}
	if stream.consumed != buffered {
		return stream.data, 'TypeError: Extra input after the compressed stream'
	}
	return stream.data, ''
}

pub fn (mut decoder IncrementalDecompressor) push(input []u8, finish bool) DecompressionOutput {
	mut output := []u8{}
	mut failure := ''
	if decoder.failed || (decoder.complete && input.len > 0) {
		failure = 'TypeError: Extra input after the compressed stream'
	} else if !decoder.complete && decoder.closed {
		failure = 'TypeError: Decompression stream is closed'
	} else if !decoder.complete {
		output, failure = decoder.push_buffered(input, finish)
	}
	if finish && !decoder.complete && failure == '' { failure = 'TypeError: Incomplete compressed input' }
	if failure != '' { decoder.failed = true }
	if decoder.complete || decoder.failed || finish { decoder.close() }
	return DecompressionOutput{bytes: output, error_message: failure, complete: decoder.complete}
}
