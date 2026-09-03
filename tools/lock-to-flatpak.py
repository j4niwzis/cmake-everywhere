#!/usr/bin/env python3
"""Turn cme-lock.json into the sources a Flatpak build fetches.

    python3 tools/lock-to-flatpak.py cme-lock.json \
        --sources flatpak/cme-sources.json --ports flatpak/cme-ports

A flatpak-builder module has no network. Everything it uses is declared in
the manifest, fetched by flatpak-builder, and checked against a digest before
the build starts -- which is the same list the lock already holds, written in
another spelling.

Two files come out, because a source that arrives is only half of it:

  --sources   a list of flatpak sources, one per library, each with the URL
              and the digest or commit the lock names, landing under a
              directory of its own. A module's `sources` may name a file like
              this instead of listing everything inline.

  --ports     a directory of port declarations, one per library, each saying
              only where its sources are. Pass it as CME_OVERLAYS: an overlay
              is read before the registry, so this says where to look and the
              registry still says what the library is and how it is built.

The second file is what makes this work at all. Offline mode alone is not
enough: it means "do not fetch", and a build that may not fetch and has not
been told where anything is has nothing to read. Naming a directory per port
is this project's own mechanism -- the same one a checkout of skiff is passed
through -- rather than an arrangement of somebody else's cache.
"""
import argparse
import json
import os
import sys


def entries(lock):
    """What the lock says was fetched, as (port, url, commit, digest)."""
    for port, facts in sorted(lock.get("ports", {}).items()):
        url = facts.get("url")
        if not url:
            # A port answered by the system, or a name for other ports.
            # Nothing was fetched for it and nothing has to be.
            continue
        digest = facts.get("archive", "")
        digest = digest.split("=", 1)[1] if "=" in digest else digest
        yield port, url, facts.get("commit"), digest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("lock")
    parser.add_argument("--sources", required=True,
                        help="where to write the list of flatpak sources")
    parser.add_argument("--ports", required=True,
                        help="a directory to write port declarations into")
    parser.add_argument("--dest", default=".flatpak-sources/ports",
                        help="where flatpak-builder puts them, inside the "
                             "module's build directory")
    parser.add_argument("--prefix", default="/run/build/osu-cpp",
                        help="the module's build directory, as the build "
                             "sees it")
    arguments = parser.parse_args()

    with open(arguments.lock) as file:
        lock = json.load(file)

    written = []
    incomplete = []
    for port, url, commit, digest in entries(lock):
        where = f"{arguments.dest}/{port}"
        if commit:
            written.append({"type": "git", "url": url, "commit": commit,
                            "dest": where})
        elif digest:
            written.append({"type": "archive", "url": url, "sha256": digest,
                            "dest": where})
        else:
            # A URL with neither a commit nor a digest is not something to
            # write into a manifest: flatpak-builder would fetch whatever is
            # there today. Said here rather than written out.
            incomplete.append(port)
            continue
        directory = os.path.join(arguments.ports, port)
        os.makedirs(directory, exist_ok=True)
        with open(os.path.join(directory, "port.cmake"), "w") as file:
            file.write(
                "# Written by tools/lock-to-flatpak.py. Where this library's\n"
                "# sources are in a build that may not fetch. What the\n"
                "# library is, and how it is built, the registry still says.\n"
                f'cme_declare_port(\n  NAME {port}\n'
                f'  SOURCE_DIR "{arguments.prefix}/{where}")\n')

    os.makedirs(os.path.dirname(arguments.sources) or ".", exist_ok=True)
    with open(arguments.sources, "w") as file:
        json.dump(written, file, indent=2)
        file.write("\n")

    print(f"{len(written)} sources, {len(written)} ports", file=sys.stderr)
    for port in incomplete:
        print(f"  {port}: a URL with no commit and no digest, left out",
              file=sys.stderr)
    return 1 if incomplete else 0


if __name__ == "__main__":
    sys.exit(main())
