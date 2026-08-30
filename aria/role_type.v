// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/ARIA/RoleType.{h,cpp} and the generated
// AriaRoles classes. The generated classes are represented by one typed,
// data-driven RoleType backed by the same upstream AriaRoles.json metadata.
module aria

import strconv
import x.json2

pub enum NameFromSource {
	author
	content
	author_content
	prohibited
}

struct RawRoleDefinition {
	name                        string
	supported_states            []StateAndProperty
	supported_properties        []StateAndProperty
	required_states             []StateAndProperty
	required_properties         []StateAndProperty
	prohibited_states           []StateAndProperty
	prohibited_properties       []StateAndProperty
	required_context_roles      []Role
	required_owned_elements     []Role
	name_from_source            NameFromSource
	accessible_name_required    bool
	children_are_presentational bool
	implicit_values             map[StateAndProperty]DefaultValue
}

@[heap]
pub struct RoleType {
pub:
	role Role
mut:
	data_       AriaData
	definition_ RawRoleDefinition
}

fn json_object(value json2.Any) !map[string]json2.Any {
	if value !is map[string]json2.Any {
		return error('ARIA role metadata entry is not an object')
	}
	return value as map[string]json2.Any
}

fn json_string(object map[string]json2.Any, key string) string {
	value := object[key] or { return '' }
	return if value is string { value } else { '' }
}

fn json_bool(object map[string]json2.Any, key string) bool {
	value := object[key] or { return false }
	return if value is bool { value } else { false }
}

fn json_string_array(object map[string]json2.Any, key string) []string {
	value := object[key] or { return []string{} }
	if value !is []json2.Any {
		return []string{}
	}
	mut result := []string{}
	for item in value as []json2.Any {
		if item is string {
			result << item
		}
	}
	return result
}

fn metadata_state_list(object map[string]json2.Any, key string) []StateAndProperty {
	mut result := []StateAndProperty{}
	for name in json_string_array(object, key) {
		if value := state_or_property_from_string(name) {
			result << value
		}
	}
	return result
}

fn metadata_role_list(object map[string]json2.Any, key string) []Role {
	mut result := []Role{}
	for name in json_string_array(object, key) {
		if role := role_from_string(name) {
			result << role
		}
	}
	return result
}

fn parse_name_from_source(value string) NameFromSource {
	return match value {
		'Content' { .content }
		'AuthorContent' { .author_content }
		'Prohibited' { .prohibited }
		else { .author }
	}
}

fn parse_implicit_default(value string) DefaultValue {
	return match value {
		'true' {
			DefaultValue(true)
		}
		'false' {
			DefaultValue(false)
		}
		'AriaOrientation::Horizontal' {
			DefaultValue(AriaOrientation.horizontal)
		}
		'AriaOrientation::Undefined' {
			DefaultValue(AriaOrientation.undefined)
		}
		'AriaOrientation::Vertical' {
			DefaultValue(AriaOrientation.vertical)
		}
		'AriaLive::Assertive' {
			DefaultValue(AriaLive.assertive)
		}
		'AriaLive::Off' {
			DefaultValue(AriaLive.off)
		}
		'AriaLive::Polite' {
			DefaultValue(AriaLive.polite)
		}
		'AriaHasPopup::False' {
			DefaultValue(AriaHasPopup.false_)
		}
		'AriaHasPopup::True' {
			DefaultValue(AriaHasPopup.true_)
		}
		'AriaHasPopup::Menu' {
			DefaultValue(AriaHasPopup.menu)
		}
		'AriaHasPopup::Listbox' {
			DefaultValue(AriaHasPopup.listbox)
		}
		'AriaHasPopup::Tree' {
			DefaultValue(AriaHasPopup.tree)
		}
		'AriaHasPopup::Grid' {
			DefaultValue(AriaHasPopup.grid)
		}
		'AriaHasPopup::Dialog' {
			DefaultValue(AriaHasPopup.dialog)
		}
		else {
			DefaultValue(strconv.atof64(value) or { return DefaultValue(NoDefault{}) })
		}
	}
}

fn raw_role_definition(name string, object map[string]json2.Any) RawRoleDefinition {
	mut implicit_values := map[StateAndProperty]DefaultValue{}
	if raw_implicit := object['implicitValueForRole'] {
		if raw_implicit is map[string]json2.Any {
			for attribute, raw_value in raw_implicit {
				state := state_or_property_from_string(attribute) or { continue }
				if raw_value is string {
					implicit_values[state] = parse_implicit_default(raw_value)
				}
			}
		}
	}
	return RawRoleDefinition{
		name:                        name
		supported_states:            metadata_state_list(object, 'supportedStates')
		supported_properties:        metadata_state_list(object, 'supportedProperties')
		required_states:             metadata_state_list(object, 'requiredStates')
		required_properties:         metadata_state_list(object, 'requiredProperties')
		prohibited_states:           metadata_state_list(object, 'prohibitedStates')
		prohibited_properties:       metadata_state_list(object, 'prohibitedProperties')
		required_context_roles:      metadata_role_list(object, 'requiredContextRoles')
		required_owned_elements:     metadata_role_list(object, 'requiredOwnedElements')
		name_from_source:            parse_name_from_source(json_string(object, 'nameFromSource'))
		accessible_name_required:    json_bool(object, 'accessibleNameRequired')
		children_are_presentational: json_bool(object, 'childrenArePresentational')
		implicit_values:             implicit_values
	}
}

