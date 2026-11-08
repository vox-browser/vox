module browserjs

import dom

// Compact realms supply their private Node identity transport. Records and
// filtering remain native DOM objects; JavaScript never reconstructs mutations.
pub type MutationObserverNodeResolver = fn (string) !&dom.Node
pub type MutationObserverRecordEncoder = fn ([]&dom.MutationRecord) !string

$if !darwin && !linux && !windows {
	pub fn (mut runtime Runtime) install_mutation_observer_binding(_ MutationObserverNodeResolver, _ MutationObserverRecordEncoder) ! {
		return error('Native MutationObserver binding requires JavaScriptCore')
	}
}
