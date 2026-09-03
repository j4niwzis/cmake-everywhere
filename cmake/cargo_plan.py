"""What cargo would do, as commands this build runs itself.

`cargo build --build-plan` answers the question every other build system
here is asked: not "please build this", but "what would you run". The answer
is one entry per invocation of rustc -- the program, its arguments, its
environment, the directory to run it in, what it produces and which other
invocations must come first -- and that is enough to make each of them a
command in the graph this project builds with.

What that buys is what it buys for Meson and GN: the compilation happens
where every other compilation happens, in dependency order decided by one
scheduler, with one job pool, and a source file that changes rebuilds what
depends on it and nothing else. Cargo is asked once, at configure time, and
then it steps out of the way.
"""

import argparse
import json
import os
import shlex
import sys


def quote(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


def dep_info(args):
    """Where rustc will write what a crate read, if it was told to.

    The plan says --emit=dep-info when cargo wants one, and rustc names it
    after the crate and the extra filename it was given. Ninja reads it, so
    a header or a module a crate includes is a dependency of that crate here
    rather than only inside cargo's own idea of freshness.
    """
    if not any(arg.startswith("--emit=") and "dep-info" in arg for arg in args):
        return None
    out_dir = crate = extra = None
    for at, arg in enumerate(args):
        if arg == "--out-dir" and at + 1 < len(args):
            out_dir = args[at + 1]
        elif arg == "--crate-name" and at + 1 < len(args):
            crate = args[at + 1]
        elif arg.startswith("extra-filename="):
            extra = arg.split("=", 1)[1]
        elif arg == "-C" and at + 1 < len(args) and \
                args[at + 1].startswith("extra-filename="):
            extra = args[at + 1].split("=", 1)[1]
    if not out_dir or not crate:
        return None
    return os.path.join(out_dir, f"{crate}{extra or ''}.d")


def program(one, told):
    """The compiler, as a path rather than as a name.

    Cargo names the program it would run the way it was spelled -- "rustc",
    plain -- because cargo runs it with its own directory on PATH, which a
    build started from anywhere else does not have. So a bare name becomes
    the compiler cmake found, or failing that the one that sits next to the
    cargo the plan came from, which is where every toolchain puts it.
    """
    named = one.get("program", "rustc")
    if os.path.sep in named or (os.path.altsep and os.path.altsep in named):
        return named
    if named == "rustc" and told:
        return told
    beside = one.get("env", {}).get("CARGO")
    if beside:
        candidate = os.path.join(os.path.dirname(beside), named)
        if os.path.exists(candidate):
            return candidate
    return named


# Cargo asks rustc to report in JSON because cargo reads the report: that is
# how it learns which files came out. Nothing reads it here -- the plan already
# said what would be produced -- so it is dropped, and a Rust error is printed
# the way an error is printed, with the offending line under it.
def machine_talk(arg):
    return arg == "--error-format=json" or arg.startswith("--json=")


# What is worth passing on, of the environment cargo would have set.
#
# Everything a crate can read at compile time is here -- CARGO_PKG_VERSION is
# in the middle of half the crates on the registry -- and the rest is cargo
# talking to itself. Passing the lot is simplest and is what cargo would have
# done, minus the paths that belong to the machine rather than to the build.
SKIP = {"LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH", "PATH"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--stamp", required=True,
                        help="the file that says the whole plan has been run")
    parser.add_argument("--ninja", action="store_true",
                        help="this generator can read what rustc wrote down")
    parser.add_argument("--python", default=sys.executable,
                        help="what runs the script that rewrites those paths")
    parser.add_argument("--rewriter", default=None,
                        help="the script that makes those paths absolute")
    parser.add_argument("--rustc", default=None,
                        help="the compiler this build runs, found by cmake")
    arguments = parser.parse_args()

    with open(arguments.plan, encoding="utf-8") as file:
        plan = json.load(file)
    invocations = plan.get("invocations", [])
    if not invocations:
        print("cargo described a build with nothing in it", file=sys.stderr)
        return 1

    lines = ["# Written by cargo_plan.py from what cargo said it would do.",
             "# One command per invocation of rustc, in the order cargo would",
             "# have run them, driven by this build rather than by cargo."]
    produced = []
    for index, one in enumerate(invocations):
        outputs = list(one.get("outputs", []))
        links = one.get("links", {})
        outputs += list(links.keys())
        if not outputs:
            # A build script that only prints; its effect is in what the
            # invocations after it were told, and those name it as a
            # dependency, so it still needs something to depend on.
            outputs = [f"{arguments.stamp}.{index}"]
        produced.append(outputs)

        depends = []
        for at in one.get("deps", []):
            depends += produced[at]

        command = [program(one, arguments.rustc)] + \
            [arg for arg in one.get("args", []) if not machine_talk(arg)]
        environment = []
        for name, value in sorted(one.get("env", {}).items()):
            if name in SKIP:
                continue
            environment.append(f"{name}={value}")

        lines.append("")
        lines.append(f"# {one.get('package_name')} "
                     f"{one.get('package_version')} "
                     f"({one.get('compile_mode')})")
        lines.append("add_custom_command(")
        lines.append("  OUTPUT " + " ".join(quote(x) for x in outputs))
        out_dirs = sorted({os.path.dirname(x) for x in outputs if os.path.dirname(x)})
        for directory in out_dirs:
            lines.append("  COMMAND \"${CMAKE_COMMAND}\" -E make_directory " +
                         quote(directory))
        lines.append("  COMMAND \"${CMAKE_COMMAND}\" -E env " +
                     " ".join(quote(x) for x in environment) + " " +
                     " ".join(quote(x) for x in command))
        for stable, real in links.items():
            # Copied rather than copied-if-different: the point of the
            # stable name is to be an output of this command, and an output
            # whose timestamp does not move is one this build re-makes for
            # ever, every time, because it looks older than what it came
            # from.
            lines.append("  COMMAND \"${CMAKE_COMMAND}\" -E copy " +
                         quote(real) + " " + quote(stable))
        if not one.get("outputs"):
            lines.append("  COMMAND \"${CMAKE_COMMAND}\" -E touch " +
                         quote(outputs[0]))
        if depends:
            lines.append("  DEPENDS " + " ".join(quote(x) for x in depends))
        wrote = dep_info(one.get("args", []))
        if wrote and arguments.ninja and arguments.rewriter:
            # rustc names what it read relative to where it ran; ninja reads
            # such a file relative to the build directory. The paths are made
            # absolute by the step that follows the compiler, and that is the
            # file ninja is given.
            resolved = wrote + ".resolved"
            lines.append("  COMMAND " + quote(arguments.python) + " " +
                         quote(arguments.rewriter) +
                         " --depfile " + quote(wrote) +
                         " --root " + quote(one.get("cwd", ".")) +
                         " --out " + quote(resolved))
            lines.append("  DEPFILE " + quote(resolved))
        lines.append("  WORKING_DIRECTORY " + quote(one.get("cwd", ".")))
        lines.append("  COMMENT " +
                     quote(f"rust: {one.get('package_name')} "
                           f"{one.get('package_version')}"))
        lines.append("  VERBATIM)")

    everything = [x for group in produced for x in group]
    lines.append("")
    lines.append("set(CME_CARGO_OUTPUTS " +
                 " ".join(quote(x) for x in everything) + ")")
    # What a consumer links: the stable names cargo would have left in the
    # profile directory, rather than the ones with a hash in them.
    linked = []
    for one in invocations:
        for stable in one.get("links", {}):
            if stable.endswith((".a", ".lib", ".so", ".dylib", ".dll")):
                linked.append(stable)
    lines.append("set(CME_CARGO_LIBRARIES " +
                 " ".join(quote(x) for x in linked) + ")")
    with open(arguments.out, "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
