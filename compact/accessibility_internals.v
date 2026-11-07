module main

import aria
import dom
import html
import x.json2

// Ladybird's test driver asks Internals for the accessible name and role of an
// element (Internals::get_computed_label/get_computed_role). Compute both with
// the translated accessible name computation and ARIA role resolution.
fn compact_accessibility_query(root &dom.Node, kind string) !string {
	element := root.as_element() or { return error('TypeError: Expected an Element') }
	match kind {
		'label' {
			// The accessible name is a flat string: collapse and trim white space.
			name := root.accessible_name(element.document(), .yes)!
			return json2.encode(name.fields().join(' '))
		}
		'role' {
			role := html.html_element_role_or_default(element) or { return json2.encode('') }
			return json2.encode(aria.role_name(role))
		}
		else {
			return error('Invalid accessibility query')
		}
	}
}

// Runs after window.internals exists.
fn compact_accessibility_internals_bootstrap() string {
	return r'
if(window.internals)for(const [name,kind] of [["getComputedLabel","label"],["getComputedRole","role"]])window.internals[name]=function(element){
 const state=__elementApply(__elementRecordGet,__elementRecords,[element]);
 if(!state)throw new TypeError(name+" requires an Element");
 return __queryElements(state.bridgeKey,"computedAccessibility",kind,true);
};
'
}
