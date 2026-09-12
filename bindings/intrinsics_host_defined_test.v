module bindings

import dom
import html

fn intrinsic_test_behavior(arguments []dom.JSValue) !dom.JSValue {
	return if arguments.len == 0 { dom.js_undefined() } else { arguments[0] }
}

fn test_intrinsics_lazily_cache_names_prototypes_constructors_and_unforgeables() {
	realm := &html.ScriptingRealm{}
	mut intrinsics := Intrinsics.create(realm)
	namespace_1 := intrinsics.ensure_web_namespace('console')
	namespace_2 := intrinsics.ensure_web_namespace('console')
	assert namespace_1 == namespace_2
	prototype_1 := intrinsics.ensure_web_prototype('HTMLElement')
	prototype_2 := intrinsics.ensure_web_prototype('HTMLElement')
	assert prototype_1 == prototype_2
	constructor := intrinsics.ensure_web_constructor('HTMLElement')
	assert constructor.name == 'HTMLElement'
	assert intrinsics.namespace_count() == 1
	assert intrinsics.prototype_count() == 1
	assert intrinsics.constructor_count() == 1

	getter_1 := intrinsics.ensure_web_unforgeable_function('Window', 'document',
		intrinsic_test_behavior, .getter)
	getter_2 := intrinsics.ensure_web_unforgeable_function('Window', 'document',
		intrinsic_test_behavior, .getter)
	setter := intrinsics.ensure_web_unforgeable_function('Window', 'document',
		intrinsic_test_behavior, .setter)
	assert getter_1 == getter_2
	assert getter_1.length == 0
	assert setter.length == 1
	assert setter.prefix == 'set'
	assert intrinsics.unforgeable_function_count() == 2
	assert setter.call([dom.js_string('value')]) or { panic(err) }.string_data == 'value'
}

fn test_principal_and_internal_host_defined_keep_realm_state() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	window := html.WindowModel.create_top_level(document, none, 'main') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	settings := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none,
		document.url, document.origin()).settings
	intrinsics := Intrinsics.create(realm)
	page := &dom.Page{}
	principal := create_principal_host_defined(settings, intrinsics, page)
	assert principal.is_principal_host_defined()
	assert principal_host_defined_environment_settings_object(realm) == settings
	assert principal_host_defined_page(realm) == page
	assert host_defined_intrinsics(realm) == intrinsics
	assert host_defined_wrapper_world(realm).is_main_world()

	mut internal_realm := &html.ScriptingRealm{}
	internal_world := WrapperWorld.create(.internal)
	internal := HostDefined.create(Intrinsics.create(internal_realm), internal_world, realm, .no)
	install_host_defined(mut internal_realm, internal)
	assert host_defined_wrapper_world(internal_realm).type_() == .internal
	assert principal_host_defined_environment_settings_object(internal_realm) == settings
	assert principal_host_defined_page(internal_realm) == page
}
