module dom

// The document owns the native factory; its scripting host supplies the actual
// ECMAScript Construct operation without introducing a DOM -> engine import.
pub struct CustomElementConstructionHook {
pub:
	target voidptr
	construct fn (voidptr, &CustomElementDefinition, voidptr) !&Element = unsafe { nil }
	report fn (voidptr, IError) = unsafe { nil }
	// Upgrade steps 7-9.4: construct the definition's constructor while the
	// existing element is on its construction stack.
	upgrade fn (voidptr, &Element, &CustomElementDefinition) ! = unsafe { nil }
	// Invoke a lifecycle callback reaction with the element as this value.
	invoke fn (voidptr, &Element, CustomElementCallbackReaction) ! = unsafe { nil }
}

pub fn (mut document Document) set_custom_element_construction_hook(hook ?CustomElementConstructionHook) {
	document.custom_element_construction_hook_ = hook
}

pub fn (mut document Document) clear_custom_element_construction_hook(owner voidptr) {
	if hook := document.custom_element_construction_hook_ {
		if hook.target == owner { document.custom_element_construction_hook_ = none }
	}
}

fn validate_html_constructor_interface(definition &CustomElementDefinition, interface_name string) ! {
	if definition.local_name() == definition.name() {
		if interface_name != 'HTMLElement' { return error('TypeError: Autonomous custom elements must inherit from HTMLElement') }
	} else if definition.local_name() !in valid_local_names_for_given_html_element_interface(interface_name) {
		return error('TypeError: Custom element local name does not match its HTML interface')
	}
}

pub fn html_constructor_is_upgrading(definition &CustomElementDefinition) bool {
	return definition.construction_stack.len != 0
}

// HTMLConstructor steps 10-13 for an element being upgraded. The caller sets
// the wrapper's prototype (step 12) and returns that existing wrapper.
pub fn take_html_constructor_upgrade_element(definition &CustomElementDefinition, interface_name string) !&Element {
	validate_html_constructor_interface(definition, interface_name)!
	if definition.construction_stack.len == 0 {
		return error('TypeError: No element is being upgraded')
	}
	// 10. Let element be the last entry in definition's construction stack.
	element := definition.construction_stack.last()
	// 11. If element is an already constructed marker, then throw a TypeError.
	if element == unsafe { nil } {
		return error('TypeError: Custom element constructor already constructed this element')
	}
	// 13. Replace the last entry in definition's construction stack with an
	//     already constructed marker.
	mut stack_owner := unsafe { &CustomElementDefinition(definition) }
	stack_owner.construction_stack[stack_owner.construction_stack.len - 1] = unsafe { nil }
	return element
}

// HTMLConstructor, empty construction-stack branch. Existing-element upgrades
// use take_html_constructor_upgrade_element and keep their native owner.
pub fn create_element_for_html_constructor(document &Document, definition &CustomElementDefinition, registry voidptr, interface_name string) !&Element {
	validate_html_constructor_interface(definition, interface_name)!
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

pub fn (d &Document) has_pending_custom_element_reactions() bool {
	return d.custom_element_reaction_backup_queue.len != 0
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#invoke-custom-element-reactions
// The compact script bridge has no per-operation [CEReactions] stack. It
// drains the backup element queue at its replay boundaries instead: after
// define(), after queued script writes reach the native tree, and after task
// replays. A nested request leaves newly queued elements to the active drain.
pub fn (mut d Document) invoke_custom_element_reactions() {
	if d.custom_element_reaction_backup_queue.len == 0 || d.invoking_custom_element_reactions {
		return
	}
	hook := d.custom_element_construction_hook_ or { return }
	if hook.upgrade == unsafe { nil } || hook.invoke == unsafe { nil } { return }
	d.invoking_custom_element_reactions = true
	defer { d.invoking_custom_element_reactions = false }
	for d.custom_element_reaction_backup_queue.len > 0 {
		mut element := d.custom_element_reaction_backup_queue[0]
		d.custom_element_reaction_backup_queue.delete(0)
		for {
			reactions := element.take_custom_element_reactions()
			if reactions.len == 0 { break }
			for reaction in reactions {
				match reaction {
					CustomElementUpgradeReaction {
						element.upgrade_element(reaction.custom_element_definition) or {
							hook.report(hook.target, err)
						}
					}
					CustomElementCallbackReaction {
						hook.invoke(hook.target, element, reaction) or { hook.report(hook.target, err) }
					}
				}
			}
		}
	}
	d.processing_custom_element_reaction_backup_queue = false
}
