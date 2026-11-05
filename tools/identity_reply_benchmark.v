// Component diagnostic. Oracle creation and warmup are outside the counters.
module main

import browserjs.querywire
import platform
import processmetrics
import x.json2

fn measure_identity_reply(name string, keys []string, repetitions int) {
	mut expected := []string{cap: keys.len}
	for key in keys {
		expected << json2.encode(json2.Any({
			'bridgeKey': json2.Any(key)
		}))
	}
	for index, key in keys {
		assert querywire.encode_identity_reply(key) == expected[index]
	}
	mut checksum := u64(0)
	start := processmetrics.instruction_snapshot()
	for group_start := 0; group_start < repetitions; group_start += 64 {
		mut scratch := platform.begin_thread_scratch('identity reply component')
		end := if group_start + 64 < repetitions { group_start + 64 } else { repetitions }
		for _ in group_start .. end {
			for index, key in keys {
				actual := querywire.encode_identity_reply(key)
				assert actual == expected[index]
				checksum += u64(actual.len)
			}
		}
		scratch.finish()
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	println('{"scene":"${name}","instructions":${instructions},"encodes":${keys.len * repetitions},"checksum":${checksum}}')
}

fn main() {
	measure_identity_reply('element-keys', ['__element_0', '__element_1024', '__query_99999',
		'__created_1000000'], 8192)
	measure_identity_reply('empty-key', [''], 32768)
	measure_identity_reply('escaped-keys', ['"\\/\b\f\n\r\t', '__element_"quoted"\\path'], 8192)
	measure_identity_reply('unicode-keys', ['__element_λ😀', 'é漢\u2028\u2029'], 8192)
	measure_identity_reply('255-byte-key', ['x'.repeat(255)], 4096)
	measure_identity_reply('256-byte-key', ['x'.repeat(256)], 4096)
	measure_identity_reply('257-byte-key', ['x'.repeat(257)], 4096)
	measure_identity_reply('long-key', ['x'.repeat(16384) + '"😀'], 256)
	measure_identity_reply('malformed-utf8', [[u8(0xe2), 0x28, 0xa1, 0xff].bytestr()], 16384)
}
