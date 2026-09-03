"""What a crate read, in paths this build can resolve.

rustc writes its dependency file in make's format, with the paths as it saw
them -- relative to the directory it was run in, which is the crate's own.
Ninja reads such a file relative to the build directory, so the two disagree
about every relative path, and what it makes of that is nothing: no rebuild
when a source changes, or a transform that stops with no message.

So the paths are made absolute, once, by the only side that knows where
rustc was standing.

rustc also writes down which environment variables a crate read, as comment
lines of the form `# env-dep:NAME=value`. Those have a colon in them and are
not files, so they are dropped: read as dependencies they would name a file
that cannot exist, and a build whose input is missing is rebuilt every time.
"""

import argparse
import os
import sys


def absolute(path, root):
    if not path or os.path.isabs(path):
        return path
    return os.path.normpath(os.path.join(root, path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--depfile", required=True)
    parser.add_argument("--root", required=True,
                        help="where rustc was run, which its paths are from")
    parser.add_argument("--out", required=True)
    arguments = parser.parse_args()

    if not os.path.exists(arguments.depfile):
        # A crate that produced no dependency file has nothing to say; an
        # empty one keeps the build valid rather than failing it.
        with open(arguments.out, "w", encoding="utf-8") as file:
            file.write("")
        return 0

    lines = []
    with open(arguments.depfile, encoding="utf-8", errors="replace") as file:
        for line in file:
            line = line.rstrip("\n")
            if line.lstrip().startswith("#"):
                # What rustc says about the environment, not about files.
                continue
            if ":" not in line:
                lines.append(line)
                continue
            target, _, rest = line.partition(":")
            deps = [absolute(one, arguments.root) for one in rest.split()]
            lines.append(absolute(target.strip(), arguments.root) + ": " +
                         " ".join(deps))
    with open(arguments.out, "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
