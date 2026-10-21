module css

import dom
import platform

fn test_empty_substitution_contexts_allocate_no_custom_function_maps_and_remain_independent() {
	mut contexts := []GuardedSubstitutionContexts{cap:256}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 { contexts << GuardedSubstitutionContexts{} }
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first := StyleScope.new(document.as_node())
	element := document.create_element('div')!
	second := StyleScope.new(element.as_node())
	contexts[0].remember_definition_scope(17, first)
	contexts[1].remember_definition_scope(17, second)
	contexts[0].remember_definition_scope(29, second)
	assert voidptr(contexts[0].definition_scope(17)?) == voidptr(first)
	assert voidptr(contexts[1].definition_scope(17)?) == voidptr(second)
	assert contexts[1].definition_scope(29) == none
	assert contexts[255].definition_scope(17) == none
	contexts[0].remember_definition_scope(17, second)
	assert voidptr(contexts[0].definition_scope(17)?) == voidptr(second)
}
