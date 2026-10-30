module platform

#flag darwin -framework CoreFoundation
#include "hyphenation_bridge.h"

fn C.libweb_v_hyphen_locations(text &u16, length i32, language &char, locations &i32, capacity i32) i32

// Return dictionary break positions in ascending UTF-16 order. Unsupported
// locales/platforms deliberately contribute no automatic break opportunities.
pub fn hyphenation_locations(text []u16, language string) []int {
	if text.len < 5 || text.len > 2147483647 || language == '' { return []int{} }
	mut locations := []i32{len: text.len}
	count := int(C.libweb_v_hyphen_locations(text.data, i32(text.len), language.str,
		locations.data, i32(locations.len)))
	if count <= 0 || count > locations.len { return []int{} }
	mut result := []int{cap: count}
	for index := count - 1; index >= 0; index-- { result << int(locations[index]) }
	return result
}
