module main

import os

// Same-binary control: replay the whole viewport whenever the paint order of
// matched commands changes, as before.
//
// The diff matches each command with an identical one of the retained frame.
// A command matched earlier in paint order than one before it used to make
// the frame irreconcilable. Treat it as changed instead: its retained copy
// stays unmatched and is damaged where it was, the current one where it is.
// For each pair whose order flipped, one of the two is damaged in this way,
// and where they overlap its ink covers the overlap, so the clipped replay
// paints those pixels in the new order. A large reordering exceeds the
// damage limit and still replays completely.
const retain_paint_order_fallback = os.getenv('VOX_RETAIN_PAINT_ORDER_FALLBACK') != ''
