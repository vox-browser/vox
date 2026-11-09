
pub fn (mut h Header) set(key CommonHeader, value string) {
    h.vox_replace_header_value(key.str(), value)
}