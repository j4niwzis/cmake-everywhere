"""What cargo runs rustc with, written down as it happens.

Cargo used to answer "what would you run" without running it: `cargo build
--build-plan`. Current cargo has no such flag, so the question is asked the
other way: cargo builds, and rustc is reached through this script, set as
RUSTC_WRAPPER for that one build. Each call that compiles a crate is
recorded -- the compiler, its arguments, its environment, where it ran and
the files it makes -- in a file of its own, one per unit.

Two kinds of unit come through, and they are told apart by --target, which
cmake-everywhere always gives cargo:

- The host's: build scripts, procedural macros and what they use. Cargo runs
  build scripts itself and needs their output to go on, so these are
  compiled now, for real. They are recorded only so that a change to a local
  one asks for a configure again.
- The target's: everything that ends up in the library. These are recorded
  and not compiled -- empty files stand where their outputs go, so cargo
  goes on as if they had been made -- and this build compiles them later,
  each a command in its graph. A file already there (compiled by an earlier
  build) is left as it is.

Anything else goes straight to rustc: `rustc -vV`, cargo asking what a
target's files are called (`--crate-name ___`), and a build script trying
the compiler out (proc-macro2's, autocfg's: RUSTC_WRAPPER is theirs to use
too). That last one must be compiled for real -- an empty file standing for
it tells the script the compiler can do what it cannot -- and it is told
apart from a unit by what cargo gives every unit and a build script never
does: -C metadata, and an environment with no HOST and TARGET in it (those
are said to build scripts, not to the compiler).
"""

import json
import os
import subprocess
import sys


def option(args, name):
    """Every value of an option given as `name value` or `name=value`."""
    values = []
    for at, arg in enumerate(args):
        if arg == name and at + 1 < len(args):
            values.append(args[at + 1])
        elif arg.startswith(name + "="):
            values.append(arg[len(name) + 1:])
    return values


def codegen(args, key):
    """A -C option's value: `-C key=value` or `-Ckey=value`."""
    for at, arg in enumerate(args):
        said = None
        if arg == "-C" and at + 1 < len(args):
            said = args[at + 1]
        elif arg.startswith("-C") and len(arg) > 2:
            said = arg[2:]
        if said and said.startswith(key + "="):
            return said[len(key) + 1:]
    return None


def produces(args, target):
    """The files rustc makes for these arguments, by rustc's own naming."""
    out_dir = (option(args, "--out-dir") or ["."])[-1]
    crate = option(args, "--crate-name")[-1]
    extra = codegen(args, "extra-filename") or ""
    kinds = option(args, "--crate-type") or ["bin"]
    emits = [kind.split("=", 1)[0]
             for said in (option(args, "--emit") or ["link"])
             for kind in said.split(",")]
    windows = "windows" in target
    msvc = windows and "msvc" in target
    apple = "apple" in target
    wasm = target.startswith("wasm")
    stem = f"{crate}{extra}"

    def linked(kind):
        if kind in ("lib", "rlib"):
            return f"lib{stem}.rlib"
        if kind == "staticlib":
            return f"{stem}.lib" if msvc else f"lib{stem}.a"
        if kind in ("dylib", "cdylib", "proc-macro"):
            if windows:
                return f"{stem}.dll"
            if apple:
                return f"lib{stem}.dylib"
            if wasm:
                return f"{stem}.wasm"
            return f"lib{stem}.so"
        if windows:
            return f"{stem}.exe"
        if wasm:
            return f"{stem}.wasm"
        return stem

    names = []
    for emit in emits:
        if emit == "dep-info":
            names.append(f"{stem}.d")
        elif emit == "metadata":
            names.append(f"lib{stem}.rmeta")
        elif emit == "link":
            names += [linked(kind) for kind in kinds]
    return [os.path.abspath(os.path.join(out_dir, name)) for name in dict.fromkeys(names)]


def main():
    rustc, args = sys.argv[1], sys.argv[2:]
    units = os.environ.get("CME_CARGO_UNITS")
    crate = option(args, "--crate-name")
    probing = codegen(args, "metadata") is None or ("HOST" in os.environ and "TARGET" in os.environ)
    if not units or not crate or crate[-1] == "___" or probing:
        os.execv(rustc, [rustc] + args) if os.path.sep in rustc else os.execvp(rustc, [rustc] + args)
    targets = option(args, "--target")
    host = not targets
    record = {
        "program": rustc,
        "args": args,
        "env": dict(os.environ),
        "cwd": os.getcwd(),
        "host": host,
        "crate_types": option(args, "--crate-type"),
        "outputs": produces(args, targets[-1] if targets else sys.platform),
    }
    if host:
        code = subprocess.call([rustc] + args)
        if code != 0:
            return code
    else:
        for path in record["outputs"]:
            if not os.path.exists(path):
                os.makedirs(os.path.dirname(path), exist_ok=True)
                open(path, "wb").close()
    os.makedirs(units, exist_ok=True)
    name = f"{crate[-1]}{codegen(args, 'extra-filename') or ''}-{'host' if host else 'target'}.json"
    # Written whole under another name and moved: cargo runs many of these
    # at once, and a reader never sees half of one.
    with open(os.path.join(units, name + ".part"), "w", encoding="utf-8") as file:
        json.dump(record, file)
    os.replace(os.path.join(units, name + ".part"), os.path.join(units, name))
    return 0


if __name__ == "__main__":
    sys.exit(main())
