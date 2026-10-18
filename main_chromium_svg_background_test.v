module main
import painting

fn test_svg_background_container_rounding_is_independent_of_tile_origin() {
 replay := chromium_svg_background_replay(painting.Rect{51.453125,241.640625,17.1,17.1}, [f64(1),0,0,1,0,0]!)
 assert replay.viewport_width == 17
 assert replay.viewport_height == 17
 assert replay.transform == [f64(1),0,0,1,51,242]!
 second := chromium_svg_background_replay(painting.Rect{51,241,17.1,17.1}, [f64(1),0,0,1,0,0]!)
 assert second.viewport_width == replay.viewport_width
 assert second.transform[0] == replay.transform[0]
}

fn test_svg_background_replay_composes_outer_transform_and_negative_ties() {
 replay := chromium_svg_background_replay(painting.Rect{-.5,-1.5,16,20},[f64(2),0,0,3,11,13]!)
 assert replay.viewport_width == 16 && replay.viewport_height == 20
 assert replay.transform == [f64(2),0,0,3,11,10]!
}
