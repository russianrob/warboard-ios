#!/usr/bin/env python3
"""Merge a partial plist into an existing one (in place).

Used by build-ipa.yml to fold actool's output (CFBundleIcons,
CFBundleIconName, etc.) into the .app's Info.plist before re-signing.

Usage: merge_plist.py <target.plist> <partial.plist>
"""
import plistlib
import sys


def main() -> int:
    if len(sys.argv) != 3:
        sys.exit("usage: merge_plist.py <target.plist> <partial.plist>")
    target, partial = sys.argv[1], sys.argv[2]
    with open(target, "rb") as f:
        merged = plistlib.load(f)
    with open(partial, "rb") as f:
        delta = plistlib.load(f)
    merged.update(delta)
    with open(target, "wb") as f:
        plistlib.dump(merged, f)
    print(f"Merged keys into {target}: {list(delta.keys())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
