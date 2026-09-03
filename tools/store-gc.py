#!/usr/bin/env python3
"""Remove from the store what is not an entry, and what is not wanted.

    python3 tools/store-gc.py [store] [--unfinished] [--older-than DAYS]
                              [--port NAME] [--delete]

Nothing is deleted without --delete: the default is to say what would go and
how much it comes to, because a store is a cache of things that took an hour
each and a wrong answer here is paid for in rebuilds.

An entry is content-addressed: its name is a digest of the library, its
version, its features, its options and the environment it was built in. So
nothing refers to an entry by name from outside, nothing has to be updated
when one goes, and the only cost of removing one is building it again. What
there is no way to know is whether it will be wanted -- which is why the
questions this asks are about age and about state, and never about "is this
still needed".

Three kinds of thing are found here:

  unfinished  a .building-<name>-<tag> directory, left by a build that was
              interrupted between filling it and renaming it into place. It
              is never read: the reader looks for the finished name.

  incomplete  an entry with no `complete` marker, which store-finish writes
              last. A reader ignores it, so it occupies disk and answers
              nothing.

  old         an entry nothing has read for a while. Read, not written:
              store-finish sets the time when it publishes, and a hit only
              reads -- so this is honest only where the filesystem records
              access times, and it says so when it cannot tell.
"""
import argparse
import os
import shutil
import sys
import time


def default_store():
    cache = os.environ.get("XDG_CACHE_HOME")
    if not cache:
        home = os.environ.get("HOME")
        cache = os.path.join(home, ".cache") if home else None
    return os.path.join(cache, "cmake-everywhere", "store") if cache else None


def size(path):
    total = 0
    for root, _, names in os.walk(path):
        for name in names:
            full = os.path.join(root, name)
            try:
                total += os.lstat(full).st_size
            except OSError:
                pass
    return total


def megabytes(count):
    return f"{count / (1024 * 1024):.1f} MiB"


def entries(store):
    """Every directory that is one level below a port's directory."""
    for port in sorted(os.listdir(store)):
        directory = os.path.join(store, port)
        if not os.path.isdir(directory):
            continue
        for leaf in sorted(os.listdir(directory)):
            yield port, leaf, os.path.join(directory, leaf)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("store", nargs="?", default=default_store())
    parser.add_argument("--unfinished", action="store_true",
                        help="the leavings of interrupted builds")
    parser.add_argument("--incomplete", action="store_true",
                        help="entries with no complete marker")
    parser.add_argument("--older-than", type=float, metavar="DAYS",
                        help="entries not read for this many days")
    parser.add_argument("--port", action="append", default=[],
                        help="only this library; may be repeated")
    parser.add_argument("--delete", action="store_true",
                        help="actually remove what is listed")
    arguments = parser.parse_args()

    if not arguments.store or not os.path.isdir(arguments.store):
        print(f"no store at {arguments.store}", file=sys.stderr)
        return 1
    if not (arguments.unfinished or arguments.incomplete or arguments.older_than):
        print("nothing asked for: name --unfinished, --incomplete or "
              "--older-than DAYS", file=sys.stderr)
        return 1

    now = time.time()
    doomed = []
    for port, leaf, path in entries(arguments.store):
        if arguments.port and port not in arguments.port:
            continue
        if leaf.startswith(".building-"):
            if arguments.unfinished:
                doomed.append((path, "unfinished"))
            continue
        complete = os.path.join(path, "complete")
        if not os.path.exists(complete):
            if arguments.incomplete:
                doomed.append((path, "no complete marker"))
            continue
        if arguments.older_than:
            try:
                read = os.stat(path).st_atime
            except OSError:
                continue
            days = (now - read) / 86400
            if days > arguments.older_than:
                doomed.append((path, f"last read {days:.0f} days ago"))

    total = 0
    for path, why in doomed:
        bytes_here = size(path)
        total += bytes_here
        print(f"{megabytes(bytes_here):>12}  {why:<24}  {path}")
        if arguments.delete:
            shutil.rmtree(path, ignore_errors=True)
    verb = "removed" if arguments.delete else "would remove"
    print(f"{verb} {len(doomed)} of them, {megabytes(total)}")
    if not arguments.delete and doomed:
        print("nothing was deleted; pass --delete", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
