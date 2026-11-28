module libjs

// A module environment keeps its declarations (and namespace imports) in its
// DeclarativeEnvironment bindings and its named imports, which are indirect
// bindings, in `imports`; the two never share a name. Binding coordinate hints
// cover both kinds: an import's hint carries module_import_hint and its
// position in `imports`, and the import remembers its target binding's index.
const module_import_hint = u32(0x800000)

fn (environment &ModuleEnvironment) hinted_binding_matches(index u32, name &Utf16String) bool {
	if index & module_import_hint == 0 {
		return environment.DeclarativeEnvironment.hinted_binding_matches(int(index), name)
	}
	position := int(index & (binding_hint_index_mask & ~module_import_hint))
	if position >= environment.imports.len { return false }
	import_name := unsafe { &environment.imports[position].name }
	return import_name.data.len == name.data.len
		&& (import_name.data.data == name.data.data || utf16_equals(import_name.data, name.data))
}

// GetBindingValue for a binding hinted_binding_matches() confirmed.
fn (mut environment ModuleEnvironment) hinted_binding_value(mut vm VM, index u32) !Value {
	if index & module_import_hint == 0 {
		return environment.DeclarativeEnvironment.get_binding_value_direct(mut vm, int(index))
	}
	return environment.import_value(mut vm, int(index & (binding_hint_index_mask & ~module_import_hint)))
}

// GetBindingValue of an indirect binding reads the target module's binding,
// whose position the import keeps once found.
fn (mut environment ModuleEnvironment) import_value(mut vm VM, position int) !Value {
	binding := unsafe { &environment.imports[position] }
	mut target := binding.target.module_environment or {
		return vm.throw_error(.reference_error, 'Imported module has no environment')
	}
	cached := binding.target_index
	if cached >= 0 && target.DeclarativeEnvironment.hinted_binding_matches(cached, &binding.target_name) {
		return target.DeclarativeEnvironment.get_binding_value_direct(mut vm, cached)
	}
	index := target.DeclarativeEnvironment.find_binding_index(binding.target_name)
	if index >= 0 {
		environment.imports[position].target_index = index
		return target.DeclarativeEnvironment.get_binding_value_direct(mut vm, index)
	}
	return target.get_binding_value(mut vm, binding.target_name, true)
}
