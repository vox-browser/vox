module dom

// The document owns the native factory; its scripting host supplies the actual
// ECMAScript Construct operation without introducing a DOM -> engine import.
pub struct CustomElementConstructionHook {
pub:
	target voidptr
	construct fn (voidptr, &CustomElementDefinition, voidptr) !&Element = unsafe { nil }
	report fn (voidptr, IError) = unsafe { nil }
}

pub fn (mut document Document) set_custom_element_construction_hook(hook ?CustomElementConstructionHook) {
	document.custom_element_construction_hook_ = hook
}

pub fn (mut document Document) clear_custom_element_construction_hook(owner voidptr) {
	if hook := document.custom_element_construction_hook_ {
		if hook.target == owner { document.custom_element_construction_hook_ = none }
	}
}

// HTMLConstructor, empty construction-stack branch. Existing-element upgrades
// use a separate algorithm and must not allocate a replacement native owner.
pub fn create_element_for_html_constructor(document &Document, definition &CustomElementDefinition, registry voidptr, interface_name string) !&Element {
	if definition.local_name() == definition.name() {
		if interface_name != 'HTMLElement' { return error('TypeError: Autonomous custom elements must inherit from HTMLElement') }
	} else if definition.local_name() !in valid_local_names_for_given_html_element_interface(interface_name) {
		return error('TypeError: Custom element local name does not match its HTML interface')
	}
	if definition.construction_stack().len != 0 {
		return error('TypeError: Existing-element construction requires an upgrade construction stack')
	}
	is_value := if definition.name() == definition.local_name() { ?string(none) } else { ?string(definition.name()) }
	mut element := create_element_internal(document, definition.local_name(), namespace_html_, none, .custom, is_value, registry)
	element.setup_custom_element_from_constructor(definition, is_value)
	return element
}

fn validate_constructed_custom_element(element &Element, document &Document, local_name string) ! {
	if !element.is_html_element() { return error('TypeError: Custom element constructor must return an HTMLElement') }
	if element.has_attributes() || element.as_node().has_child_nodes() || element.as_node().parent() != none {
		return error('NotSupportedError: Newly constructed custom element has attributes, children, or a parent')
	}
	if voidptr(element.document()) != voidptr(document) || (element.namespace_uri() or { '' }) != namespace_html_ || element.local_name() != local_name {
		return error('NotSupportedError: Custom element constructor returned an element with a different document, namespace, or local name')
	}
}

fn create_failed_custom_element(document &Document, local_name string, prefix ?string, registry voidptr) &Element {
	mut element := unsafe { &Element(&HTMLUnknownElement{
		HTMLElement: new_html_element_storage(document, QualifiedName{
			local_name: local_name
			prefix_: prefix
			namespace_: namespace_html_
			lowercased_local_name: to_ascii_lowercase(local_name)
		})
	}) }
	assign_unique_node_id(element)
	element.set_custom_element_state(.failed)
	element.set_custom_element_registry(registry)
	return element
}

fn construct_custom_element_synchronously(document &Document, definition &CustomElementDefinition, prefix ?string, registry voidptr, hook CustomElementConstructionHook) &Element {
	mut element := hook.construct(hook.target, definition, registry) or {
		hook.report(hook.target, err)
		return create_failed_custom_element(document, definition.local_name(), prefix, registry)
	}
	validate_constructed_custom_element(element, document, definition.local_name()) or {
		hook.report(hook.target, err)
		return create_failed_custom_element(document, definition.local_name(), prefix, registry)
	}
	element.set_prefix(prefix)
	return element
}
