// SPDX-License-Identifier: BSD-2-Clause
module libjs

struct ModuleLinkState {
mut:
	index int
	stack []&SourceTextModule
}

// CyclicModule.cpp::InnerModuleLinking: keep each strongly connected component
// on the stack until all its imports and environments have initialized.
fn (mut module_record SourceTextModule) inner_module_link(mut vm VM,mut state ModuleLinkState) ! {
	if module_record.module_status!=.unlinked { return }
	if vm.stack_info_.size_free()<512*1024 || state.index>=4096 { return vm.throw_error(.internal_error,'LibJS module linking budget exceeded') }
	module_record.module_status=.linking
	module_record.module_dfs_index=state.index
	module_record.module_dfs_ancestor=state.index
	state.index++;state.stack << &module_record
	executable := module_record.compile_module(mut vm)!
	for request in module_record.requested_module_requests() {
		mut target := module_record.imported_source_module(mut vm,request)!
		target.inner_module_link(mut vm,mut state)!
		if target.module_status==.linking && target.module_dfs_ancestor<module_record.module_dfs_ancestor {
			module_record.module_dfs_ancestor=target.module_dfs_ancestor
		}
	}
	program := module_record.parsed.program.kind.program_data or { return error('Missing module program') }
	for name in module_record.module_export_names([]) {
		resolution := module_record.resolve_module_export(name,[]) or { return vm.throw_error(.syntax_error,'Unresolvable module export ${name.str()}') }
		// Ambiguous star exports are omitted from namespaces, and only fail if
		// explicitly imported or re-exported under a name.
		if resolution.ambiguous {
			for statement in program.scope.children {
				if statement.kind.tag!=.export_stmt { continue }
				data := statement.kind.export_data or { continue }
				if data.entries.any((it.export_name or { utf16_string('') })==name) {
					return vm.throw_error(.syntax_error,'Ambiguous named module export ${name.str()}')
				}
			}
			continue
		}
		if !resolution.namespace {
			target_executable := resolution.target.module_executable or { return error('Export target has no executable') }
			if !target_executable.global_bindings.any(it.name==resolution.name) { return vm.throw_error(.syntax_error,'Module export has no binding ${name.str()}') }
		}
	}
	module_record.initialize_module_environment(mut vm,executable)!
	if module_record.module_dfs_ancestor==module_record.module_dfs_index {
		for state.stack.len>0 {
			mut target := state.stack.pop();target.module_status=.linked
			if voidptr(target)==voidptr(&module_record) { break }
		}
	}
}

pub fn (mut module_record SourceTextModule) link(mut vm VM) ! {
	if module_record.module_status in [.linked,.evaluating,.evaluated] { return }
	mut state := ModuleLinkState{}
	module_record.inner_module_link(mut vm,mut state) or {
		for mut target in state.stack {
			target.module_status=.unlinked
			target.module_environment=none
			target.module_namespace_=none
		}
		return err
	}
}
