module devtools

import dom
import ui2

const html_namespace = 'http://www.w3.org/1999/xhtml'

struct Sample {
	document &dom.Document
	html     &dom.Node
	head     &dom.Node
	body     &dom.Node
	main     &dom.Node
	para     &dom.Node
	image    &dom.Node
	comment  &dom.Node
	empty    &dom.Node
}

fn sample_element(document &dom.Document, name string) &dom.Node {
	element := document.create_element_ns(html_namespace, name) or { panic(err) }
	return element.as_node()
}

fn sample_append(parent &dom.Node, child &dom.Node) {
	mut target := unsafe { &dom.Node(parent) }
	target.append_child(child) or { panic(err) }
}

fn sample_attribute(node &dom.Node, name string, value string) {
	mut element := node.as_element() or { panic('not an element') }
	element.set_attribute_value(name, value)
}

// <html><head><title>Hello</title></head><body>
//   <main id="app" class="card wide"><p>…long text…</p><img src="a.png"></main>
//   <!-- note --><div></div></body></html>
fn sample() Sample {
	document := dom.Document.create(dom.url_about_blank())
	html := sample_element(document, 'html')
	head := sample_element(document, 'head')
	title := sample_element(document, 'title')
	body := sample_element(document, 'body')
	main := sample_element(document, 'main')
	para := sample_element(document, 'p')
	image := sample_element(document, 'img')
	empty := sample_element(document, 'div')
	comment := document.create_comment(' note ').as_node()
	sample_append(document.as_node(), html)
	sample_append(html, head)
	sample_append(head, title)
	sample_append(title, document.create_text_node('Hello').as_node())
	sample_append(html, body)
	sample_append(body, document.create_text_node('\n  ').as_node())
	sample_append(body, main)
	sample_attribute(main, 'id', 'app')
	sample_attribute(main, 'class', 'card wide')
	sample_append(main, para)
	sample_append(para, document.create_text_node('First line\nsecond   line').as_node())
	sample_append(main, image)
	sample_attribute(image, 'src', 'a.png')
	sample_append(body, comment)
	sample_append(body, empty)
	return Sample{
		document: document
		html:     html
		head:     head
		body:     body
		main:     main
		para:     para
		image:    image
		comment:  comment
		empty:    empty
	}
}

fn row_text(row Row) string {
	mut text := ''
	for segment in row.segments {
		text += segment.text
	}
	return '${'  '.repeat(row.depth)}${text}'
}

fn tree_text(tools &DevTools) []string {
	return tools.rows.map(row_text(it))
}

fn opened(s Sample) &DevTools {
	mut tools := &DevTools{
		open: true
	}
	tools.sync(s.document, 1)
	tools.rebuild(s.document)
	return tools
}

fn test_opens_with_html_and_body_expanded_and_body_selected() {
	s := sample()
	tools := opened(s)
	assert tools.selected == node_id(s.body)
	assert tree_text(tools) == [
		'<html>',
		'  <head>…</head>',
		'  <body>',
		'    <main id="app" class="card wide">…</main>',
		'    <!-- note -->',
		'    <div></div>',
		'  </body>',
		'</html>',
	]
	assert tools.rows[0].expandable && tools.rows[0].expanded
	assert tools.rows[1].expandable && !tools.rows[1].expanded
	assert tools.rows[6].kind == .close_tag
}

fn test_rows_inline_short_text_and_omit_void_closing_tags() {
	s := sample()
	mut tools := opened(s)
	tools.toggle(node_id(s.head))
	tools.toggle(node_id(s.main))
	tools.rebuild(s.document)
	tools.toggle(node_id(s.para))
	tools.rebuild(s.document)
	text := tree_text(tools)
	assert '    <title>Hello</title>' in text
	assert '        "First line second line"' in text
	assert '      <img src="a.png">' in text
	assert !text.any(it.contains('</img>'))
	title_row := tools.rows[tools.row_index(node_id(s.head)) + 1]
	assert !title_row.expandable
}

