import encoding

fn main() {
	for fatal in [false, true] {
		mut stream := encoding.TextDecoderStream.create('shift_jis', encoding.TextDecoderOptions{ fatal: fatal })!
		for input in [[u8(0x82)], [u8(0xa0)]] {
			if result := stream.decode_and_enqueue_chunk(input) {
				println('fatal=${fatal} input=${input} units=${result.runes()} bytes=${result.bytes()}')
			} else {
				println('fatal=${fatal} input=${input} error=${err.msg()}')
			}
		}
		if result := stream.flush_and_enqueue() {
			println('fatal=${fatal} empty-flush units=${result.runes()}')
		} else {
			println('fatal=${fatal} empty-flush error=${err.msg()}')
		}
	}
}
