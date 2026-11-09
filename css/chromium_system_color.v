module css

// Match the Chromium UA control defaults through system keywords, so author
// system colors and control colors follow the same color scheme.
fn chromium_system_color(keyword Keyword, scheme PreferredColorScheme) ?Color {
 return match keyword {
  .buttonborder { if scheme == .dark { SystemColor.button_border(scheme) } else { Color.rgb(118,118,118) } }
  .buttonface { if scheme == .dark { SystemColor.button_face(scheme) } else { Color.rgb(239,239,239) } }
  else { none }
 }
}
