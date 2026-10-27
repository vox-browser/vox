module html

import dom
import platform

fn test_shadow_template_presence_walk_does_not_allocate_or_change_ordinary_tree() {
	mut document := parse_document('<main id="content">' +
		'<section><b>text</b><i>more</i></section>'.repeat(64) + '</main>')
	defer { document.finalize() }
	mut arena := platform.new_arena('shadow template presence')
	entry := arena.enter()
	for _ in 0 .. 16 {
		assert !has_declarative_shadow_templates(document.as_node())
		materialize_declarative_shadow_roots(document.as_node())
	}
	arena.leave(entry)
	$if prealloc {
		assert arena.usage().used == 0
	}
	arena.release()
	assert document.as_node().descendant_text_content() == 'textmore'.repeat(64)
	content := document.get_element_by_id('content') or { panic('missing content') }
	assert content.as_node().children_as_vector().len == 64
}

fn test_shadow_template_presence_finds_templates_in_existing_closed_roots() {
	mut document := parse_document('<main id="host"><template shadowrootmode="closed"><section></section></template></main>')
	defer { document.finalize() }
	host := document.get_element_by_id('host') or { panic('missing host') }
	root := host.shadow_root() or { panic('missing closed root') }
	assert !has_declarative_shadow_templates(document.as_node())
	mut section := root.as_node().first_child() or { panic('missing section') }
	mut template_element := document.create_element('template') or { panic(err) }
	template_element.set_attribute_value('shadowrootmode', 'open')
	template := unsafe { &dom.HTMLTemplateElement(template_element) }
	mut content := template.content().as_node()
	content.append_child(document.create_text_node('nested').as_node()) or { panic(err) }
	section.append_child(template_element.as_node()) or { panic(err) }
	assert has_declarative_shadow_templates(document.as_node())
	materialize_declarative_shadow_roots(document.as_node())
	assert !has_declarative_shadow_templates(document.as_node())
	inner_host := section.as_element() or { panic('missing inner host') }
	inner_root := inner_host.shadow_root() or { panic('missing inner root') }
	assert inner_root.as_node().descendant_text_content() == 'nested'
}

fn test_shadow_template_presence_preserves_inert_templates_and_later_mutations() {
	mut document := parse_document('<main id="host"><template><b>inert</b></template></main>')
	defer { document.finalize() }
	host := document.get_element_by_id('host') or { panic('missing host') }
	assert has_declarative_shadow_templates(document.as_node())
	materialize_declarative_shadow_roots(document.as_node())
	assert host.shadow_root() == none
	child := host.as_node().first_child() or { panic('missing template') }
	mut element := child.as_element() or { panic('missing template element') }
	element.set_attribute_value('shadowrootmode', 'OpEn')
	materialize_declarative_shadow_roots(document.as_node())
	root := host.shadow_root() or { panic('missing root after mutation') }
	assert root.as_node().descendant_text_content() == 'inert'
	assert !has_declarative_shadow_templates(document.as_node())
}
