module html

import platform

// The first scripts in a process usually run with a document's native storage
// entered. Growing the process-wide execution context stack there would leave
// it pointing into that document's released arena for every later page.
fn test_execution_context_stack_growth_survives_release_of_the_entering_document_arena() {
	mut realms := []&ScriptingRealm{}
	for _ in 0 .. 64 {
		realms << &ScriptingRealm{}
	}
	base_depth := html_scripting_execution_context_stack.len
	mut document := platform.new_arena('released scripting document')
	entry := document.enter()
	for index in 0 .. realms.len {
		push_scripting_execution_context(realms[index])
	}
	document.leave(entry)
	$if prealloc {
		assert !document.contains(html_scripting_execution_context_stack.data)
	}
	for _ in 0 .. realms.len {
		html_scripting_execution_context_stack.delete_last()
	}
	document.release()
	for _ in 0 .. 4 {
		work := platform.begin_thread_scratch('execution context overwrite')
		_ = []u8{len: 256 * 1024, init: u8(0xa5)}
		work.finish()
	}
	for index in 0 .. realms.len {
		push_scripting_execution_context(realms[index])
	}
	assert html_scripting_execution_context_stack.len == base_depth + realms.len
	assert voidptr(html_scripting_execution_context_stack.last()) == voidptr(realms.last())
	for _ in 0 .. realms.len {
		html_scripting_execution_context_stack.delete_last()
	}
	assert html_scripting_execution_context_stack.len == base_depth
}
