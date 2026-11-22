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

// Same-binary control: group ends of equal kind and layer keep equal keys.
//
// Ends carried no identity of their group, so equal ends were
// interchangeable in the diff. When an animation ended on the archived
// github.com/vlang/v page, its effect layer's begin and end left the list,
// and the three header buttons' ends then matched the removed end out of
// paint order: the frame replayed completely instead of repainting the
// removed group's extent. An end's key now includes its begin's.
const retain_shared_group_end_keys = os.getenv('VOX_RETAIN_SHARED_GROUP_END_KEYS') != ''
