"""What cargo itself does between the compiler's runs, done by the build.

The crates are compiled by rustc directly, each a command of the build.
Two things cargo did around them are left, and are done here:

    cargo_run.py run --script BIN --output FILE [--dep LINKS=FILE]...
        Runs a build script the way cargo would: in its package's directory,
        with the environment cargo gave it (the command around this one
        sets it) and DEP_<LINKS>_<KEY> for what the build scripts of the
        packages it depends on said (`links`). What it prints is kept in
        FILE; what it says to the compiler -- --cfg, --check-cfg, -l, -L --
        in FILE.args, one argument a line, which its crate's rustc is given
        as @FILE.args; what it reads (rerun-if-changed) in FILE.d, so that
        Ninja runs it again when one of those changes.

    cargo_run.py native --listed TXT --rsp RSP [--search FILE]...
        What a C or C++ program linking the static library needs beside it:
        the libraries rustc listed for it (--print native-static-libs=TXT)
        and the directories the build scripts said to search, as a linker
        response file.
"""

import os
import shlex
import subprocess
import sys


def lines_of(text):
    """(key, value) for each cargo: line a build script printed."""
    lines = []
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("cargo::"):
            rest = line[len("cargo::"):]
        elif line.startswith("cargo:"):
            rest = line[len("cargo:"):]
        else:
            continue
        key, _, value = rest.partition("=")
        if key == "metadata":
            key, _, value = value.partition("=")
            key = "metadata:" + key
        lines.append((key, value))
    return lines


def said(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8", errors="replace") as file:
        return lines_of(file.read())


# What a build script tells cargo rather than the packages that depend on it
# (everything else in the old `cargo:KEY=VALUE` form is metadata for them).
KNOWN = {"rustc-cfg", "rustc-check-cfg", "rustc-link-lib", "rustc-link-search",
         "rustc-flags", "rustc-env", "rerun-if-changed", "rerun-if-env-changed",
         "warning", "error", "rustc-link-arg", "rustc-link-arg-bins",
         "rustc-link-arg-bin", "rustc-link-arg-tests", "rustc-link-arg-examples",
         "rustc-link-arg-benches", "rustc-cdylib-link-arg", "rustc-link-arg-cdylib"}


def options(arguments):
    found = {}
    for at in range(0, len(arguments) - 1, 2):
        found.setdefault(arguments[at], []).append(arguments[at + 1])
    return found


def write_if_changed(path, text):
    if os.path.exists(path):
        with open(path, encoding="utf-8", errors="replace") as file:
            if file.read() == text:
                return
    with open(path, "w", encoding="utf-8") as file:
        file.write(text)


def escape(path):
    return path.replace("\\", "/").replace(" ", "\\ ").replace("$", "$$")


def run(arguments):
    given = options(arguments)
    script, output = given["--script"][0], given["--output"][0]
    env = dict(os.environ)
    for dep in given.get("--dep", []):
        links, _, path = dep.partition("=")
        prefix = "DEP_" + links.upper().replace("-", "_") + "_"
        for key, value in said(path):
            if key.startswith("metadata:"):
                env[prefix + key[len("metadata:"):].upper().replace("-", "_")] = value
            elif key not in KNOWN:
                env[prefix + key.upper().replace("-", "_")] = value
    os.makedirs(env["OUT_DIR"], exist_ok=True)
    root = env.get("CARGO_MANIFEST_DIR", os.getcwd())
    name = env.get("CARGO_PKG_NAME", "?")
    done = subprocess.run([script], cwd=root, env=env, stdout=subprocess.PIPE)
    text = done.stdout.decode("utf-8", errors="replace")
    lines = lines_of(text)
    for key, value in lines:
        if key in ("warning", "error"):
            print(f"{name}: {key}: {value}", file=sys.stderr)
    if done.returncode != 0:
        sys.stderr.write(text)
        print(f"the build script of {name} failed", file=sys.stderr)
        return done.returncode
    # What rustc is given as @FILE.args: one argument a line.
    args = []
    for key, value in lines:
        if key == "rustc-cfg":
            args += ["--cfg", value]
        elif key == "rustc-check-cfg":
            args += ["--check-cfg", value]
        elif key == "rustc-link-lib":
            args += ["-l", value]
        elif key == "rustc-link-search":
            args += ["-L", value]
        elif key == "rustc-flags":
            args += shlex.split(value)
        elif key == "rustc-env":
            # rustc takes no environment from an argument file, and the crate
            # is compiled by rustc itself: nothing can carry it there.
            print(f"cmake-everywhere: the build script of {name} sets {value.partition('=')[0]} "
                  "for its crate (cargo:rustc-env), which a crate compiled by this build "
                  "does not get", file=sys.stderr)
            return 1
    if any("\n" in arg for arg in args):
        print(f"cmake-everywhere: {name}'s build script said an argument with a line break in it",
              file=sys.stderr)
        return 1
    write_if_changed(output, text)
    write_if_changed(output + ".args", "".join(arg + "\n" for arg in args))
    watched = [os.path.join(root, value) for key, value in lines if key == "rerun-if-changed"]
    depfile = escape(output) + ":" + "".join(
        " \\\n  " + escape(os.path.abspath(path)) for path in watched if os.path.isfile(path)) + "\n"
    with open(output + ".d", "w", encoding="utf-8") as file:
        file.write(depfile)
    return 0


def native(arguments):
    given = options(arguments)
    listed, rsp = given["--listed"][0], given["--rsp"][0]
    flags = []
    if os.path.exists(listed):
        with open(listed, encoding="utf-8", errors="replace") as file:
            flags = shlex.split(file.read().replace("native-static-libs:", " "))
    directories = []
    for output in given.get("--search", []):
        for key, value in said(output):
            if key == "rustc-link-search":
                kind, _, where = value.rpartition("=")
                if kind in ("", "native", "all"):
                    directories.append("-L" + where)
    lines = list(dict.fromkeys(directories)) + flags
    write_if_changed(rsp, "".join(shlex.quote(line) + "\n" for line in lines))
    return 0


def main():
    if sys.argv[1] == "run":
        return run(sys.argv[2:])
    if sys.argv[1] == "native":
        return native(sys.argv[2:])
    print(f"cargo_run.py: no such step: {sys.argv[1]}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
