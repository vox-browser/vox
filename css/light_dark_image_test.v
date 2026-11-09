module css

fn test_light_dark_images_resolve_scheme_and_preserve_transparent_layers() {
 value := parse_css_value_logic(.background_image,'light-dark(none, linear-gradient(red, blue))') or { panic('image') }
 assert value.serialize(.normal) == 'light-dark(none, linear-gradient(red, blue))'
 assert value.absolutized(ComputationContext{color_scheme:PreferredColorScheme.light}).serialize(.resolved_value) == 'image(rgba(0, 0, 0, 0))'
 assert value.absolutized(ComputationContext{color_scheme:PreferredColorScheme.dark}).serialize(.resolved_value) == 'linear-gradient(rgb(255, 0, 0), rgb(0, 0, 255))'
 assert parse_css_value_logic(.background_image,'light-dark(red, url(dark.png))') == none
 assert parse_css_value_logic(.color,'light-dark(url(light.png), none)') == none
 assert parse_css_value_logic(.background_image,'image-set(light-dark(url(a),url(b)) 1x)') != none
 assert parse_css_value_logic(.background_image,'image-set(light-dark(image-set(url(a) 1x),url(b)) 1x)') == none
}

fn test_generated_content_resolves_image_color_scheme() {
 value := parse_css_value_logic(.content,'light-dark(url(light.png),url(dark.png))') or { panic('content') }
 assert value.absolutized(ComputationContext{color_scheme:PreferredColorScheme.dark}).serialize(.resolved_value) == 'url("dark.png")'
}
