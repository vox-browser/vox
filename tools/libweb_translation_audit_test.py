import tempfile
import unittest
from pathlib import Path

import libweb_translation_audit as audit


class TrivialImplementationInventoryTests(unittest.TestCase):
    def test_verified_allocator_factory_is_not_suspicious(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "permissionsapi" / "permissions.v"
            source.parent.mkdir()
            source.write_text(
                """
module permissionsapi

struct Permissions {}

fn Permissions.create() &Permissions {
    return &Permissions{}
}
"""
            )
            region_source = Path(directory) / "webvtt" / "vtt_region.v"
            region_source.parent.mkdir()
            region_source.write_text(
                """
module webvtt

struct VTTRegion {}

fn VTTRegion.create() &VTTRegion {
    return &VTTRegion{}
}
"""
            )

            suspicious, verified = audit.trivial_implementation_inventories(Path(directory))

        self.assertEqual(suspicious, [])
        self.assertEqual(len(verified), 2)
        self.assertEqual(
            {finding["owner"] for finding in verified}, {"Permissions", "VTTRegion"}
        )

    def test_foreign_function_declaration_is_not_an_empty_implementation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "boundary.c.v"
            source.write_text(
                """
module boundary

fn C.external_value() &C.Value

const cache = map[string]int{}

fn genuinely_empty() {
}
"""
            )

            suspicious, _ = audit.trivial_implementation_inventories(Path(directory))

        self.assertEqual(
            suspicious,
            [
                {
                    "source": "boundary.c.v",
                    "line": 8,
                    "owner": None,
                    "name": "genuinely_empty",
                    "body": "",
                }
            ],
        )

    def test_webgl_proxy_noops_are_reviewed_upstream_equivalents(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "webgl" / "context_proxy.v"
            source.parent.mkdir()
            source.write_text(
                """
module webgl

struct WebGLContextProxyBase {}

fn (_ &WebGLContextProxyBase) make_current() {}
fn (_ &WebGLContextProxyBase) notify_content_will_change() {}
fn (_ &WebGLContextProxyBase) default_framebuffer() u32 { return 0 }
fn (_ &WebGLContextProxyBase) default_renderbuffer() u32 { return 0 }
"""
            )

            suspicious, verified = audit.trivial_implementation_inventories(
                Path(directory)
            )

        self.assertEqual(suspicious, [])
        self.assertEqual(len(verified), 4)


class VFunctionInventoryTests(unittest.TestCase):
    def test_generic_receiver_owner_drops_type_parameters(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "bindings" / "wrapper_world.v"
            source.parent.mkdir()
            source.write_text(
                """
module bindings

pub struct WrapperWorldWeakValueCache[T] {}

pub struct WrapperWorldWeakValueCacheMap[K, V] {}

pub fn (cache &WrapperWorldWeakValueCache[T]) get() ?&T {
    return none
}

pub fn (mut cache WrapperWorldWeakValueCacheMap[K, V]) cache_for(key &K) ?&V {
    return none
}
"""
            )

            functions, _, _ = audit.all_v_function_names(Path(directory))

        self.assertIn(("get", "WrapperWorldWeakValueCache"), functions)
        self.assertNotIn(("get", "WrapperWorldWeakValueCache[T]"), functions)
        self.assertIn(("cache_for", "WrapperWorldWeakValueCacheMap"), functions)
        self.assertNotIn(("cache_for", "V]"), functions)


if __name__ == "__main__":
    unittest.main()
