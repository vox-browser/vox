module css

import dom
import platform

fn test_pending_full_style_pass_covers_has_and_later_selective_updates_without_mutation_histories() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := full_invalidation_element(document, document.as_node(), 'html')
	section := full_invalidation_element(document, root.as_node(), 'section')
	mut trigger := full_invalidation_element(document, section.as_node(), 'i')
	target := full_invalidation_element(document, section.as_node(), 'span')
	add_document_author_style_sheet(document, 'span{color:blue}section:has(.on) span{color:red}')
	css_style_computer_for(document)
	document.update_style()
	mut scope := css_style_scope_for_document(document)
	assert scope.pending_has_invalidation_features.len == 0
	document.set_needs_full_style_update(true)
	trigger.set_attribute_value('class', 'on')
	assert scope.pending_has_invalidation_features.len == 0
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	trigger.remove_attribute('class')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	assert scope.pending_has_invalidation_features.len == 0
}

fn test_pending_full_pass_does_not_allocate_selective_invalidation_records_per_node() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := full_invalidation_element(document, document.as_node(), 'html')
	mut target := full_invalidation_element(document, root.as_node(), 'div')
	document.set_needs_full_style_update(true)
	mut node := target.as_node()
	properties := [dom.InvalidationProperty{type_:.class, name:'trigger'}]
	node.invalidate_style_with_properties(.element_attribute_change, properties, dom.StyleInvalidationOptions{})
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		node.invalidate_style(.element_attribute_change)
		node.invalidate_style_with_properties(.element_attribute_change, properties, dom.StyleInvalidationOptions{})
	}
	after := platform.thread_arena_usage().used
	$if prealloc { assert after == before }
}

fn test_full_pass_pending_before_host_attribute_change_updates_shadow_style() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := full_invalidation_element(document, document.as_node(), 'html')
	mut host := full_invalidation_element(document, root.as_node(), 'div')
	shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open}) or { panic(err) }
	target := full_invalidation_element(document, unsafe { &dom.Node(shadow) }, 'span')
	add_shadow_root_author_style_sheet(shadow, 'span{color:blue}:host(.on) span{color:red}')
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	document.set_needs_full_style_update(true)
	host.set_attribute_value('class', 'on')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	host.remove_attribute('class')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
}

fn test_full_pass_covers_inherited_language_and_direction_has_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := full_invalidation_element(document, document.as_node(), 'html')
	section := full_invalidation_element(document, root.as_node(), 'section')
	mut trigger := full_invalidation_element(document, section.as_node(), 'i')
	target := full_invalidation_element(document, section.as_node(), 'span')
	root.set_attribute_value('lang', 'en')
	trigger.set_attribute_value('dir', 'ltr')
	add_document_author_style_sheet(document, 'span{color:blue}section:has(i:lang(fr)) span{color:red}section:has(i:dir(rtl)) span{background-color:green}')
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	mut scope := css_style_scope_for_document(document)
	document.set_needs_full_style_update(true)
	root.set_attribute_value('lang', 'fr')
	trigger.set_attribute_value('dir', 'rtl')
	assert scope.pending_has_invalidation_features.len == 0
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	assert computed_value_for(target, .background_color) or { '' } == 'rgb(0, 128, 0)'
	root.set_attribute_value('lang', 'en')
	trigger.set_attribute_value('dir', 'ltr')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	assert computed_value_for(target, .background_color) or { '' } == 'rgba(0, 0, 0, 0)'
}
