module html

import dom
import platform

fn test_token_attribute_snapshots_copy_records_and_share_immutable_strings() {
	mut attribute := Attribute{local_name:'data-name', value:'payload '.repeat(4096), prefix:'prefix', namespace_:'urn:test'}
	mut token := HTMLToken.make_start_tag('span')
	before := platform.thread_arena_usage().used
	token.add_attribute(attribute)
	owned := create_own_token(&token)
	after := platform.thread_arena_usage().used
	$if prealloc { assert after - before < 4096 }
	assert voidptr(owned.attributes.data) != voidptr(token.attributes.data)
	assert owned.attributes[0].value.str == attribute.value.str
	attribute.value = 'replacement'
	attribute.prefix = none
	token.attributes[0].value = 'changed original token'
	token.attributes[0].namespace_ = none
	assert owned.attributes[0].value == 'payload '.repeat(4096)
	assert owned.attributes[0].prefix? == 'prefix'
	assert owned.attributes[0].namespace_? == 'urn:test'
}

fn test_parser_character_workspace_reuses_capacity_without_changing_emitted_text() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parser := HTMLParser.create(document, '')
	mut texts := []&dom.Text{}
	for index in 0 .. 32 {
		text := document.create_text_node('')
		parser.character_insertion_node = text
		parser.character_insertion_builder << 'Retained text ${index}'.runes()
		buffer := parser.character_insertion_builder.data
		capacity := parser.character_insertion_builder.cap
		parser.flush_character_insertions()
		assert parser.character_insertion_builder.len == 0
		assert parser.character_insertion_builder.cap == capacity
		assert parser.character_insertion_builder.data == buffer
		texts << text
	}
	for index, text in texts { assert text.data() == 'Retained text ${index}' }
}

fn test_token_queue_does_not_recopy_completed_payloads_before_consumption() {
	mut tokenizer := HTMLTokenizer.new('')
	mut token := HTMLToken.make_start_tag('custom-element')
	token.add_attribute(Attribute{local_name:'data-value', value:'immutable payload '.repeat(4096)})
	before := platform.thread_arena_usage().used
	tokenizer.enqueue(token)
	emitted := tokenizer.dequeue() or { panic('missing emitted token') }
	after := platform.thread_arena_usage().used
	$if prealloc { assert after - before < 4096 }
	assert emitted.attributes[0].value.str == token.attributes[0].value.str
	assert tokenizer.next_token()?.is_end_of_file()
	assert emitted.attributes[0].value == 'immutable payload '.repeat(4096)
	// Real tokenizer reuse must leave an earlier token intact as well.
	mut real := HTMLTokenizer.new('<p data-value="first">text<a id="second">tail</a>')
	first := real.next_token()?
	for { next := real.next_token() or { break }; if next.is_end_of_file() { break } }
	assert first.tag_name == 'p'
	assert first.attribute('data-value')? == 'first'
}
