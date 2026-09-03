"""Turn `gn gen --ide=json` output into CMake data.

GN describes a build far better than it can be guessed at: every source, every
define, every per-file compiler flag and every generated file, with all of the
project's own conditions already evaluated. This reads that description and
writes it out as CMake variables. It decides nothing; gn.cmake makes the
targets.

It is written in Python rather than in CMake's string(JSON) because that
command re-parses its input on every call, and one of these files is several
megabytes with tens of thousands of members in it. Python is needed anyway:
GN's own action() steps are Python scripts.
"""

import json
import os
import re
import sys


def cmake_name(label):
    """A GN label as a CMake target name.

    //src/core:core becomes src_core__core, and //:skia becomes skia. The
    result has to be unique, so the separators are kept as distinct spellings
    rather than all collapsed to one.
    """
    label = label.split("(", 1)[0]          # drop the toolchain suffix
    label = label.removeprefix("//").lstrip(":")
    return re.sub(r"[^A-Za-z0-9]", lambda m: "__" if m.group() == ":" else "_",
                  label) or "root"


def resolve(path, root, build):
    """A GN path as a real one.

    // is the source root. Anything already absolute is left alone, and
    anything else is relative to the build directory, which is where GN runs
    its scripts from.
    """
    if path.startswith("//"):
        return os.path.normpath(os.path.join(root, path[2:]))
    if os.path.isabs(path):
        return path
    return os.path.normpath(os.path.join(build, path))


def quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit_list(out, name, values):
    out.write("set({} {})\n".format(name, " ".join(quote(v) for v in values)))


def main(argv):
    if len(argv) != 4:
        sys.stderr.write("usage: gn_import.py <project.json> <build-dir> <out.cmake>\n")
        return 2
    with open(argv[1]) as handle:
        project = json.load(handle)

    settings = project.get("build_settings", {})
    root = settings.get("root_path", "")
    build = argv[2]
    targets = project.get("targets", {})

    names = []
    seen = {}
    for label in sorted(targets):
        name = cmake_name(label)
        if name in seen:
            # Two labels that mangle to one name would silently become one
            # target. Say so instead.
            sys.stderr.write(
                "gn_import: {} and {} both become {}\n".format(seen[name], label, name))
            return 1
        seen[name] = label
        names.append(name)

    with open(argv[3], "w") as out:
        out.write("# Written by gn_import.py from a gn --ide=json description.\n")
        out.write("# Anything edited here is overwritten.\n\n")
        out.write("set(GN_ROOT_PATH {})\n".format(quote(root)))
        out.write("set(GN_BUILD_DIR {})\n\n".format(quote(build)))
        emit_list(out, "GN_TARGET_NAMES", names)
        out.write("\n")

        for label in sorted(targets):
            target = targets[label]
            name = cmake_name(label)
            prefix = "GN_TARGET_{}".format(name)
            out.write("# {}\n".format(label))
            out.write("set({}_LABEL {})\n".format(prefix, quote(label)))
            out.write("set({}_TYPE {})\n".format(
                prefix, quote(target.get("type", "unknown"))))

            for field in ("sources", "inputs", "outputs"):
                emit_list(out, "{}_{}".format(prefix, field.upper()),
                          [resolve(p, root, build) for p in target.get(field, [])])
            emit_list(out, prefix + "_INCLUDE_DIRS",
                      [resolve(p, root, build) for p in target.get("include_dirs", [])])
            emit_list(out, prefix + "_LIB_DIRS",
                      [resolve(p, root, build) for p in target.get("lib_dirs", [])])
            for field in ("defines", "cflags", "cflags_c", "cflags_cc",
                          "ldflags", "libs", "args"):
                emit_list(out, "{}_{}".format(prefix, field.upper()),
                          target.get(field, []))
            emit_list(out, prefix + "_DEPS",
                      [cmake_name(d) for d in target.get("deps", [])])
            script = target.get("script")
            out.write("set({}_SCRIPT {})\n\n".format(
                prefix, quote(resolve(script, root, build) if script else "")))

    sys.stderr.write("gn_import: {} targets\n".format(len(names)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
