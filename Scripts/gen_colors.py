#!/usr/bin/env python3
"""把 Assets.xcassets 里的 colorset 转成 mvcolors.json，供 MVResource.color(_:) 在无 Xcode 构建时使用。"""
import json
import os
import sys


def camel_to_symbol(name: str) -> str:
    """timer-time-color -> timerTime（与 Xcode 生成的符号名保持一致）"""
    base = name[:-len("-color")] if name.endswith("-color") else name
    parts = base.split("-")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


def to_float(value) -> float:
    """Xcode 的 colorset 里分量可能是 "0.199"，也可能是 "0xD6" 这类十六进制"""
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if text.lower().startswith("0x"):
        return int(text, 16) / 255.0
    return float(text)


def components_of(entry: dict):
    color = entry.get("color", {})
    comps = color.get("components", {})
    if "red" not in comps:
        return None, None
    values = [
        to_float(comps.get("red", 0)),
        to_float(comps.get("green", 0)),
        to_float(comps.get("blue", 0)),
        to_float(comps.get("alpha", 1)),
    ]
    return values, color.get("color-space", "srgb")


def parse_colorset(path: str):
    with open(os.path.join(path, "Contents.json")) as handle:
        contents = json.load(handle)
    light = None
    dark = None
    space = "srgb"
    for entry in contents.get("colors", []):
        values, entry_space = components_of(entry)
        if values is None:
            continue
        appearances = [
            a.get("value") for a in entry.get("appearances", [])
        ]
        if "dark" in appearances:
            dark = values
            space = entry_space or space
        elif light is None:
            light = values
            space = entry_space or space
    if light is None:
        return None
    return {"space": space, "light": light, "dark": dark or light}


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: gen_colors.py <assets-dir> <output-json>", file=sys.stderr)
        sys.exit(1)
    assets_dir, output = sys.argv[1], sys.argv[2]

    table = {}
    for name in sorted(os.listdir(assets_dir)):
        if not name.endswith(".colorset"):
            continue
        entry = parse_colorset(os.path.join(assets_dir, name))
        if entry is None:
            print(f"skip {name}: no srgb components", file=sys.stderr)
            continue
        folder = name[: -len(".colorset")]
        table[camel_to_symbol(folder)] = entry
        table[folder] = entry

    os.makedirs(os.path.dirname(os.path.abspath(output)), exist_ok=True)
    with open(output, "w") as handle:
        json.dump(table, handle, indent=2)
        handle.write("\n")
    print(f"wrote {len(table)} keys -> {output}")


if __name__ == "__main__":
    main()
