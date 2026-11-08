module main

import compression
import encoding.base64
import x.json2

// https://compression.spec.whatwg.org/
// Scripts see CompressionStream and DecompressionStream as TransformStreams.
// Legacy internal complete-buffer query. JavaScript constructors are installed
// by the native TransformStream binding, with one codec context per stream.
fn compact_compression_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	kind := json_string_property(request, 'kind') or { '' }
	format := compression.parse_compression_format(json_string_property(request, 'format') or { '' })!
	data := base64.decode(json_string_property(request, 'data') or { '' })
	match kind {
		'checkCompress' {
			_ = compression.CompressionStream.construct_impl(format)!
			return 'null'
		}
		'checkDecompress' {
			_ = compression.DecompressionStream.construct_impl(format)!
			return 'null'
		}
		'compress' {
			mut stream := compression.CompressionStream.construct_impl(format)!
			mut writable := stream.writable()
			if data.len > 0 { writable.write(data)! }
			writable.close()!
			mut readable := stream.readable()
			return json2.encode(base64.encode(readable.read_all()))
		}
		'decompress' {
			mut stream := compression.DecompressionStream.construct_impl(format)!
			mut writable := stream.writable()
			if data.len > 0 {
				writable.write(data) or { return error('TypeError: ${err.msg().trim_string_left('TypeError: ')}') }
			}
			writable.close() or { return error('TypeError: ${err.msg().trim_string_left('TypeError: ')}') }
			mut readable := stream.readable()
			return json2.encode(base64.encode(readable.read_all()))
		}
		else {
			return error('Invalid compression operation')
		}
	}
}
