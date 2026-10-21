module css

import platform

// Counter inheritance and operations repeatedly copy and grow their working
// set. Only its final vector is published to the layout tree. Own its names
// and creator descriptions too: V's record copies can copy those strings
// into the workspace even when the original operation's input was retained.
fn resolve_retained_counter_state(element CounterElement) ?CountersSet {
	$if prealloc {
		mut scratch := platform.begin_thread_scratch('counter resolution')
		resolved := resolve_counters(element).counters_set
		scratch.leave()
		defer { scratch.finish() }
		if counters := resolved {
			mut final := []Counter{cap: counters.counters_.len}
			for counter in counters.counters_ {
				final << Counter{
					...counter
					name: counter.name.clone()
					originating_element: CounterOriginatingElement{
						...counter.originating_element
						debug_description: counter.originating_element.debug_description.clone()
					}
				}
			}
			return CountersSet{counters_: final}
		}
		return none
	}
	return resolve_counters(element).counters_set
}