fn role_definition_key(role Role, focusable bool, definitions map[string]json2.Any) ?string {
	return match role {
		.image, .img {
			'Img'
		}
		.insertion {
			'Insertion'
		}
		.none_, .presentation {
			'Presentation'
		}
		.separator {
			if focusable {
				'FocusableSeparator'
			} else {
				'NonFocusableSeparator'
			}
		}
		else {
			fragment := '#${role_name(role)}'
			mut found := ?string(none)
			for key, raw_definition in definitions {
				object := json_object(raw_definition) or { continue }
				if json_string(object, 'specLink').ends_with(fragment) {
					found = key
					break
				}
			}
			found
		}
	}
}

pub fn build_role_object(role Role, focusable bool, data AriaData) !&RoleType {
	return RoleType.build_role_object(role, focusable, data)
}

pub fn RoleType.build_role_object(role Role, focusable bool, data AriaData) !&RoleType {
	if is_abstract_role(role) {
		return error('Cannot construct a role object for an abstract role.')
	}
	decoded := json2.decode[json2.Any]($embed_file('aria_roles.json').to_string())!
	definitions := json_object(decoded)!
	key := role_definition_key(role, focusable, definitions) or {
		return error('Missing generated metadata for ARIA role ${role_name(role)}')
	}
	object := json_object(definitions[key] or {
		return error('Missing generated metadata object ${key}')
	})!
	return &RoleType{
		role:        role
		data_:       data
		definition_: raw_role_definition(key, object)
	}
}

pub fn (role_type &RoleType) supported_states() []StateAndProperty {
	return role_type.definition_.supported_states.clone()
}

pub fn (role_type &RoleType) supported_properties() []StateAndProperty {
	return role_type.definition_.supported_properties.clone()
}

pub fn (role_type &RoleType) required_states() []StateAndProperty {
	return role_type.definition_.required_states.clone()
}

pub fn (role_type &RoleType) required_properties() []StateAndProperty {
	return role_type.definition_.required_properties.clone()
}

pub fn (role_type &RoleType) prohibited_states() []StateAndProperty {
	return role_type.definition_.prohibited_states.clone()
}

pub fn (role_type &RoleType) prohibited_properties() []StateAndProperty {
	return role_type.definition_.prohibited_properties.clone()
}

pub fn (role_type &RoleType) required_context_roles() []Role {
	return role_type.definition_.required_context_roles.clone()
}

pub fn (role_type &RoleType) required_owned_elements() []Role {
	return role_type.definition_.required_owned_elements.clone()
}

pub fn (role_type &RoleType) name_from_source() NameFromSource {
	return role_type.definition_.name_from_source
}

pub fn (role_type &RoleType) accessible_name_required() bool {
	return role_type.definition_.accessible_name_required
}

pub fn (role_type &RoleType) children_are_presentational() bool {
	return role_type.definition_.children_are_presentational
}

pub fn (role_type &RoleType) default_value_for_property_or_state(value StateAndProperty) DefaultValue {
	return role_type.definition_.implicit_values[value] or { DefaultValue(NoDefault{}) }
}

fn role_type_values(role_type &RoleType, values []StateAndProperty) map[string]string {
	mut result := map[string]string{}
	for value in values {
		result[state_or_property_to_string(value)] = state_or_property_to_string_value(value,
			&role_type.data_, role_type.default_value_for_property_or_state(value))
	}
	return result
}

pub fn (role_type &RoleType) serialize_as_json() string {
	mut object := map[string]json2.Any{}
	for name, values in {
		'state':                 role_type_values(role_type, role_type.supported_states())
		'properties':            role_type_values(role_type, role_type.supported_properties())
		'required_state':        role_type_values(role_type, role_type.required_states())
		'required_properties':   role_type_values(role_type, role_type.required_properties())
		'prohibited_state':      role_type_values(role_type, role_type.prohibited_states())
		'prohibited_properties': role_type_values(role_type, role_type.prohibited_properties())
	} {
		mut encoded_values := map[string]json2.Any{}
		for key, value in values {
			encoded_values[key] = value
		}
		object[name] = encoded_values
	}
	return json2.Any(object).json_str()
}
