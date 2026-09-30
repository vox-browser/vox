module libjs

fn test_initialize_host_defined_realm_pushes_a_context_with_a_global_environment() {
	mut vm := VM.create()
	context := create_simple_execution_context(mut vm)
	assert vm.has_running_execution_context()
	assert voidptr(vm.running_execution_context()) == voidptr(context)
	realm := vm.realm()
	assert voidptr(context.realm?) == voidptr(realm)
	assert context.script_or_module.is_empty()
	assert context.function == none
	global := vm.global_object()
	assert global.class_name == 'GlobalObject'
	assert voidptr(vm.get_global_object()) == voidptr(global)
	environment := realm.global_environment_record()
	assert voidptr(environment.object_record.binding_object) == voidptr(global)
	assert voidptr(environment.global_this_value) == voidptr(global)
	assert voidptr(vm.global_declarative_environment()) == voidptr(environment.declarative_record)
	assert vm.lexical_environment() == none
	assert vm.get_active_script_or_module().is_empty()
	roots := vm.heap_roots()
	assert roots.contains(voidptr(realm))
	assert roots.contains(voidptr(global)) == false
	assert vm.heap_roots().contains(voidptr(context.realm?))
}

fn test_host_hooks_supply_the_global_object_and_this_value() {
	mut vm := VM.create()
	initialize_host_defined_realm(mut vm, RealmGlobalHooks{
		create_global_object:     fn (realm &Realm) &Object {
			mut global := Object.create(realm, none)
			global.class_name = 'Window'
			return global
		}
		create_global_this_value: fn (realm &Realm) &Object {
			mut proxy := Object.create(realm, none)
			proxy.class_name = 'WindowProxy'
			return proxy
		}
	})!
	realm := vm.realm()
	assert vm.global_object().class_name == 'GlobalObject'
	assert realm.global_environment_record().global_this_value.class_name == 'WindowProxy'
	mut running := vm.running_execution_context()
	running.lexical_environment = Environment(realm.global_environment_record())
	this_value := vm.resolve_this_binding()!
	assert this_value.as_object().class_name == 'WindowProxy'
	mut host_defined := &RealmTestHostDefined{}
	mut standalone := Realm.create()
	standalone.host_defined = RealmHostDefined(host_defined)
	assert standalone.host_defined?.is_principal_host_defined()
	assert !standalone.host_defined?.is_synthetic_host_defined()
	assert realm.host_defined == none
	script := Script.parse('const answer = 42;', realm, 'answer.js', unsafe { nil })!
	assert script.filename == 'answer.js'
	assert !script.is_strict_mode
	assert voidptr(script.realm) == voidptr(realm)
	Script.parse('const = ;', realm, 'broken.js', unsafe { nil }) or {
		assert err is ScriptParseError
		assert err.msg().starts_with('SyntaxError: 1:')
		return
	}
	assert false, 'broken scripts must not parse'
}

@[heap]
struct RealmTestHostDefined {}

fn (host_defined &RealmTestHostDefined) is_principal_host_defined() bool {
	return true
}

fn (host_defined &RealmTestHostDefined) is_synthetic_host_defined() bool {
	return false
}
