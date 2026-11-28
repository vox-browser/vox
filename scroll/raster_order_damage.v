module main

import os

// Experimental, off by default: VOX_PAINT_ORDER_DAMAGE=1 damages reordered
// commands instead of replaying the whole viewport.
//
// The diff matches each command with an identical one of the retained frame.
// A command matched earlier in paint order than one before it makes the frame
// irreconcilable. With this switch it is treated as changed instead: its
// retained copy stays unmatched and is damaged where it was, the current one
// where it is. On the archived github.com/vlang/v page this left stale pixels
// (e2463b19b, 23e225131, both reverted); the switch keeps the path available
// for diagnosis with VOX_SCROLL_RASTER_DAMAGE_DIAGNOSTICS.
const paint_order_damage_enabled = os.getenv('VOX_PAINT_ORDER_DAMAGE') != ''
