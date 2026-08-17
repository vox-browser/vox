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

fn test_principal_and_synthetic_host_defined_keep_realm_state() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	window := html.WindowModel.create_top_level(document, none, 'main') or { panic(err) }
	mut realm := &html.ScriptingRealm{}
	settings := html.WindowEnvironmentSettingsObject.setup(window, document.url, mut realm, none,
		document.url, document.origin()).settings
	intrinsics := Intrinsics.create(realm)
	page := &dom.Page{}
	principal := PrincipalHostDefined.create(settings, intrinsics, page)
	assert principal.is_principal_host_defined()
	assert principal_host_defined_environment_settings_object(principal) == settings
	assert principal_host_defined_page(principal) == page
	assert host_defined_intrinsics(unsafe { &HostDefined(principal) }) == intrinsics

	synthetic_realm := &html.ScriptingRealm{}
	synthetic_settings := html.SyntheticRealmSettings{
		execution_context: unsafe { nil }
		principal_realm:   realm
		module_map:        html.ModuleMap.create()
	}
	synthetic := SyntheticHostDefined.create(synthetic_settings, Intrinsics.create(synthetic_realm))
	assert synthetic.is_synthetic_host_defined()
	assert synthetic.synthetic_realm_settings.principal_realm == realm
}
