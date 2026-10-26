"""What cargo runs, written down while configuring -- and nothing built.

Cargo used to answer "what would you run" without running it: `cargo build
--build-plan`. Current cargo has no such flag, so the question is asked the
other way: cargo is let loose on a scratch directory with rustc reached
through this script (RUSTC_WRAPPER), and every call that compiles a unit is
written down -- the compiler, its arguments, its environment, where it ran,
the files it makes -- and not compiled. Empty files stand where its outputs
go, so cargo goes on as if they had been made.

A build script is the one thing cargo runs itself, and what it prints
decides the arguments of the crate it belongs to. So the "binary" that
stands for a build script is this script again (a line of shell calling
it, with --ran): run by cargo, it writes down how it was run -- its
environment says everything cargo told it -- prints nothing, and succeeds.
What the real one prints is applied when the crate is compiled, by
cargo_run.py, in the build, where the script is compiled and run as well.

Anything that does not compile a unit goes straight to rustc: `rustc -vV`,
cargo asking what a target's files are called (`--crate-name ___`).
"""

import json
import os
import stat
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


def host_platform():
    """The machine's own platform, in the words a target triple uses."""
    if sys.platform == "darwin":
        return "apple-darwin"
    if sys.platform == "win32":
        return "windows-msvc"
    return "linux-gnu"


def produces(args, target):
    """The files rustc makes for these arguments, by rustc's own naming,
    and which of them is the program (a build script's)."""
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

    names, program = [], None
    for emit in emits:
        if emit == "dep-info":
            names.append(f"{stem}.d")
        elif emit == "metadata":
            names.append(f"lib{stem}.rmeta")
        elif emit == "link":
            for kind in kinds:
                names.append(linked(kind))
                if kind == "bin":
                    program = os.path.abspath(os.path.join(out_dir, linked(kind)))
    outputs = [os.path.abspath(os.path.join(out_dir, name)) for name in dict.fromkeys(names)]
    return outputs, program


def save(units, name, record):
    os.makedirs(units, exist_ok=True)
    # Written whole under another name and moved: cargo runs many of these
    # at once, and a reader never sees half of one.
    part = os.path.join(units, name + ".part")
    with open(part, "w", encoding="utf-8") as file:
        json.dump(record, file)
    os.replace(part, os.path.join(units, name))


def ran(program, args):
    """A build script, as cargo ran it: written down, nothing printed."""
    units = os.environ["CME_CARGO_UNITS"]
    out_dir = os.environ.get("OUT_DIR", "")
    save(units, "run-" + os.path.basename(os.path.dirname(out_dir)) + ".json", {
        "kind": "run",
        "program": os.path.abspath(program),
        "args": args,
        "env": dict(os.environ),
        "cwd": os.getcwd(),
    })
    return 0


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--ran":
        return ran(sys.argv[2], sys.argv[3:])
    rustc, args = sys.argv[1], sys.argv[2:]
    units = os.environ.get("CME_CARGO_UNITS")
    crate = option(args, "--crate-name")
    if not units or not crate or crate[-1] == "___" or codegen(args, "metadata") is None:
        if os.path.sep in rustc:
            os.execv(rustc, [rustc] + args)
        os.execvp(rustc, [rustc] + args)
    targets = option(args, "--target")
    outputs, program = produces(args, targets[-1] if targets else host_platform())
    for path in outputs:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as file:
            if path == program:
                file.write(f'#!/bin/sh\nexec "{sys.executable}" "{os.path.abspath(__file__)}" --ran "$0" "$@"\n')
        if path == program:
            os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    extra = codegen(args, "extra-filename") or ""
    save(units, f"{crate[-1]}{extra}-{'host' if not targets else 'target'}.json", {
        "kind": "rustc",
        "program": rustc,
        "args": args,
        "env": dict(os.environ),
        "cwd": os.getcwd(),
        "host": not targets,
        "crate_types": option(args, "--crate-type"),
        "outputs": outputs,
        "program_output": program,
    })
    return 0


if __name__ == "__main__":
    sys.exit(main())