fn test_collapsing_an_ancestor_moves_the_selection_to_it() {
	s := sample()
	mut tools := opened(s)
	tools.toggle(node_id(s.main))
	tools.rebuild(s.document)
	tools.select(node_id(s.image))
	assert tools.selected == node_id(s.image)
	tools.toggle(node_id(s.main))
	assert tools.selected == node_id(s.main)
	tools.rebuild(s.document)
	assert tools.row_index(node_id(s.image)) < 0
}

fn test_keyboard_navigation_follows_rows() {
	s := sample()
	mut tools := opened(s)
	tools.select(node_id(s.main))
	assert tools.key('down')
	assert tools.selected == node_id(s.comment)
	assert tools.key('up')
	assert tools.selected == node_id(s.main)
	assert tools.key('right')
	tools.rebuild(s.document)
	assert tools.expanded[node_id(s.main)] or { false }
	assert tools.key('right')
	assert tools.selected == node_id(s.para)
	assert tools.key('left')
	assert tools.selected == node_id(s.main)
	assert tools.key('left')
	tools.rebuild(s.document)
	assert !(tools.expanded[node_id(s.main)] or { false })
	assert tools.key('home')
	assert tools.selected == node_id(s.html)
	assert !tools.key('x')
}

fn test_reveal_expands_ancestors_and_survives_rebuild() {
	s := sample()
	mut tools := opened(s)
	assert tools.reveal_node(s.image)
	tools.rebuild(s.document)
	assert tools.selected == node_id(s.image)
	assert tools.row_index(node_id(s.image)) > 0
	assert tools.reveal
	assert tools.breadcrumbs().map(node_label(it)) == ['html', 'body', 'main#app.card.wide', 'img']
}

fn test_attribute_edits_reach_the_dom() {
	s := sample()
	mut tools := opened(s)
	id := node_id(s.main)
	assert tools.set_attribute(id, 'data-state', 'ready')
	element := s.main.as_element() or { panic('main') }
	assert element.get_attribute('data-state') or { '' } == 'ready'
	assert tools.set_attribute(id, 'class', 'card')
	assert tools.remove_attribute(id, 'id')
	tools.rebuild(s.document)
	assert tree_text(tools)[3] == '    <main class="card" data-state="ready">…</main>'
	assert !tools.set_attribute(id, '  ', 'x')
	assert tools.error == 'Enter an attribute name'
	assert !tools.set_attribute(id, 'bad name', 'x')
	assert tools.error != ''
}

fn test_delete_selects_next_then_previous_sibling_then_parent() {
	s := sample()
	mut tools := opened(s)
	assert tools.delete(node_id(s.comment))
	assert tools.selected == node_id(s.empty)
	assert s.comment.parent() == none
	tools.rebuild(s.document)
	assert tools.delete(node_id(s.empty))
	assert tools.selected == node_id(s.main)
	tools.rebuild(s.document)
	assert tools.delete(node_id(s.main))
	assert tools.selected == node_id(s.body)
	tools.rebuild(s.document)
	assert tree_text(tools) == ['<html>', '  <head>…</head>', '  <body></body>', '</html>']
	assert !tools.delete(node_id(s.document.as_node()))
}

fn test_text_editor_replaces_character_data() {
	s := sample()
	mut tools := opened(s)
	tools.toggle(node_id(s.main))
	tools.rebuild(s.document)
	tools.toggle(node_id(s.para))
	tools.rebuild(s.document)
	text := s.para.first_child() or { panic('text') }
	assert tools.begin_edit(node_id(text), .text)
	tools.rebuild(s.document)
	editor_index := tools.row_index(node_id(text))
	assert tools.rows[editor_index].kind == .editor
	assert tools.row_extent(tools.rows[editor_index]) > row_height
	assert tools.row_at(tools.row_top(editor_index) + 30) == editor_index
	assert tools.row_at(tools.row_top(editor_index + 1) + 1) == editor_index + 1
	assert tools.apply_edit('Edited')
	assert text.text_content() or { '' } == 'Edited'
	assert tools.editor == none
	// The document element cannot be replaced from markup.
	assert !tools.begin_edit(node_id(s.html), .html)
	assert tools.error.contains('document element')
	assert !tools.begin_edit(node_id(s.main), .text)
}

