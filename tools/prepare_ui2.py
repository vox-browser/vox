#!/usr/bin/env python3
"""Stage UI2 with Vox's embedding adapter, without modifying the UI2 checkout."""

import os
from pathlib import Path
import shutil
import sys


def write_if_changed(path, text):
    if not path.is_file() or path.read_text() != text:
        path.write_text(text)


def link_to(path, source):
    if path.is_symlink():
        if path.resolve() == source.resolve():
            return
        path.unlink()
    path.symlink_to(source, target_is_directory=source.is_dir())


def main():
    repo = Path(__file__).resolve().parent.parent
    modules = Path(os.environ.get("VMODULES", str(Path.home() / ".vmodules")))
    source = Path(os.environ.get("UI2_SOURCE_DIR", str(modules / "ui2"))).resolve()
    if not (source / "ui/ui.v").is_file():
        raise SystemExit("UI2 not found. Set UI2_SOURCE_DIR to your UI2 checkout.")
    target = repo / "Build/v/modules/ui2"
    target.mkdir(parents=True, exist_ok=True)
    for name in ("uikit", "windows", "linux"):
        link_to(target / name, source / name)
    appkit = target / "appkit"
    if appkit.is_symlink():
        appkit.unlink()
    appkit.mkdir(exist_ok=True)
    for entry in (source / "appkit").iterdir():
        output = appkit / entry.name
        if entry.name == "ui_macos_darwin.v":
            if output.is_symlink():
                output.unlink()
            # Modern AppKit may give an NSTextField its own private subviews.
            # Those are not UI2's optional label container; keep the field as
            # the text owner rather than messaging its private drawing view.
            text = entry.read_text().replace(
                "fn label_text_field(view NativeView) NativeView {\n",
                "fn label_text_field(view NativeView) NativeView {\n"
                "\tif macos.msg_bool_id(view, 'isKindOfClass:', macos.get_class('NSTextField')) {\n"
                "\t\treturn view\n\t}\n",
            )
            text = text.replace(
                "\t\t.text_field {\n\t\t\tregister_control(native, element_action_id(el), el.submit_id, el.emit_change)",
                "\t\t.text_field {\n\t\t\tmacos.msg_void_bool(native, 'setUsesSingleLineMode:', true)\n"
                "\t\t\tmacos.msg_void_bool(macos.msg_id(native, 'cell'), 'setScrollable:', true)\n"
                "\t\t\tmacos.msg_void_bool(native, 'setEditable:', !el.readonly)\n"
                "\t\t\tmacos.msg_void_bool(native, 'setSelectable:', true)\n"
                "\t\t\tregister_control(native, element_action_id(el), el.submit_id, el.emit_change)",
            )
            text = text.replace(
                "macos.add_method(cls, 'mouseUp:', ui2_pointer_mouse_up, 'v@:@')",
                "macos.add_method(cls, 'mouseUp:', ui2_pointer_mouse_up, 'v@:@')\n"
                "\t\tmacos.add_method(cls, 'otherMouseDown:', ui2_embedded_pointer_other, 'v@:@')",
            )
            text = text.replace(
                "macos.add_method(cls, 'mouseUp:', voidptr(ui2_pointer_mouse_up), 'v@:@')",
                "macos.add_method(cls, 'mouseUp:', voidptr(ui2_pointer_mouse_up), 'v@:@')\n"
                "\t\tmacos.add_method(cls, 'otherMouseDown:', voidptr(ui2_embedded_pointer_other), 'v@:@')",
            )
            text = text.replace(
                "\tnative_apply_common_view_state(native, el.hidden",
                "\tmacos.msg_void1(native, 'setIdentifier:', macos.nsstring(el.id))\n"
                "\tnative_apply_common_view_state(native, el.hidden",
            )
            text = text.replace(
                "if !(st.pointer_buttons[pointer] or { false }) || voidptr(st.event_handler) == unsafe { nil } {",
                "if (!(st.pointer_buttons[pointer] or { false }) && !(st.pointer_draggable[pointer] or { false })) || voidptr(st.event_handler) == unsafe { nil } {",
            )
            text = text.replace(
                "\tapply_common_native_state(native, el)\n\treturn native",
                "\tapply_common_native_state(native, el)\n\tapply_embedded_vector_path(native, el)\n\tapply_embedded_button_image(native, el)\n"
                "\treturn native",
            )
            # Apply a declared family as soon as a control exists. The tooltip
            # installed later in render_element measures the button title, and
            # measuring a symbol in the system face builds CoreText's fallback cascade.
            text = text.replace(
                "\t\tnative = native_create_element(create_el)\n",
                "\t\tnative = native_create_element(create_el)\n\t\tapply_embedded_text_font(native, create_el)\n", 1,
            )
            # A native-styled transparent button is flat at rest. Let UI2's
            # backend supply the hover/pressed bezel, without browser subclasses.
            text = text.replace(
                "\tif native_style && box_draws_fill(box) {",
                "\tmacos.msg_void_bool(button_view, 'setShowsBorderOnlyWhileMouseInside:', false)\n"
                "\tif native_style && !box_draws_fill(box) {\n"
                "\t\tmacos.msg_void_i64(button_view, 'setButtonType:', ns_button_type_momentary_push_in)\n"
                "\t\tmacos.msg_void_u64(button_view, 'setBezelStyle:', 13)\n"
                "\t\tmacos.msg_void_bool(button_view, 'setBordered:', true)\n"
                "\t\tmacos.msg_void_bool(button_view, 'setShowsBorderOnlyWhileMouseInside:', true)\n"
                "\t\tmacos.msg_void_bool(button_view, 'setWantsLayer:', false)\n"
                "\t\tmacos.msg_void1(button_view, 'setFont:', native_font(size, bold, italic))\n"
                "\t\tnative_control_set_attributed_title(button_view, title, text_hex, size, bold, italic, underline)\n"
                "\t} else if native_style && box_draws_fill(box) {",
            )
            # Select the final bezel once. Resetting a flat native button to
            # rounded and back makes AppKit rebuild its cell on every update.
            text = text.replace(
                "\tmacos.msg_void_u64(button_view, 'setBezelStyle:', 1)\n"
                "\tmacos.msg_void_bool(button_view, 'setShowsBorderOnlyWhileMouseInside:', false)",
                "\tapply_embedded_button_bezel(button_view, native_style && !box_draws_fill(box))",
            ).replace(
                "\t\tmacos.msg_void_u64(button_view, 'setBezelStyle:', 13)",
                "\t\tif disable_embedded_button_bezel_coalescing {\n"
                "\t\t\tmacos.msg_void_u64(button_view, 'setBezelStyle:', 13)\n\t\t}",
            ).replace(
                "\t\tmacos.msg_void_bool(button_view, 'setShowsBorderOnlyWhileMouseInside:', true)",
                "\t\tif disable_embedded_button_bezel_coalescing {\n"
                "\t\t\tmacos.msg_void_bool(button_view, 'setShowsBorderOnlyWhileMouseInside:', true)\n\t\t}",
            )
            # Clearing an image a button never had still makes AppKit measure its
            # title. On creation that happens before a declared font family is
            # applied, building CoreText's fallback cascade for symbol titles.
            text = text.replace(
                "\tif image_name.trim_space() == '' {\n"
                "\t\tmacos.msg_void1(button_view, 'setImage:', macos.Id(unsafe { nil }))\n"
                "\t\tmacos.msg_void_i64(button_view, 'setImagePosition:', 0)\n"
                "\t\treturn\n\t}",
                "\tif image_name.trim_space() == '' {\n"
                "\t\tif !objc_is_nil(macos.msg_id(button_view, 'image')) {\n"
                "\t\t\tmacos.msg_void1(button_view, 'setImage:', macos.Id(unsafe { nil }))\n\t\t}\n"
                "\t\tif macos.msg_i64(button_view, 'imagePosition') != 0 {\n"
                "\t\t\tmacos.msg_void_i64(button_view, 'setImagePosition:', 0)\n\t\t}\n"
                "\t\treturn\n\t}",
            )
            # Label and button updates reinstall the system face; keep a declared family.
            # Creation's match arms are values, so patch only the update function.
            head, marker, tail = text.partition("fn native_update_element(")
            text = head + marker + tail.replace(
                "label_needs_container(el))\n\t\t}\n\t\t.image {",
                "label_needs_container(el))\n\t\t\tapply_embedded_text_font(native, el)\n\t\t}\n\t\t.image {", 1,
            ).replace(
                "el.image_path, el.native_style)\n\t\t}\n\t\t.checkbox {",
                "el.image_path, el.native_style)\n\t\t\tapply_embedded_text_font(native, el)\n\t\t}\n\t\t.checkbox {", 1,
            )
            text = text.replace(
                "\tnode_kinds          map[string]Kind",
                "\tnode_visual_inputs map[string]EmbeddedNativeVisualInputs\n"
                "\tnode_kinds          map[string]Kind",
            ).replace(
                "fn render_element(parent NativeView, el Element, key string, mut active map[string]bool) NativeView {\n"
                "\tactive[key] = true\n\tmut st := state()",
                "fn render_element(parent NativeView, el Element, key string, mut active map[string]bool) NativeView {\n"
                "\tactive[key] = true\n\tmut st := state()\n"
                "\tvisual_changed := embedded_native_visual_changed(mut st, key, el)",
            ).replace(
                "\t\tnative_update_element(native, el, declared_text_changed, content_changed)",
                "\t\tif visual_changed {\n"
                "\t\t\tnative_update_element(native, el, declared_text_changed, content_changed)\n\t\t}",
            ).replace(
                "\t\tst.nodes.delete(key)",
                "\t\tst.nodes.delete(key)\n\t\tst.node_visual_inputs.delete(key)",
            )
            write_if_changed(output, text)
        elif entry.name == "ui_macos_objc_darwin.v":
            if output.is_symlink():
                output.unlink()
            text = entry.read_text().replace(
                "\t\t'switch' { macos.nsstring('AXCheckBox') }",
                "\t\t'switch' { macos.nsstring('AXCheckBox') }\n"
                "\t\t'tab' { macos.nsstring('AXRadioButton') }\n"
                "\t\t'tab_list' { macos.nsstring('AXTabGroup') }\n"
                "\t\t'menu' { macos.nsstring('AXMenu') }\n"
                "\t\t'menu_item' { macos.nsstring('AXMenuItem') }\n"
                "\t\t'group' { macos.nsstring('AXGroup') }",
            )
            # UI2 and its custom renderer interpret packed colors as sRGB.
            # Calibrated RGB lightens the classic gray chrome on modern displays.
            text = text.replace("'colorWithCalibratedRed:green:blue:alpha:'", "'colorWithSRGBRed:green:blue:alpha:'")
            write_if_changed(output, text)
        else:
            link_to(output, entry)
    # UI2 follows current V. The browser uses V's compatibility frontend;
    # make the three floating-point generic calls explicit in the staged copy.
    ui = target / "ui"
    if ui.is_symlink():
        ui.unlink()
    ui.mkdir(exist_ok=True)
    for entry in (source / "ui").iterdir():
        output = ui / entry.name
        if entry.name in {"chart.v", "ui_immediate.c.v", "ui.v"}:
            if output.is_symlink():
                output.unlink()
            text = entry.read_text()
            text = text.replace("math.max(0, math.min(1,", "math.max(0.0, math.min(1.0,")
            text = text.replace("math.max(48, f64(", "math.max(48.0, f64(")
            text = text.replace("math.max(0, r * r", "math.max(0.0, r * r")
            text = text.replace("if el.enabled && !el.readonly {", "if el.enabled {")
            if entry.name == "ui.v":
                text = text.replace("pub struct Element {\npub:", "pub struct Element {\npub:\n\tvector VectorPath\n\tbutton_image_size f64")
            if entry.name == "ui_immediate.c.v":
                text = text.replace(
                    "button_image_layout(el.frame.width, el.frame.height, el.text,\n\t\t\t\t\tel.image_path)",
                    "embedded_button_image_layout(el)",
                )
                text = text.replace("\t\tarea := element_area(ctx, el, off_x, off_y)",
                    "\t\tarea := element_area(ctx, el, off_x, off_y)\n"
                    "\t\tdraw_embedded_vector_path(ctx, el.vector, off_x + el.frame.x, off_y + el.frame.y)")
            # Transparent buttons are used as dismiss targets over documents.
            text = text.replace(
                "\t\t\t\t} else {\n\t\t\t\t\tdraw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)",
                "\t\t\t\t} else if box_draws_fill(el.box) {\n\t\t\t\t\tdraw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)",
            )
            text = text.replace(
                "\t\t\t\tif el.native_style && el.box.bg == unstyled_box_bg {",
                "\t\t\t\tif el.native_style && el.box.transparent {\n"
                "\t\t\t\t\tif (g_tooltip.pointer_in && g_tooltip.pointer_x >= x && g_tooltip.pointer_x < x + el.frame.width\n"
                "\t\t\t\t\t\t&& g_tooltip.pointer_y >= y && g_tooltip.pointer_y < y + el.frame.height)\n"
                "\t\t\t\t\t\t|| (g_touch.down && g_touch.pointer_target.id == el.id) {\n"
                "\t\t\t\t\t\tdraw_rect(ctx, x, y, el.frame.width, el.frame.height, el.box.bg, el.box.radius)\n"
                "\t\t\t\t\t}\n"
                "\t\t\t\t} else if el.native_style && el.box.bg == unstyled_box_bg {",
            )
            write_if_changed(output, text)
        else:
            link_to(output, entry)
    # Use the same checkout's Objective-C bridge, which has the APIs UI2 uses.
    compiler_name = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "V_BIN", shutil.which("v") or str(Path.home() / "code/v/v")
    )
    compiler = Path(compiler_name).resolve()
    macos_source = compiler.parent / "vlib/macos"
    if sys.platform == "darwin" and not (macos_source / "objc_bridge.h").is_file():
        raise SystemExit("UI2 requires a current V checkout with vlib/macos.")
    if sys.platform == "darwin":
        macos = target.parent / "macos"
        macos.mkdir(exist_ok=True)
        write_if_changed(
            macos / "macos.c.v",
            (macos_source / "macos.c.v").read_text().replace(
                "@VEXEROOT/vlib/macos/objc_bridge.h", str(macos_source / "objc_bridge.h")
            ),
        )
    adapter = target / "vox"
    if adapter.is_symlink():
        adapter.unlink()
    adapter.mkdir(exist_ok=True)
    # Remove the previous single-control adapter when refreshing an old stage.
    (adapter / "embedded_textbox_darwin.v").unlink(missing_ok=True)
    write_if_changed(adapter / "embedded_input_windows.v",
                     (repo / "tools/ui2/embedded_input_windows.v").read_text())
    write_if_changed(adapter / "embedded_host_windows.v",
                     (repo / "tools/ui2/embedded_host_windows.v").read_text())
    for name in ("embedded_browser_darwin.v", "embedded_elements_custom.c.v", "embedded_input_darwin.v", "embedded_input_darwin.h", "embedded_panel_darwin.v", "embedded_host_linux.v", "embedded_host_linux.h", "button_image.v", "button_image_darwin.v", "button_image_custom.c.v", "button_style_darwin.v", "native_visual_inputs_darwin.v", "native_visual_inputs_test.v", "vector_path.v", "vector_path_darwin.v", "vector_path_darwin.h", "vector_path_custom.c.v", "embedded_text_font_darwin.v"):
        write_if_changed(adapter / name, (repo / "tools/ui2" / name).read_text())
    write_if_changed(
        target / "v.mod",
        "Module {\n name: 'ui2'\n"
        " subdirs: ['ui', 'appkit', 'uikit', 'windows', 'linux', 'vox']\n}\n"
    )
    print(target.parent)


if __name__ == "__main__":
    main()
