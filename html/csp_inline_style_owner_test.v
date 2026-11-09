module html

import css
import dom

@[heap]
struct InlineStyleCSPProbe {
mut:
	checks int
}

fn test_inline_style_csp_checks_connection_attribute_writes_and_preserves_cssom_clones() {
	mut document := dom.Document.create(dom.URL{value:'https://inline-style.test/'})
	defer { document.finalize() }
	probe := &InlineStyleCSPProbe{}
	document.set_csp_hook(dom.DocumentCSPHook{
		target: probe
		inline_check: fn (target voidptr, _ &dom.Element, kind string, _ string) bool {
			assert kind == 'style-attribute'
			mut probe := unsafe { &InlineStyleCSPProbe(target) }
			probe.checks++
			return true
		}
	})
	mut root := document.create_element('html')!
	document.as_node().append_child(root.as_node())!
	mut element := document.create_element('div')!
	element.set_attribute_value('style', 'color:red')
	mut style := css.element_style(element)
	assert probe.checks == 0 && style.get_property_value('color') == 'red'
	root.as_node().append_child(element.as_node())!
	assert probe.checks == 1 && style.get_property_value('color') == ''
	assert element.get_attribute_value('style') == 'color:red'
	element.set_attribute_value('style', 'width:13px')
	assert probe.checks == 2 && style.get_property_value('width') == ''
	style.set_property('color','blue','')!
	assert probe.checks == 2 && style.get_property_value('color') == 'blue'
	clone := element.as_node().clone_node(none, true, none)!
	root.as_node().append_child(clone)!
	assert probe.checks == 2
	clone_element := clone.as_element()?
	clone_style := css.element_style(clone_element)
	assert clone_style.get_property_value('color') == 'blue'
	mut detached := document.create_element('div')!
	detached.set_attribute_value('style', 'height:17px')
	detached_clone := detached.as_node().clone_node(none, false, none)!
	root.as_node().append_child(detached_clone)!
	assert probe.checks == 3
	detached_clone_element := detached_clone.as_element()?
	detached_clone_style := css.element_style(detached_clone_element)
	assert detached_clone_style.get_property_value('height') == ''
}
