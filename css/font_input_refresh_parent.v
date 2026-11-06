module css

import dom
import os

const retain_font_refresh_parent_lookups = os.getenv('VOX_RETAIN_FONT_REFRESH_PARENT_LOOKUPS') != ''
const font_refresh_parent_diagnostics = os.getenv('VOX_FONT_REFRESH_PARENT_DIAGNOSTICS') != ''

__global font_refresh_parent_reported bool

// The guard is synchronous and does not mutate styles or invoke script. Borrow
// its inheritance parent for this call only; each property still reads the live
// base store, including explicit inherit on normally non-inherited properties.
@[inline]
fn font_refresh_parent_value(id PropertyID, subject dom.AbstractElement,
	parent ?&ComputedProperties) &dom.StyleValue {
	if retain_font_refresh_parent_lookups {
		return StyleComputer.get_non_animated_inherit_value(id, subject)
	}
	if font_refresh_parent_diagnostics && !font_refresh_parent_reported && parent != none {
		font_refresh_parent_reported = true
		eprintln('Vox font refresh guard: reused synchronous parent lookup')
	}
	return non_animated_inherit_value_from_parent(id, parent)
}
