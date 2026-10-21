module html

import dom
import platform

fn test_native_parser_character_buffers_and_encoding_retire_with_tokenizer() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	mut parser := HTMLParser.create(document, '')
	storage := parser.tokenizer_storage
	assert storage != unsafe { nil }
	run := 'buffered 日本語 😀 '.repeat(4096).runes()
	before := document.native_storage().arena.usage().used
	for start := 0; start < run.len; start += 64 {
		end := if start + 64 < run.len { start + 64 } else { run.len }
		parser.append_character_insertion(run[start])
		parser.append_character_insertion_run(run[start + 1..end])
	}
	assert document.native_storage().arena.usage().used - before < 4096
	assert storage.contains(parser.character_insertion_builder.data)
	text := document.create_text_node('')
	parser.character_insertion_node = text
	encoded := parser.character_insertion_text()
	assert storage.contains(encoded.str)
	parser.flush_character_insertions()
	assert !storage.contains(text.data().str)
	parser.retire_tokenizer_storage()
	assert parser.character_insertion_builder.len == 0
	assert parser.character_insertion_builder.cap == 0
	assert text.data() == 'buffered 日本語 😀 '.repeat(4096)
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_native_parser_retired_character_storage_matches_ordinary_text_and_raw_text() {
	for markup in [
		'<p>first &amp; 日本語 😀</p><p>second</p>',
		'<style>p { color: red; }</style><script>var text = "😀 &amp;";</script><p>tail</p>',
		'<table>before<tr><td>inside &lt; cell</td></tr>after</table>',
		'<textarea>\nfirst\n日本語 😀</textarea><pre>\nlast</pre>',
	] {
		mut reference := dom.Document.create(dom.url_about_blank())
		reference.set_scripting_enabled_by_embedder(false)
		mut ordinary := HTMLParser.create(reference, markup)
		ordinary.run()
		expected := reference.document_element()?.outer_html() or { panic(err) }
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_scripting_enabled_by_embedder(false)
		document.enable_native_storage()
		mut allocations := document.enter_native_storage()
		mut parser := HTMLParser.create(document, markup)
		parser.run()
		assert parser.tokenizer_storage == unsafe { nil }
		assert parser.character_insertion_builder.len == 0
		actual := document.document_element()?.outer_html() or { panic(err) }
		assert actual == expected
		allocations.finish()
		document.finalize()
		document.release_native_storage()
		reference.finalize()
	}
}
