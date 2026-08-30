module webassembly

import webidl

fn streaming_module_bytes() []u8 {
	return [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, 9, 1, 3, `e`, `n`, `v`,
		1, `f`, 0, 0, 7, 5, 1, 1, `f`, 0, 0]
}

fn test_compile_instantiate_and_streaming_mime_boundary() {
	bytes := streaming_module_bytes()
	imports := {
		'env': {
			'f': ExternalValue{
				kind:  .function_
				value: webidl.callback_value()
			}
		}
	}
	source := instantiate(webidl.BufferSource.array_buffer(bytes), imports)!
	assert source.module.exports().len == 1
	assert source.instance.exports()['f'].kind == .function_
	streamed := compile_streaming(StreamingResponse{
		content_type: 'application/wasm; charset=binary'
		body:         bytes
	})!
	assert streamed.imports().len == 1
	for mime in ['text/plain', '', 'application/octet-stream'] {
		if _ := compile_streaming(StreamingResponse{ content_type: mime, body: bytes }) {
			assert false
		} else {
			assert err.msg().starts_with('TypeError:')
		}
	}
}
