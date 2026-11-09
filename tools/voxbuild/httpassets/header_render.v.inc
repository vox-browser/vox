
pub fn (h Header) render_into_sb(mut sb strings.Builder, flags HeaderRenderConfig) {
    for kv in h.data {
        key := if flags.version == .v2_0 {
            kv.key.to_lower()
        } else if flags.canonicalize {
            canonicalize(kv.key.to_lower())
        } else {
            kv.key
        }
        sb.write_string(key)
        sb.write_string(': ')
        sb.write_string(kv.value)
        sb.write_string('\r\n')
    }
}