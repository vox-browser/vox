module html

import css
import dom

fn tag_absence_first_with_name(root &dom.Node, name string) ?&dom.Element {
	for child in root.children {
		if element := child.as_element() {
			if element.local_name() == name { return element }
		}
		if found := tag_absence_first_with_name(child, name) { return found }
	}
	return none
}

fn tag_absence_connected_roots(node &dom.Node, mut roots []&dom.Node) {
	roots << node
	for child in node.children {
		if child.is_element() { tag_absence_connected_roots(child, mut roots) }
	}
}

// querySelector for a tag name from every connected element agrees with a
// plain walk, including for names the document has never seen.
fn tag_absence_check(document &dom.Document, names []string, label string) {
	mut roots := []&dom.Node{}
	tag_absence_connected_roots(document.as_node(), mut roots)
	for root in roots {
		for name in names {
			expected := tag_absence_first_with_name(root, name)
			actual := css.query_selector(root, name)
			if element := expected {
				found := actual or { panic('${label}: missed <${name}>') }
				assert voidptr(found) == voidptr(element), '${label} ${name}'
			} else {
				assert actual == none, '${label} ${name}'
			}
		}
	}
}

// Every way markup and scripts add elements to a connected tree records the
// names that the tag-absence shortcut of connected roots relies on.
fn test_connected_tag_absence_follows_parser_markup_cloning_and_adoption() {
	names := ['lazy-one', 'lazy-two', 'lazy-three', 'lazy-four', 'lazy-five', 'lazy-six', 'lazy-seven',
		'p', 'span', 'never-element']
	mut document := parse_document('<!doctype html><body><main id="main"><section id="section"><p>text</p></section><aside id="aside"><lazy-one></lazy-one></aside></main><template id="template"><lazy-five><span>inert</span></lazy-five></template></body>')
	defer { document.finalize() }
	tag_absence_check(document, names, 'parsed')
	mut section := document.get_element_by_id('section')?
	mut main := document.get_element_by_id('main')?
	mut main_node := main.as_node()
	section.set_inner_html('<div><lazy-two class="x"><span>inner</span></lazy-two></div>')!
	tag_absence_check(document, names, 'innerHTML')
	section.insert_adjacent_html('beforeend', '<lazy-three></lazy-three>')!
	tag_absence_check(document, names, 'insertAdjacentHTML')
	// A subtree built detached, then inserted.
	mut wrapper := document.create_element('div')!
	mut wrapper_node := wrapper.as_node()
	_ = wrapper_node.append_child(document.create_element('lazy-four')!.as_node())!
	tag_absence_check(document, names, 'detached build')
	_ = main_node.append_child(wrapper_node)!
	tag_absence_check(document, names, 'detached insert')
	// A deep clone of connected content, and of inert template content.
	copy := section.as_node().clone_node_binding(true)!
	_ = main_node.append_child(copy)!
	tag_absence_check(document, names, 'clone')
	template := document.get_element_by_id('template')?
	template_copy := template.as_node().clone_node_binding(true)!
	_ = main_node.append_child(template_copy)!
	tag_absence_check(document, names, 'template clone')
	// Content adopted from another parsed document.
	mut foreign := parse_document('<!doctype html><body><div id="gift"><lazy-six><lazy-seven></lazy-seven></lazy-six></div></body>')
	defer { foreign.finalize() }
	gift := foreign.get_element_by_id('gift')?
	adopted := document.adopt_node_binding(gift.as_node())!
	tag_absence_check(document, names, 'adopted detached')
	_ = main_node.append_child(adopted)!
	tag_absence_check(document, names, 'adopted insert')
	// Removal leaves the history conservative.
	_ = main_node.remove_child(adopted)!
	_ = main_node.remove_child(wrapper_node)!
	tag_absence_check(document, names, 'removed')
	section.set_outer_html('<article><lazy-two></lazy-two></article>')!
	tag_absence_check(document, names, 'outerHTML')
}
