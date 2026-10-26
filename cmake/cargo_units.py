"""What cargo_record.py wrote down, as the plan cargo_plan.py reads.

The records are one file per unit and outlive a configure: cargo compiles
only what is out of date, so a configure after the first sees calls for the
units that changed and none for the rest. Which units this build is made of
is what cargo said this time (`--message-format json`, every unit, fresh or
not), and a record is kept when one of its files is among them -- the file
itself, or the copy cargo makes of it under the profile directory, named
without the hash.

The target's units become the plan, in an order where each comes after the
units whose files its arguments name (--extern name=path). The host's are
not in it -- they were built while configuring -- but the sources of theirs
that live in the project ask for a configure again when they change.
"""

import argparse
import json
import os
import sys


def reported(build_log):
    """Every file cargo says this build is made of."""
    files = set()
    with open(build_log, encoding="utf-8", errors="replace") as stream:
        for line in stream:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("reason") == "compiler-artifact":
                files.update(os.path.abspath(name) for name in message.get("filenames", []))
    return files


def uplifted(path, extra):
    """Where cargo copies a unit's file: up from deps/, without its hash."""
    name = os.path.basename(path)
    if extra:
        name = name.replace(extra, "", 1)
    return os.path.join(os.path.dirname(os.path.dirname(path)), name)


def extra_of(args):
    for at, arg in enumerate(args):
        said = args[at + 1] if arg == "-C" and at + 1 < len(args) else arg[2:] if arg.startswith("-C") else ""
        if said.startswith("extra-filename="):
            return said.split("=", 1)[1]
    return ""


def native(records):
    """What the target's crates link from the system, said to rustc as -l.

    A build script's cargo:rustc-link-lib reaches the compiler as -l on its
    crate's command line, and a static library made of the crate does not
    carry it: rustc bundles the static ones (-l static=) and leaves the rest
    to whoever links the result. So the rest is read here, in order, with
    the directories (-L native=, -L all=) they are looked for in.
    """
    libraries, directories = [], []
    for one in records:
        args = one["args"]
        for at, arg in enumerate(args):
            if arg in ("-l", "-L") and at + 1 < len(args):
                flag, said = arg, args[at + 1]
            elif arg.startswith(("-l", "-L")) and len(arg) > 2:
                flag, said = arg[:2], arg[2:]
            else:
                continue
            kind, _, name = said.rpartition("=")
            kind = kind.split(":", 1)[0]
            if flag == "-L":
                if kind in ("", "native", "all", "framework"):
                    directories.append(name)
            elif kind in ("", "dylib"):
                libraries.append(name.split(":", 1)[-1])
            elif kind == "framework":
                libraries.append(f"$<LINK_LIBRARY:FRAMEWORK,{name}>")
    return list(dict.fromkeys(libraries)), list(dict.fromkeys(directories))


# Cargo's own conversation with the compiler, and the wrapper's: nothing a
# command run later needs, and the jobserver's descriptors are long closed.
NOT_PASSED = {"RUSTC_WRAPPER", "RUSTC_WORKSPACE_WRAPPER", "CME_CARGO_UNITS",
              "CARGO_MAKEFLAGS", "MAKEFLAGS", "MFLAGS"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--units", required=True, help="where the records are")
    parser.add_argument("--build-log", required=True)
    parser.add_argument("--source", required=True, help="the crate's checkout")
    parser.add_argument("--plan", required=True, help="the plan to write")
    parser.add_argument("--depends", required=True,
                        help="the CMake file naming what asks for a configure")
    arguments = parser.parse_args()

    files = reported(arguments.build_log)
    records = []
    for name in sorted(os.listdir(arguments.units)):
        if not name.endswith(".json"):
            continue
        with open(os.path.join(arguments.units, name), encoding="utf-8") as file:
            one = json.load(file)
        extra = extra_of(one["args"])
        if any(out in files or uplifted(out, extra) in files for out in one["outputs"]):
            records.append(one)
    target = [one for one in records if not one["host"]]
    if not target:
        print("no unit for the target was recorded", file=sys.stderr)
        return 1

    # Which unit makes which file, and so which units each one waits for.
    maker = {out: at for at, one in enumerate(target) for out in one["outputs"]}

    def waits_for(one):
        named = {arg.split("=", 1)[1] if "=" in arg else arg for arg in one["args"]}
        return sorted({maker[path] for path in named if path in maker})

    waits = [waits_for(one) for one in target]
    order, placed = [], {}
    pending = list(range(len(target)))
    while pending:
        ready = [at for at in pending if all(dep in placed for dep in waits[at])]
        if not ready:
            print("the recorded units wait for each other in a circle", file=sys.stderr)
            return 1
        for at in ready:
            placed[at] = len(order)
            order.append(at)
        pending = [at for at in pending if at not in placed]

    invocations = []
    for at in order:
        one = target[at]
        env = {name: value for name, value in one["env"].items()
               if name not in NOT_PASSED and os.environ.get(name) != value}
        invocations.append({
            "program": one["program"],
            "args": one["args"],
            "env": env,
            "cwd": one["cwd"],
            "outputs": one["outputs"],
            "links": {},
            "deps": [placed[dep] for dep in waits[at]],
            "package_name": one["env"].get("CARGO_PKG_NAME", ""),
            "package_version": one["env"].get("CARGO_PKG_VERSION", ""),
            "compile_mode": "build",
            # Linked from where rustc writes it, not from cargo's copy: that
            # copy is a hard link to what stood there while configuring.
            "libraries": [out for out in one["outputs"]
                          if "staticlib" in one["crate_types"] and out.endswith((".a", ".lib"))],
        })
    with open(arguments.plan, "w", encoding="utf-8") as file:
        json.dump({"invocations": invocations}, file)

    source = os.path.realpath(arguments.source)
    local = set()
    for one in records:
        if not one["host"]:
            continue
        for out in one["outputs"]:
            if not out.endswith(".d") or not os.path.exists(out):
                continue
            with open(out, encoding="utf-8", errors="replace") as file:
                for line in file:
                    line = line.strip()
                    if line.endswith(":") and not line.startswith("#"):
                        path = os.path.realpath(os.path.join(one["cwd"], line[:-1]))
                        if path.startswith(source + os.sep):
                            local.add(path)
    local.update(os.path.join(source, name) for name in ("Cargo.toml", "Cargo.lock")
                 if os.path.exists(os.path.join(source, name)))
    with open(arguments.depends, "w", encoding="utf-8") as file:
        file.write("set(CME_CARGO_CONFIGURE_DEPENDS\n")
        for path in sorted(local):
            file.write('  "' + path.replace("\\", "/").replace('"', '\\"') + '"\n')
        file.write(")\n")
        libraries, directories = native(target)
        for variable, values in (("CME_CARGO_NATIVE_LIBRARIES", libraries),
                                 ("CME_CARGO_NATIVE_DIRECTORIES", directories)):
            file.write(f"set({variable}\n")
            for value in values:
                file.write('  "' + value.replace("\\", "/").replace('"', '\\"') + '"\n')
            file.write(")\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
