"""What cargo said it built, as something CMake can read.

`cargo build --message-format=json` narrates a build: one JSON object per
line, and the ones that matter here say "compiler-artifact" and carry the
files that came out of a crate. This picks the ones a C++ build can link --
the static libraries -- and writes their paths, the crate they came from and
the libraries the Rust side needs from the system.

That last part is the one that cannot be guessed. A Rust static library does
not carry its own dependencies the way a shared one does: it needs libc, the
unwinder, pthreads and whatever else its crates reached for, and the only
thing that knows the list is rustc. It is asked, with
`--print native-static-libs`, and what it prints goes onto the imported
target as its interface.
"""

import argparse
import json
import re
import sys


def artifacts(stream):
    """The static libraries cargo reports, in the order it reports them."""
    found = []
    for line in stream:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if message.get("reason") != "compiler-artifact":
            continue
        kinds = message.get("target", {}).get("kind", [])
        if "staticlib" not in kinds and "cdylib" not in kinds:
            continue
        for name in message.get("filenames", []):
            if name.endswith((".a", ".lib", ".so", ".dylib", ".dll")):
                found.append((message["target"]["name"], name))
    return found


def native_libraries(text):
    """The libraries rustc says a static Rust library needs beside it.

    It prints them as one line, `native-static-libs: -lgcc_s -lutil ...`,
    which is a linker command line rather than a list of names -- so the
    flags that are not libraries are kept as they are and the -l ones are
    reduced to names, because that is what CMake wants on a target.
    """
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("native-static-libs:"):
            continue
        out = []
        for word in line.split(":", 1)[1].split():
            if word.startswith("-l"):
                out.append(word[2:])
            elif word.startswith("-"):
                out.append(word)
            else:
                out.append(word)
        # Said twice by cargo when a crate is built for two profiles; the
        # order is what the linker needs, so duplicates go rather than
        # everything being sorted.
        seen = set()
        return [x for x in out if not (x in seen or seen.add(x))]
    return []


def quote(text):
    return '"' + str(text).replace("\\", "/").replace('"', '\\"') + '"'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-log", required=True,
                        help="what cargo build --message-format=json wrote")
    parser.add_argument("--link-log", default=None,
                        help="what rustc --print native-static-libs wrote")
    parser.add_argument("--out", required=True, help="the CMake file to write")
    arguments = parser.parse_args()

    with open(arguments.build_log, encoding="utf-8", errors="replace") as file:
        built = artifacts(file)
    libraries = []
    if arguments.link_log:
        with open(arguments.link_log, encoding="utf-8", errors="replace") as file:
            libraries = native_libraries(file.read())

    if not built:
        print("cargo built no static library", file=sys.stderr)
        return 1

    lines = ["# Written by cargo_import.py. What cargo built, as CMake sees it."]
    lines.append("set(CME_CARGO_ARTIFACTS")
    for name, path in built:
        lines.append(f"  {quote(name)} {quote(path)}")
    lines.append(")")
    lines.append("set(CME_CARGO_NATIVE_LIBRARIES " +
                 " ".join(quote(one) for one in libraries) + ")")
    with open(arguments.out, "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
