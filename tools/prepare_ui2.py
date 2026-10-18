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
    if not (source / "appkit/ui_macos_darwin.v").is_file():
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
        if entry.name == "chart.v":
            if output.is_symlink():
                output.unlink()
            text = entry.read_text()
            text = text.replace("math.max(0, math.min(1,", "math.max(0.0, math.min(1.0,")
            text = text.replace("math.max(48, f64(", "math.max(48.0, f64(")
            text = text.replace("math.max(0, r * r", "math.max(0.0, r * r")
            write_if_changed(output, text)
        else:
            link_to(output, entry)
    # Use the same checkout's Objective-C bridge, which has the APIs UI2 uses.
    compiler_name = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "V_BIN", shutil.which("v") or str(Path.home() / "code/v/v")
    )
    compiler = Path(compiler_name).resolve()
    macos_source = compiler.parent / "vlib/macos"
    if not (macos_source / "objc_bridge.h").is_file():
        raise SystemExit("UI2 requires a current V checkout with vlib/macos.")
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
    write_if_changed(
        adapter / "embedded_browser_darwin.v",
        (repo / "tools/ui2/embedded_browser_darwin.v").read_text(),
    )
    write_if_changed(
        target / "v.mod",
        "Module {\n name: 'ui2'\n"
        " subdirs: ['ui', 'appkit', 'uikit', 'windows', 'linux', 'vox']\n}\n"
    )
    print(target.parent)


if __name__ == "__main__":
    main()
