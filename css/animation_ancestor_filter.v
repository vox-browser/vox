module css

import dom
import os

const disable_animation_ancestor_seeding = os.getenv('VOX_DISABLE_ANIMATION_ANCESTOR_SEEDING') != ''

// Include the target for descendant cascades, and cross a shadow root through
// its host just as the ordinary shadow-including style traversal does. Extra
// hashes can only admit candidates; selector matching still enforces scope.
fn (mut computer StyleComputer) push_animation_recompute_ancestors(target dom.AbstractElement) []&dom.Element {
	mut ancestors := []&dom.Element{}
	if disable_animation_ancestor_seeding { return ancestors }
	mut current := ?&dom.Element(target.element())
	for current != none {
		ancestor := current or { break }
		ancestors << ancestor
		computer.push_ancestor(ancestor)
		current = ancestor.as_node().parent_or_shadow_host_element()
	}
	return ancestors
}
