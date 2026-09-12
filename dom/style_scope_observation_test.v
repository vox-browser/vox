module dom

struct StyleScopeTestCollector {
mut:
	scopes []&StyleScope
}

fn test_node_visits_each_observing_style_scope_once() {
	document := Document.create(url_about_blank())
	mut outer_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	outer_shadow := outer_host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut outer_shadow_node := unsafe { &Node(outer_shadow) }
	mut inner_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	outer_shadow_node.append_child(inner_host.as_node()) or { panic(err) }
	inner_shadow := inner_host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut inner_shadow_node := unsafe { &Node(inner_shadow) }
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	inner_shadow_node.append_child(target.as_node()) or { panic(err) }

	collector := &StyleScopeTestCollector{}
	target.as_node().for_each_style_scope_which_may_observe_the_node(fn [collector] (scope &StyleScope) {
		unsafe {
			mut mutable_collector := &StyleScopeTestCollector(collector)
			mutable_collector.scopes << scope
		}
	})
	assert collector.scopes.len == 3
	assert inner_shadow.style_scope() in collector.scopes
	assert outer_shadow.style_scope() in collector.scopes
	assert document.style_scope() in collector.scopes
	assert target.as_node().style_scope() == inner_shadow.style_scope()
}
