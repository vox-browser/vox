module css

import dom
import platform

// Scratch pools retain capacity for the next style pass. Their reset scopes
// have no readers, so idle can discard physical pages without losing capacity.
pub fn trim_unused_computation_pages(document &dom.Document) {
	$if prealloc {
		if !platform.arena_thread_is_current() || document.style_computer == unsafe { nil }
			|| document.style_computer.css_handle == unsafe { nil } { return }
		computer := unsafe { &StyleComputer(document.style_computer.css_handle) }
		if computer.matching_rule_sets_ != unsafe { nil } && computer.matching_rule_sets_.depth == 0 {
			for arena in computer.matching_rule_sets_.arenas { arena.trim_empty_pages() }
		}
		if computer.cascade_scratch_ != unsafe { nil } && computer.cascade_scratch_.depth == 0 {
			for slot in computer.cascade_scratch_.slots { slot.arena.trim_empty_pages() }
		}
		if computer.computed_property_page_arena_ != unsafe { nil }
			&& computer.computed_property_page_batch_depth_ == 0 {
			computer.computed_property_page_arena_.trim_empty_pages()
		}
		fonts := computer.font_computer_
		if fonts != unsafe { nil } {
			if fonts.font_input_scratch_ != unsafe { nil } && fonts.font_input_scratch_.depth == 0 {
				for arena in fonts.font_input_scratch_.arenas { arena.trim_empty_pages() }
			}
			if fonts.font_key_scratch_ != unsafe { nil } { fonts.font_key_scratch_.trim_empty_pages() }
		}
	}
}
