module html

import dom
import editing

fn test_insert_node_command_unapplies_and_reapplies_the_same_node() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><i id="reference">tail</i></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	reference := document.get_element_by_id('reference') or { panic('missing reference') }
	inserted := document.create_element('b') or { panic(err) }
	mut inserted_node := unsafe { &dom.Node(inserted.as_node()) }
	inserted_node.append_child(document.create_text_node('new').as_node()) or { panic(err) }
	mut command := editing.new_insert_node_command(inserted.as_node(), host.as_node(), reference.as_node())

	command.apply() or { panic(err) }
	assert host.as_node().first_child()? == inserted.as_node()
	assert command.unapply()
	assert inserted.as_node().parent() == none
	assert command.reapply()
	assert host.as_node().first_child()? == inserted.as_node()
}

fn test_remove_node_command_restores_original_position() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><b>left</b><i id="removed">middle</i><u>right</u></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	removed := document.get_element_by_id('removed') or { panic('missing removed node') }
	mut command := editing.new_remove_node_command(removed.as_node())

	command.apply() or { panic(err) }
	assert host.as_node().child_count() == 2
	assert command.is_lasting_node_removal()
	assert command.unapply()
	assert host.as_node().child_at_index(1)? == removed.as_node()
	assert command.reapply()
	assert removed.as_node().parent() == none
}

fn test_replace_data_command_revalidates_utf16_content() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>A😀B</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	text_node := host.as_node().first_child() or { panic('missing text') }
	text := text_node.as_character_data() or { panic('text is not character data') }
	mut command := editing.new_replace_data_command(text, 1, '😀', 'X')

	command.apply() or { panic(err) }
	assert text.data() == 'AXB'
	assert command.unapply()
	assert text.data() == 'A😀B'
	assert command.reapply()
	assert text.data() == 'AXB'
	mut mutable_text := unsafe { &dom.CharacterData(text) }
	mutable_text.replace_data(1, 1, 'Y') or { panic(err) }
	assert !command.unapply()
	assert text.data() == 'AYB'
}

fn test_split_text_command_reuses_the_recorded_suffix_node() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>abcd</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	text_node := host.as_node().first_child() or { panic('missing text') }
	text := unsafe { &dom.Text(text_node) }
	mut command := editing.new_split_text_command(text, 2)

	command.apply() or { panic(err) }
	right := command.split_text_result() or { panic('missing split result') }
	assert text.data() == 'ab'
	assert right.data() == 'cd'
	assert command.unapply()
	assert host.as_node().child_count() == 1
	assert text.data() == 'abcd'
	assert command.reapply()
	assert host.as_node().child_at_index(1)? == right.as_node()
	assert text.data() == 'ab'
	assert right.data() == 'cd'
}

fn test_set_attribute_command_restores_presence_and_value() {
	document := parse_document('<!doctype html><body><div contenteditable><span id="target" class="old"></span></div></body>')
	target := document.get_element_by_id('target') or { panic('missing target') }
	mut command := editing.new_set_attribute_command(target, 'class', none, 'old', 'new')

	command.apply() or { panic(err) }
	assert target.get_attribute_value('class') == 'new'
	assert command.unapply()
	assert target.get_attribute_value('class') == 'old'
	assert command.reapply()
	assert target.get_attribute_value('class') == 'new'

	mut removal := editing.new_set_attribute_command(target, 'class', none, 'new', none)
	removal.apply() or { panic(err) }
	assert !target.has_attribute('class')
	assert removal.unapply()
	assert target.get_attribute_value('class') == 'new'
}

fn test_editing_range_insertion_splits_text_through_commands() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>abcd</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	text := host.as_node().first_child() or { panic('missing text') }
	range_ := dom.Range.create_from_boundary_points(text, 2, text, 2)
	inserted := document.create_element('b') or { panic(err) }
	mut inserted_node := unsafe { &dom.Node(inserted.as_node()) }
	inserted_node.append_child(document.create_text_node('X').as_node()) or { panic(err) }

	editing.insert_node_into_range(range_, inserted.as_node()) or { panic(err) }

	assert host.inner_html()! == 'ab<b>X</b>cd'
	assert range_.end() == dom.BoundaryPoint{
		node: host.as_node()
		offset: 2
	}
}
