module main

import os

// Same-binary control: group end keys carry empty ink, as before.
//
// The retained-raster diff damages each unmatched command's ink. A group end
// carried empty ink on the assumption that its begin, whose ink is the
// group's extent, changes with it. On the archived github.com/vlang/v page
// effect-layer ends changed alone, so their change damaged nothing. An end
// now carries its group's extent; an unbounded group leaves it unbounded, so
// a change to it replays the viewport.
const retain_empty_group_end_ink = os.getenv('VOX_RETAIN_EMPTY_GROUP_END_INK') != ''
