module css

import dom
import platform

fn unchanged_has_element(document &dom.Document, parent &dom.Node, tag string, classes string) &dom.Element {
	mut element := document.create_element_ns(dom.namespace_html_uri,tag) or { panic(err) }
	if classes != '' { element.set_attribute_value('class',classes) }
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn unchanged_has_fixture(condition string) (&dom.Document,&dom.Element,&dom.Element,&dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{})
	root := unchanged_has_element(document,document.as_node(),'html','')
	body := unchanged_has_element(document,root.as_node(),'body','')
	anchor := unchanged_has_element(document,body.as_node(),'section','scope')
	trigger := unchanged_has_element(document,anchor.as_node(),'i','flag')
	target := unchanged_has_element(document,anchor.as_node(),'span','target')
	add_document_author_style_sheet(document,'.target{color:blue}.scope${condition} .target{color:red}')
	css_style_computer_for(document)
	document.update_style()
	return document,anchor,trigger,target
}

fn unchanged_has_color(target &dom.Element) string {
	style := computed_properties_for_element(target) or { panic('missing target style') }
	value := style.property(.color,.no) or { panic('missing target color') }
	return value.css_text
}

fn test_unchanged_has_arguments_keep_descendant_style_after_irrelevant_child_mutations() {
	mut document,anchor,_,target := unchanged_has_fixture(':has(> .flag:not(.missing))')
	defer { document.finalize() }
	before := computed_properties_for_element(target) or { panic('missing initial style') }
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
	path := unchanged_has_element(document,anchor.as_node(),'b','unrelated')
	document.update_style()
	after_insert := computed_properties_for_element(target) or { panic('missing retained style') }
	assert voidptr(before) == voidptr(after_insert)
	mut parent := anchor.as_node()
	parent.remove_child(path.as_node()) or { panic(err) }
	document.update_style()
	after_remove := computed_properties_for_element(target) or { panic('missing retained style') }
	assert voidptr(before) == voidptr(after_remove)
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
}

fn test_changed_positive_and_negated_has_arguments_restyle_descendants() {
	for condition in [':has(> .flag:not(.missing))',':not(:has(> .flag:not(.missing)))'] {
		mut document,_,mut trigger,target := unchanged_has_fixture(condition)
		defer { document.finalize() }
		negated := condition.starts_with(':not')
		assert unchanged_has_color(target) == if negated {'rgb(0, 0, 255)'}else{'rgb(255, 0, 0)'}
		trigger.set_attribute_value('class','missing')
		document.update_style()
		assert unchanged_has_color(target) == if negated {'rgb(255, 0, 0)'}else{'rgb(0, 0, 255)'}
		trigger.set_attribute_value('class','flag')
		document.update_style()
		assert unchanged_has_color(target) == if negated {'rgb(0, 0, 255)'}else{'rgb(255, 0, 0)'}
	}
}

fn test_short_circuit_has_arguments_keep_later_alternatives_live() {
	mut document,anchor,mut first,target := unchanged_has_fixture(':has(> .flag, > .second)')
	defer { document.finalize() }
	mut second := unchanged_has_element(document,anchor.as_node(),'i','second')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
	first.set_attribute_value('class','inactive')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
	second.set_attribute_value('class','inactive')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(0, 0, 255)'
	first.set_attribute_value('class','flag')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
}

fn test_has_sibling_results_recheck_featureless_adjacency_changes() {
	mut document,anchor,_,target := unchanged_has_fixture(':has(+ .neighbor)')
	defer { document.finalize() }
	parent := anchor.as_node().parent() or { panic('missing body') }
	neighbor := unchanged_has_element(document,parent,'aside','neighbor')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
	gap := unchanged_has_element(document,parent,'div','')
	mut parent_node := unsafe { &dom.Node(parent) }
	parent_node.insert_before(gap.as_node(),neighbor.as_node(),false)
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(0, 0, 255)'
	parent_node.remove_child(gap.as_node()) or { panic(err) }
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
}

fn test_later_stylesheet_queries_join_retained_has_observations() {
	mut document,anchor,_,mut target := unchanged_has_fixture(':has(> .flag)')
	defer { document.finalize() }
	add_document_author_style_sheet(document,'.scope:has(> .extra) .target{color:green}')
	target.set_needs_style_update(true)
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
	extra := unchanged_has_element(document,anchor.as_node(),'i','extra')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(0, 128, 0)'
	mut parent := anchor.as_node()
	parent.remove_child(extra.as_node()) or { panic(err) }
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
}

fn test_scoped_and_namespace_has_observations_keep_conservative_invalidation() {
	for source in ['@scope (.scope){:scope:has(> .flag) .target{color:green}}',
		'@namespace s "http://www.w3.org/2000/svg";.scope:has(> .flag) .target{color:green}'] {
		mut document,anchor,mut trigger,_ := unchanged_has_fixture(':has(> .flag)')
		defer { document.finalize() }
		add_document_author_style_sheet(document,source)
		document.set_needs_full_style_update(true)
		document.update_style()
		assert !has_argument_results_unchanged(anchor)
		trigger.set_attribute_value('class','inactive')
		document.update_style()
		assert !has_argument_results_unchanged(anchor)
	}
}

fn test_has_observation_overflow_keeps_later_state_changes_live() {
	mut document,anchor,mut trigger,target := unchanged_has_fixture(':has(> .flag)')
	defer { document.finalize() }
	mut source := ''
	for index in 1 .. 67 {
		source += '.scope:has(> .flag:nth-child(${index})) .target{color:red}'
	}
	add_document_author_style_sheet(document,source)
	document.set_needs_full_style_update(true)
	document.update_style()
	assert !has_argument_results_unchanged(anchor)
	trigger.set_attribute_value('class','inactive')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(0, 0, 255)'
}

fn test_has_observations_outlive_a_retiring_style_query_workspace() {
	mut document,anchor,_,target := unchanged_has_fixture(':has(> .flag:not(.missing))')
	document.enable_native_storage()
	defer { document.finalize(); document.release_native_storage() }
	mut computer := css_style_computer_for(document)
	key := u64(anchor.as_node().unique_id().value())
	computer.has_result_cache_.observed_arguments_.delete(key)
	mut scratch := platform.new_arena('has observation query caller')
	entry := scratch.enter()
	computer.compute_style_with_seeded_ancestors(dom.AbstractElement.new(target,none))
	$if prealloc {
		observed := computer.has_result_cache_.observed_arguments_[key] or { panic('missing observation') }
		assert !scratch.contains(observed.arguments.data)
	}
	scratch.leave(entry)
	scratch.release()
	assert has_argument_results_unchanged(anchor)
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
}

fn test_equal_has_truth_keeps_new_hover_dependencies_live() {
	mut document,_,mut trigger,target := unchanged_has_fixture(':has(> .candidate:is(.selected,:hover))')
	defer { document.finalize() }
	trigger.set_attribute_value('class','candidate selected')
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
	trigger.set_attribute_value('class','candidate')
	document.set_hovered_node(trigger.as_node())
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(255, 0, 0)'
	document.set_hovered_node(none)
	document.update_style()
	assert unchanged_has_color(target) == 'rgb(0, 0, 255)'
}
