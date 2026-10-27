/*
 * Copyright (c) 2025, Sam Atkins <sam@ladybird.org>
 *
 * SPDX-License-Identifier: BSD-2-Clause
 */

// Translated from:
// - Libraries/LibWeb/CSS/CSSUnparsedValue.cpp/.h
// - Libraries/LibWeb/CSS/CSSVariableReferenceValue.cpp/.h
module css

import strings

pub type CSSUnparsedSegment = CSSVariableReferenceValue | string

// Local stand-in for the JS::Value conversion used by CSSUnparsedValue's indexed setters.
pub type CSSUnparsedIndexedValue = CSSVariableReferenceValue | string

// https://drafts.css-houdini.org/css-typed-om-1/#cssunparsedvalue
@[heap]
pub struct CSSUnparsedValue {
pub mut:
	// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssunparsedvalue-tokens-slot
	// They have a [[tokens]] internal slot, which is a list of USVStrings and CSSVariableReferenceValue objects.
	// This list is the object's values to iterate over.
	tokens []CSSUnparsedSegment
}

pub fn CSSUnparsedValue.create(value []CSSUnparsedSegment) &CSSUnparsedValue {
	// NB: The C++ implementation converts GC::Roots into GC::Refs here. The V port has no GC root wrapper,
	// so the supplied segments are already in the representation stored by [[tokens]].
	return &CSSUnparsedValue{
		tokens: value
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssunparsedvalue-cssunparsedvalue
pub fn CSSUnparsedValue.construct_impl(value []CSSUnparsedSegment) !&CSSUnparsedValue {
	// AD-HOC: There is no spec for this, see https://github.com/w3c/css-houdini-drafts/issues/1146

	return CSSUnparsedValue.create(value)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssunparsedvalue-length
pub fn (value &CSSUnparsedValue) length() u32 {
	// The length attribute returns the size of the [[tokens]] internal slot.
	return u32(value.tokens.len)
}

// https://drafts.css-houdini.org/css-typed-om-1/#ref-for-dfn-determine-the-value-of-an-indexed-property
pub fn (value &CSSUnparsedValue) item_value(index uint) ?CSSUnparsedSegment {
	// To determine the value of an indexed property of a CSSUnparsedValue this and an index n, let tokens be this's
	// [[tokens]] internal slot, and return tokens[n].
	if index >= value.tokens.len {
		return none
	}
	return value.tokens[index]
}

fn unparsed_segment_from_indexed_value(value CSSUnparsedIndexedValue) !CSSUnparsedSegment {
	match value {
		CSSVariableReferenceValue {
			return CSSUnparsedSegment(value)
		}
		string {
			return CSSUnparsedSegment(value)
		}
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#ref-for-dfn-set-the-value-of-an-existing-indexed-property
pub fn (mut value CSSUnparsedValue) set_value_of_existing_indexed_property(n u32, new_value CSSUnparsedIndexedValue) ! {
	// To set the value of an existing indexed property of a CSSUnparsedValue this, an index n, and a value new value,
	// let tokens be this's [[tokens]] internal slot, and set tokens[n] to new value.
	value.tokens[int(n)] = unparsed_segment_from_indexed_value(new_value)!
}

// https://drafts.css-houdini.org/css-typed-om-1/#ref-for-dfn-set-the-value-of-a-new-indexed-property
pub fn (mut value CSSUnparsedValue) set_value_of_new_indexed_property(n u32, new_value CSSUnparsedIndexedValue) ! {
	// To set the value of a new indexed property of a CSSUnparsedValue this, an index n, and a value new value,
	// let tokens be this's [[tokens]] internal slot. If n is not equal to the size of tokens, throw a RangeError.
	// Otherwise, append new value to tokens.
	if int(n) != value.tokens.len {
		return error('Index out of range')
	}

	value.tokens << unparsed_segment_from_indexed_value(new_value)!
}

fn (value &CSSUnparsedValue) contains_unparsed_value(needle &CSSUnparsedValue) bool {
	for unparsed_segment in value.tokens {
		match unparsed_segment {
			CSSVariableReferenceValue {
				fallback := unparsed_segment.fallback()
				if fallback == none {
					continue
				}
				fallback_value := fallback or { continue }
				if fallback_value == needle {
					return true
				}
				if fallback_value.contains_unparsed_value(needle) {
					return true
				}
			}
			string {}
		}
	}
	return false
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssunparsedvalue
pub fn (value &CSSUnparsedValue) to_string() !string {
	// AD-HOC: It's possible for one of the m_tokens to contain this in its fallback slot, or a similar situation with
	//         more levels of nesting. To avoid crashing, do a scan for that first and return the empty string.
	// Spec issue: https://github.com/w3c/css-houdini-drafts/issues/1158
	if value.contains_unparsed_value(value) {
		return ''
	}

	// To serialize a CSSUnparsedValue this:
	// 1. Let s initially be the empty string.
	mut s := strings.new_builder(16)

	// 2. For each item in this's [[tokens]] internal slot:
	for item in value.tokens {
		// FIXME: In order to match the expected test behaviour, this should insert comments, with the same rules as
		//        serialize_a_series_of_component_values(). See https://github.com/w3c/css-houdini-drafts/issues/1148
		match item {
			// 1. If item is a USVString, append it to s.
			string {
				s.write_string(item)
			}
			// 2. Otherwise, item is a CSSVariableReferenceValue. Serialize it, then append the result to s.
			CSSVariableReferenceValue {
				s.write_string(item.to_string()!)
			}
		}
	}

	// 3. Return s.
	return s.str()
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (value &CSSUnparsedValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	_ = property
	_ = perform_type_check
	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	//
	//     If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	//
	//     Return the value.

	// https://drafts.css-houdini.org/css-typed-om-1/#cssstylevalue-match-a-grammar
	// A CSSUnparsedValue matches any grammar.

	// NB: CSSUnparsedValue stores a list of strings, each of which may contain any number of tokens. So the simplest
	//     way to convert it to ComponentValues is to serialize and then parse it.
	string_value := value.to_string()!
	component_values := parse_as_list_of_component_values_for_unparsed_value(string_value)
	mut substitution_presence := SubstitutionFunctionsPresence{}
	collect_arbitrary_substitution_function_presence(component_values, mut substitution_presence) or {
		return error('TypeError: Invalid arbitrary substitution function syntax')
	}
	return StyleValue(UnresolvedStyleValue.create_with_presence(component_values, substitution_presence, none))
}

fn parse_as_list_of_component_values_for_unparsed_value(value string) []ComponentValue {
	return parse_component_values_for_value_logic(value)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssvariablereferencevalue
fn reify_a_var_reference(function Function) ?CSSVariableReferenceValue {
	arguments := parse_according_to_argument_grammar(.var_, function.value) or { return none }
	if arguments !is DeclarationValueList {
		return none
	}
	declaration_values := arguments as DeclarationValueList

	mut name_tokens := ParserTokenStream.from_values(declaration_values.first())
	name_tokens.discard_whitespace()
	name_token := name_tokens.consume_a_token()
	name_tokens.discard_whitespace()
	if name_tokens.has_next_token() || !name_token.is(.ident)
		|| !is_a_custom_property_name_string(name_token.token().ident()) {
		return none
	}

	mut fallback := ?&CSSUnparsedValue(none)
	if fallback_values := declaration_values.get(1) {
		fallback = reify_a_list_of_component_values(fallback_values)
	}
	return CSSVariableReferenceValue.create(name_token.token().ident(), fallback)
}

fn flush_unserialized_component_values(mut unserialized []ComponentValue, mut reified []CSSUnparsedSegment) {
	if unserialized.len == 0 {
		return
	}
	reified << CSSUnparsedSegment(serialize_a_series_of_component_values(unserialized))
	unserialized.clear()
}

fn reify_component_values(source_values []ComponentValue, mut unserialized []ComponentValue, mut reified []CSSUnparsedSegment) {
	for component_value in source_values {
		if component_value.is_function_named('var') {
			if variable_reference := reify_a_var_reference(component_value.function()) {
				flush_unserialized_component_values(mut unserialized, mut reified)
				reified << CSSUnparsedSegment(variable_reference)
				continue
			}
		}

		if component_value.is_function() {
			function := component_value.function()
			unserialized << ComponentValue.from_token(function.name_token)
			reify_component_values(function.value, mut unserialized, mut reified)
			unserialized << ComponentValue.from_token(function.end_token)
			continue
		}

		if component_value.is_block() {
			block := component_value.block()
			unserialized << ComponentValue.from_token(block.token)
			reify_component_values(block.value, mut unserialized, mut reified)
			unserialized << ComponentValue.from_token(block.end_token)
			continue
		}

		unserialized << component_value
	}
}

fn reify_a_list_of_component_values(component_values []ComponentValue) &CSSUnparsedValue {
	mut unserialized := []ComponentValue{}
	mut reified := []CSSUnparsedSegment{}
	reify_component_values(component_values, mut unserialized, mut reified)
	flush_unserialized_component_values(mut unserialized, mut reified)
	return CSSUnparsedValue.create(reified)
}

pub fn (style_value UnresolvedStyleValue) reify(associated_property string) &CSSUnparsedValue {
	_ = associated_property
	return reify_a_list_of_component_values(style_value.tokens)
}

pub struct CSSVariableReferenceValue {
pub mut:
	variable_ string
	fallback_ ?&CSSUnparsedValue
}

pub fn CSSVariableReferenceValue.create(variable string, fallback ?&CSSUnparsedValue) CSSVariableReferenceValue {
	return CSSVariableReferenceValue{
		variable_: variable
		fallback_: fallback
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssvariablereferencevalue-cssvariablereferencevalue
pub fn CSSVariableReferenceValue.construct_impl(variable string, fallback ?&CSSUnparsedValue) !CSSVariableReferenceValue {
	// The CSSVariableReferenceValue(variable, fallback) constructor must, when called, perform the following steps:
	// 1. If variable is not a custom property name string, throw a TypeError.
	if !is_a_custom_property_name_string(variable) {
		return error("'${variable}' is not a valid CSS custom property name")
	}

	// 2. Return a new CSSVariableReferenceValue with its variable internal slot set to variable and its fallback internal slot set to fallback.
	return CSSVariableReferenceValue.create(variable, fallback)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssvariablereferencevalue-variable
pub fn (value CSSVariableReferenceValue) variable() string {
	// The getter for the variable attribute of a CSSVariableReferenceValue this must return its variable internal slot.
	return value.variable_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssvariablereferencevalue-variable
pub fn (mut value CSSVariableReferenceValue) set_variable(variable string) ! {
	// The variable attribute of a CSSVariableReferenceValue this must, on setting a variable variable, perform the following steps:
	// 1. If variable is not a custom property name string, throw a TypeError.
	if !is_a_custom_property_name_string(variable) {
		return error("'${variable}' is not a valid CSS custom property name")
	}

	// 2. Otherwise, set this's variable internal slot to variable.
	value.variable_ = variable
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssvariablereferencevalue-fallback
pub fn (value CSSVariableReferenceValue) fallback() ?&CSSUnparsedValue {
	// AD-HOC: No spec algorithm, see https://github.com/w3c/css-houdini-drafts/issues/1146#issuecomment-3188550133
	return value.fallback_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssvariablereferencevalue-fallback
pub fn (mut value CSSVariableReferenceValue) set_fallback(fallback ?&CSSUnparsedValue) ! {
	// AD-HOC: No spec algorithm, see https://github.com/w3c/css-houdini-drafts/issues/1146#issuecomment-3188550133
	value.fallback_ = fallback
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssvariablereferencevalue
pub fn (value CSSVariableReferenceValue) to_string() !string {
	// To serialize a CSSVariableReferenceValue this:
	// 1. Let s initially be "var(".
	mut s := strings.new_builder(16)
	s.write_string('var(')

	// 2. Append this's variable internal slot to s.
	s.write_string(value.variable_)

	// 3. If this's fallback internal slot is not null, append ", " to s, then serialize the fallback internal slot and append it to s.
	if fallback := value.fallback_ {
		// AD-HOC: Tested behaviour requires we append "," without the space. https://github.com/w3c/css-houdini-drafts/issues/1148
		s.write_string(',')
		s.write_string(fallback.to_string()!)
	}

	// 4. Append ")" to s and return s.
	s.write_string(')')
	return s.str()
}
