module adblock

import json2
import platform

fn test_document_filter_decode_owns_all_fields_after_source_and_workspace_retire() {
	assert C.vox_adblock_get_context() == unsafe { nil }
	// Fixture encoding has a separate per-type cache; establish its ordinary
	// lifetime before creating the short-lived source owner under test.
	_ = encode_transport_json(DocumentFilters{})
	expected := DocumentFilters{
		css: '.雪::before{content:"λ😀"}'
		scriptlets: 'const label="λ\x00雪😀";'
		procedural: ['{"selector":".雪","tasks":[["has-text","λ😀"]]}']
		filters: ['site.test##.雪', 'site.test##+js(test,λ😀)']
	}
	mut input := platform.new_arena('document filter encoded input')
	entry := input.enter()
	source := encode_transport_json(expected)
	input.leave(entry)
	mut output := platform.new_arena('document filter decoded output')
	output_entry := output.enter()
	actual := decode_transport_json[DocumentFilters](source)!
	output.leave(output_entry)
	input.release()
	for _ in 0 .. 4 {
		work := platform.begin_thread_scratch('filter decoder overwrite')
		_ = []u8{len: 256 * 1024, init: u8(0xa5)}
		work.finish()
	}
	assert actual == expected
	$if prealloc {
		assert output.contains(actual.css.str)
		assert output.contains(actual.scriptlets.str)
		assert output.contains(actual.procedural.data)
		assert output.contains(actual.procedural[0].str)
		assert output.contains(actual.filters.data)
		assert output.contains(actual.filters[1].str)
	}
	output.release()
	// Reusing the field table after the output owner dies must remain safe.
	assert decode_transport_json[DocumentFilters]('{"css":"after"}')!.css == 'after'
	assert C.vox_adblock_get_context() == unsafe { nil }
}

fn test_document_filter_decode_preserves_codec_errors_and_lenient_defaults() {
	for source in ['', '{', '{"css":"unterminated}', '{"filters":[}'] {
		mut expected := ''
		_ = json2.decode[DocumentFilters](source) or { expected = err.msg(); DocumentFilters{} }
		assert expected != ''
		mut failed := false
		_ = decode_transport_json[DocumentFilters](source) or {
			failed = true
			assert err is json2.JsonDecodeError
			assert err.msg() == expected
			DocumentFilters{}
		}
		assert failed
	}
	for source in ['{}', '{"css":null,"filters":null}', '{"scriptlets":"text","unused":[1,2,3]}'] {
		assert decode_transport_json[DocumentFilters](source)! == json2.decode[DocumentFilters](source)!
	}
}

fn filter_decode_worker(source string) bool {
	decoded := decode_transport_json[DocumentFilters](source) or { return false }
	return decoded.css == '.worker{display:none}' && decoded.filters == ['worker rule']
}

fn test_document_filter_field_metadata_survives_worker_decodes_and_caller_mutation() {
	source := '{"css":".worker{display:none}","filters":["worker rule"]}'
	mut workers := []thread bool{}
	for _ in 0 .. 4 { workers << spawn filter_decode_worker(source) }
	for worker in workers { assert worker.wait() }
	first := decode_transport_json[DocumentFilters](source)!
	// Deliberately mutate this caller's actual returned array, not a clone.
	mut values := unsafe { first.filters }
	values[0] = 'caller mutation'
	second := decode_transport_json[DocumentFilters](source)!
	assert second.filters == ['worker rule']
}

fn document_filter_decode_retention_trial(source string, temporary bool) !i64 {
	mut output := platform.new_arena('document filter decode retention')
	entry := output.enter()
	before := output.usage().used
	value := if temporary { decode_transport_json[DocumentFilters](source)! } else { json2.decode[DocumentFilters](source)! }
	growth := output.usage().used - before
	assert value.css == '.test{display:none}'
	assert value.scriptlets.len > 64 * 1024
	assert value.procedural.len == 2 && value.filters.len == 2
	output.leave(entry)
	output.release()
	return growth
}

fn test_document_filter_decode_keeps_only_owned_output_not_the_parser_index() {
	source := encode_transport_json(DocumentFilters{
		css: '.test{display:none}'
		scriptlets: 'const text="λ😀";\n'.repeat(8192)
		procedural: ['{"selector":".test"}', '{"selector":".other"}']
		filters: ['test rule', 'other rule']
	})
	control := document_filter_decode_retention_trial(source, false)!
	candidate := document_filter_decode_retention_trial(source, true)!
	$if prealloc {
		assert candidate < source.len + 4096
		assert candidate * 4 < control, '${candidate} candidate versus ${control} control bytes'
		println('Document filter decoding: candidate=${candidate} control=${control} bytes')
	}
}
