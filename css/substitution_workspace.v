module css

import dom
import platform

fn resolve_property_in_substitution_workspace(element dom.AbstractElement, property_id PropertyID, unresolved UnresolvedStyleValue, mut guarded_contexts GuardedSubstitutionContexts) &dom.StyleValue {
	scratch := platform.begin_thread_scratch('CSS property substitution')
	mut temporary_contexts := GuardedSubstitutionContexts{}
	if scopes := guarded_contexts.function_definition_scopes {
		temporary_contexts.function_definition_scopes = scopes.clone()
	}
	mut result := substitute_arbitrary_substitution_functions_for_element(element,
		mut temporary_contexts, unresolved.tokens, SubstitutionContext{
			dependency_type: .property
			first:           string_from_property_id(property_id)
		})
	scratch.leave()
	defer { scratch.finish() }
	// Definition scopes belong to the document; the lookup table belongs to
	// the caller. Function-local caches remain entirely in the workspace.
	if scopes := temporary_contexts.function_definition_scopes {
		guarded_contexts.function_definition_scopes = scopes.clone()
	}
	own_value_component_text(mut result)
	return parse_substituted_property_value(property_id, result, true)
}
