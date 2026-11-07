module main

import dom
import platform

fn test_adblock_token_survey_retains_only_sorted_owned_strings_and_sees_edits() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element('html')!
	_ = document.as_node().append_child(root.as_node())!
	for i in 0 .. 128 {
		mut child := document.create_element('div')!
		child.set_attribute_value('id', 'node${i}')
		child.set_attribute_value('class', 'shared duplicate shared\tduplicate')
		_ = root.as_node().append_child(child.as_node())!
	}
	mut arena := platform.new_arena('retained adblock tokens')
	entry := arena.enter()
	tokens := browser_adblock_tokens(document)
	arena.leave(entry)
	assert tokens.len == 130
	assert tokens[0] == '#node0'
	assert tokens[tokens.len - 2] == '.duplicate'
	assert tokens.last() == '.shared'
	mut retained_bytes := tokens.len * int(sizeof(string))
	for token in tokens {
		retained_bytes += (token.len + 1 + 15) / 16 * 16
	}
	$if prealloc {
		assert arena.usage().used <= retained_bytes + 256
	}
	mut child := document.get_element_by_id('node0')?
	child.set_attribute_value('id', 'edited')
	child.set_attribute_value('class', 'new')
	updated := browser_adblock_tokens(document)
	assert '#edited' in updated
	assert '.new' in updated
	assert '#node0' !in updated
	// The earlier snapshot still owns its strings after a second workspace
	// and live attribute mutation, including when retired pages are poisoned.
	assert '#node0' in tokens
	assert '.new' !in tokens
	arena.release()
}
