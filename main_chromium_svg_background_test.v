module main
import painting

fn test_svg_background_container_rounding_is_independent_of_tile_origin() {
 replay := chromium_svg_background_replay(painting.Rect{51.453125,241.640625,17.1,17.1}, [f64(1),0,0,1,0,0]!)
 assert replay.viewport_width == 17
 assert replay.viewport_height == 17
 assert replay.transform == [f64(17)/17.09375,0,0,17/17.09375,51,242]!
 second := chromium_svg_background_replay(painting.Rect{51,241,17.1,17.1}, [f64(1),0,0,1,0,0]!)
 assert second.viewport_width == replay.viewport_width
 assert second.transform[0] == replay.transform[0]
}

fn test_svg_background_replay_composes_outer_transform_and_negative_ties() {
 replay := chromium_svg_background_replay(painting.Rect{-.5,-1.5,16,20},[f64(2),0,0,3,11,13]!)
 assert replay.viewport_width == 16 && replay.viewport_height == 20
 assert replay.transform == [f64(2),0,0,3,11,10]!
}

fn test_svg_background_keeps_fractional_layout_size_separate_from_rounded_recording() {
 replay := chromium_svg_background_replay(painting.Rect{33,22,146,22.123219241}, [f64(1),0,0,1,0,0]!)
 assert replay.viewport_width == 146
 assert replay.viewport_height == 22
 assert replay.layout_width == 146
 assert replay.layout_height == 22.109375
 assert replay.transform == [f64(1),0,0,22/22.109375,33,22]!
}

fn test_svg_background_fractional_container_preserves_both_axes_at_negative_origins() {
 replay := chromium_svg_background_replay(painting.Rect{-10.5,-20.5,146.49,22.51}, [f64(2),0,0,3,11,13]!)
 assert replay.viewport_width == 146
 assert replay.viewport_height == 23
 assert replay.layout_width == 146.484375
 assert replay.layout_height == 22.5
 assert replay.transform == [f64(2)*(146/146.484375),0,0,3*(23/22.5),-9,-47]!
}

fn test_fractional_svg_container_maps_to_the_rounded_image_area() {
 replay := chromium_svg_background_replay(painting.Rect{33,22,146,22.123219241}, [f64(1),0,0,1,0,0]!)
 assert replay.transform[0] * replay.layout_width == f64(replay.viewport_width)
 assert replay.transform[3] * replay.layout_height == f64(replay.viewport_height)
}