fn test_navigation_resets_per_document_state() {
	s := sample()
	mut tools := opened(s)
	tools.toggle(node_id(s.main))
	assert !tools.sync(s.document, 1)
	assert tools.sync(s.document, 2)
	assert !(tools.expanded[node_id(s.main)] or { false })
	other := sample()
	assert tools.sync(other.document, 2)
	tools.rebuild(other.document)
	assert tools.node(node_id(s.main)) == none
	assert tools.selected == node_id(other.body)
}

fn test_actions_round_trip() {
	assert action('close', 0, '') == 'devtools:close'
	assert action('select', 42, '') == 'devtools:select:42'
	parsed := parse_action(action('attr-set', 7, 'xlink:href')) or { panic('parse') }
	assert parsed.verb == 'attr-set' && parsed.node == 7 && parsed.arg == 'xlink:href'
	assert (parse_action('devtools:pick') or { panic('pick') }).verb == 'pick'
	assert parse_action('find-bar:1:next') == none
}

fn test_click_detects_double_clicks_on_the_same_row() {
	mut tools := &DevTools{}
	assert !tools.click(5, 0)
	assert tools.click(5, double_click_ns - 1)
	assert !tools.click(5, double_click_ns)
	assert !tools.click(6, double_click_ns + 1)
	assert !tools.click(5, double_click_ns * 4)
}

fn test_pane_height_keeps_part_of_the_document_visible() {
	assert pane_height(300, 900) == 300
	assert pane_height(10, 900) == min_height
	assert pane_height(2000, 900) == 900 - min_document_height
	assert pane_height(300, 100) == min_height
}

fn test_shorten_collapses_whitespace() {
	assert shorten('  a \n\t b  ', 10) == 'a b'
	assert shorten('abcdef', 3) == 'abc…'
}

fn find_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_element(child, id) {
			return found
		}
	}
	return none
}

fn test_elements_declare_tree_sidebar_and_editor() {
	s := sample()
	mut tools := opened(s)
	tools.picking = true
	pane := tools.elements(ui2.rect(0, 500, 1000, 300))
	assert pane.id == 'devtools'
	picker := find_element(pane, 'devtools-pick') or { panic('picker') }
	assert picker.action_id == 'devtools:pick' && picker.accessibility_value == 'on'
	tree := find_element(pane, tree_id) or { panic('tree') }
	assert tree.children.len == tools.rows.len
	body_row := find_element(pane, 'devtools-row-${node_id(s.body)}') or { panic('body row') }
	assert body_row.action_id == action('select', node_id(s.body), '')
	assert body_row.accessibility_value == 'selected'
	assert body_row.menu.any(it.id == action('delete', node_id(s.body), ''))
	assert find_element(pane, 'devtools-row-${node_id(s.body)}-end') != none
	main_toggle := find_element(pane, 'devtools-row-${node_id(s.main)}-toggle') or { panic('toggle') }
	assert main_toggle.action_id == action('toggle', node_id(s.main), '')
	tools.select(node_id(s.main))
	pane2 := tools.elements(ui2.rect(0, 500, 1000, 300))
	class_field := find_element(pane2, attribute_value_id(node_id(s.main), 1)) or { panic('class field') }
	assert class_field.text == 'card wide'
	assert class_field.submit_id == action('attr-set', node_id(s.main), 'class')
	assert find_element(pane2, new_attribute_name_id(node_id(s.main))) != none
	crumbs := find_element(pane2, 'devtools-breadcrumbs') or { panic('crumbs') }
	assert crumbs.children.len == 3
	assert tools.begin_edit(node_id(s.comment), .text)
	tools.rebuild(s.document)
	pane3 := tools.elements(ui2.rect(0, 500, 1000, 300))
	editor := find_element(pane3, editor_id) or { panic('editor') }
	assert editor.text == ' note '
	assert find_element(pane3, 'devtools-editor-apply') != none
	// Narrow windows drop the sidebar width proportionally.
	assert layout(500, 300).sidebar_width == 200
}
