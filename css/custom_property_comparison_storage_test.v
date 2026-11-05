module css

import dom
import platform

fn test_repeated_custom_property_comparisons_do_not_retain_iteration_keys() {
	mut left := map[string]dom.CSSCustomProperty_{}
	mut right := map[string]dom.CSSCustomProperty_{}
	for index in 0 .. 128 {
		name := '--discord-theme-token-${index}'
		left[name] = dom.CSSCustomProperty_{
			value: &dom.CSSStyleValue_{css_text: 'rgb(10, 20, 30)'}
		}
		right[name] = dom.CSSCustomProperty_{
			value: &dom.CSSStyleValue_{css_text: 'rgb(10, 20, 30)'}
		}
	}
	assert custom_property_maps_equal(left, right)
	before := platform.thread_arena_usage().used
	mut equal := true
	for _ in 0 .. 128 {
		equal = custom_property_maps_equal(left, right) && equal
	}
	assert equal
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth < 4096, 'comparison retained ${growth} bytes'
	}
	// Comparisons must leave both maps and their values usable. Equal sizes
	// still require checking names, values and the important flag.
	right['--discord-theme-token-127'] = dom.CSSCustomProperty_{
		important: true
		value: &dom.CSSStyleValue_{css_text: 'rgb(10, 20, 30)'}
	}
	assert !custom_property_maps_equal(left, right)
	right.delete('--discord-theme-token-127')
	right['--different'] = left['--discord-theme-token-127']
	assert !custom_property_maps_equal(left, right)
	assert left.len == 128 && right.len == 128
}
