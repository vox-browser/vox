// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/ContentFilter.{h,cpp}.
@[has_globals]
module loader

import dom

struct MatcherTransition {
	character  u8
	next_state u32
}

struct MatcherNode {
	first_transition u32
	transition_count u32
	output           bool
}

// AsciiStringMatcher is the compact trie used by Ladybird's URL content
// filter. It deliberately preserves the upstream scan's root fallback.
pub struct AsciiStringMatcher {
	nodes       []MatcherNode
	transitions []MatcherTransition
}

struct BuildNode {
mut:
	children []MatcherTransition
	output   bool
}

pub fn AsciiStringMatcher.create(patterns []string) !AsciiStringMatcher {
	mut build_nodes := [BuildNode{}]
	for pattern in patterns {
		for ch in pattern.bytes() {
			if ch > 0x7f {
				return error('content-filter patterns must contain ASCII bytes only')
			}
		}
		mut node := u32(0)
		for ch in pattern.bytes() {
			mut next := u32(0)
			mut found := false
			for transition in build_nodes[node].children {
				if transition.character == ch {
					next = transition.next_state
					found = true
					break
				}
			}
			if !found {
				next = u32(build_nodes.len)
				build_nodes << BuildNode{}
				build_nodes[node].children << MatcherTransition{ch, next}
			}
			node = next
		}
		build_nodes[node].output = true
	}

	// Compute inherited output flags exactly as the C++ build step does. The
	// Failure links are build-time state; the C++ runtime Node layout likewise
	// retains only transitions/output and restarts its scan from the root.
	mut failure_links := []u32{len: build_nodes.len}
	mut queue := []u32{}
	for transition in build_nodes[0].children {
		failure_links[transition.next_state] = 0
		queue << transition.next_state
	}
	mut cursor := 0
	for cursor < queue.len {
		current := queue[cursor]
		cursor++
		for transition in build_nodes[current].children {
			mut failure_link := failure_links[current]
			for failure_link != 0 {
				if candidate := child_for(build_nodes[failure_link].children, transition.character) {
					failure_link = candidate
					break
				}
				failure_link = failure_links[failure_link]
			}
			failure_links[transition.next_state] = failure_link
			if build_nodes[failure_link].output {
				build_nodes[transition.next_state].output = true
			}
			queue << transition.next_state
		}
	}

	mut nodes := []MatcherNode{len: build_nodes.len}
	mut transitions := []MatcherTransition{}
	for index, mut build_node in build_nodes {
		build_node.children.sort(a.character < b.character)
		nodes[index] = MatcherNode{
			first_transition: u32(transitions.len)
			transition_count: u32(build_node.children.len)
			output:           build_node.output
		}
		transitions << build_node.children
	}
	return AsciiStringMatcher{nodes, transitions}
}

fn child_for(children []MatcherTransition, character u8) ?u32 {
	for child in children {
		if child.character == character {
			return child.next_state
		}
	}
	return none
}

fn (matcher &AsciiStringMatcher) transition(state u32, character u8) ?MatcherTransition {
	node := matcher.nodes[state]
	mut low := int(node.first_transition)
	mut high := low + int(node.transition_count)
	for low < high {
		middle := low + (high - low) / 2
		candidate := matcher.transitions[middle]
		if candidate.character < character {
			low = middle + 1
		} else {
			high = middle
		}
	}
	if low < int(node.first_transition + node.transition_count)
		&& matcher.transitions[low].character == character {
		return matcher.transitions[low]
	}
	return none
}

pub fn (matcher &AsciiStringMatcher) contains(text string) bool {
	if matcher.nodes.len == 0 {
		return false
	}
	mut state := u32(0)
	for character in text.bytes() {
		mut found := matcher.transition(state, character)
		if found == none {
			state = 0
			found = matcher.transition(0, character)
			if found == none {
				continue
			}
		}
		transition := found or { continue }
		state = transition.next_state
		if matcher.nodes[state].output {
			return true
		}
	}
	return false
}

pub struct ContentFilter {
mut:
	filtering_enabled_ bool = true
	matcher            ?AsciiStringMatcher
}

pub fn ContentFilter.create() &ContentFilter {
	return &ContentFilter{}
}

pub fn ContentFilter.the() &ContentFilter {
	if loader_global_content_filter == unsafe { nil } {
		loader_global_content_filter = ContentFilter.create()
	}
	return loader_global_content_filter
}

pub fn (filter &ContentFilter) filtering_enabled() bool {
	return filter.filtering_enabled_
}

pub fn (mut filter ContentFilter) set_filtering_enabled(enabled bool) {
	filter.filtering_enabled_ = enabled
}

pub fn (mut filter ContentFilter) set_patterns(patterns []string) ! {
	filter.matcher = AsciiStringMatcher.create(patterns)!
}

pub fn (filter &ContentFilter) contains(text string) bool {
	matcher := filter.matcher or { return false }
	return matcher.contains(text)
}

pub fn (filter &ContentFilter) is_filtered(url dom.URL) bool {
	if !filter.filtering_enabled() || url.scheme() == 'data' {
		return false
	}
	return filter.contains(url.to_string())
}
