#!/usr/bin/env python3
"""Turn cme-lock.json into the sources a Nix build fetches.

    python3 tools/lock-to-nix.py cme-lock.json > sources.nix

A sandboxed build has no network, so what a build fetches has to be fetched
by whatever is running the sandbox. The lock already says what was fetched
and from where, exactly and by digest, which is the same list Nix needs -- so
it is written out rather than kept twice by hand.

What comes out is an attribute set of derivations, one per library:

    { pkgs ? import <nixpkgs> {} }:
    {
      zlib = pkgs.fetchurl { url = "..."; sha256 = "..."; };
      hello = builtins.fetchGit { url = "..."; rev = "6f1c..."; };
    }

builtins.fetchGit for a repository, because a full revision pins it and no
separate hash is needed; fetchurl for an archive, whose digest the lock has.
"""
import json
import os
import subprocess
import sys
import tempfile


def sources(lock):
    for port, facts in sorted(lock.get("ports", {}).items()):
        url = facts.get("url")
        if not url:
            # Nothing to fetch: a port answered by the system, or one that
            # is a name for other ports.
            continue
        digest = facts.get("archive", "")
        digest = digest.split("=", 1)[1] if "=" in digest else digest
        yield port, url, facts.get("commit"), digest, facts.get("version", "")


def checkout(cache, port):
    if not cache:
        return None
    root = os.path.join(cache, port)
    if not os.path.isdir(root):
        return None
    inside = [os.path.join(root, name) for name in sorted(os.listdir(root))
              if os.path.isdir(os.path.join(root, name))]
    return inside[0] if len(inside) == 1 else None


def contents(directory, commit=None):
    """The digest of what a commit is, not of what a directory happens to
    hold.

    A checkout is a working tree: it has whatever the fetching left in it
    besides the commit, and what a fetcher elsewhere produces is the commit.
    So the commit is materialised into a directory of its own and that is
    hashed. Otherwise the digest names something only this machine has, which
    is exactly what happened: Nix fetched, hashed, and disagreed.

    Through an index file of its own rather than `git archive`, which applies
    the export-ignore rules in .gitattributes -- so an archive of a
    repository that has any is not what a checkout of it is, and a digest
    taken from one would be wrong for the other in a way nothing would
    notice.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    with tempfile.TemporaryDirectory() as clean:
        target = directory
        if commit and os.path.isdir(os.path.join(directory, ".git")):
            tree = os.path.join(clean, "tree")
            os.makedirs(tree)
            environment = dict(os.environ, GIT_INDEX_FILE=os.path.join(clean, "index"))
            read = subprocess.run(["git", "-C", directory, "read-tree", commit],
                                  env=environment, capture_output=True)
            wrote = subprocess.run(
                ["git", "-C", directory, "checkout-index", "--all", "--force",
                 "--prefix=" + tree + os.sep],
                env=environment, capture_output=True)
            if read.returncode == 0 and wrote.returncode == 0:
                target = tree
            else:
                print(f"  ;; cannot materialise {commit} in {directory}",
                      file=sys.stderr)
        answer = subprocess.run(
            [sys.executable, os.path.join(here, "nar-hash.py"), target],
            capture_output=True, text=True)
    return answer.stdout.strip() if answer.returncode == 0 else ""


def main(path, cache=None):
    with open(path) as file:
        lock = json.load(file)
    print("# Written by tools/lock-to-nix.py from " + path + ".")
    print("# Every one of these is a fact the lock is already holding the "
          "build to.")
    print("{ pkgs ? import <nixpkgs> { } }:")
    print("{")
    for port, url, commit, digest, version in sources(lock):
        name = port.replace("-", "_")
        if commit:
            # fetchgit when the digest of the contents can be had, because
            # that is what a fixed-output derivation is; builtins.fetchGit
            # otherwise, which needs no digest because a full revision pins
            # it, and is the honest answer when nothing here has a checkout.
            where = checkout(cache, port)
            digest = contents(where, commit) if where else ""
            if digest:
                print(f'  {name} = pkgs.fetchgit {{')
                print(f'    url = "{url}";')
                print(f'    rev = "{commit}";')
                print(f'    sha256 = "{digest}";')
                print(f'  }};  # {version}')
            else:
                print(f'  {name} = builtins.fetchGit {{')
                print(f'    url = "{url}";')
                print(f'    rev = "{commit}";')
                print(f'  }};  # {version}')
        elif digest:
            print(f'  {name} = pkgs.fetchurl {{')
            print(f'    url = "{url}";')
            print(f'    sha256 = "{digest}";')
            print(f'  }};  # {version}')
        else:
            # Said rather than skipped: a source with neither a commit nor a
            # digest is one this lock cannot pin, and a generated file that
            # quietly leaves it out would be a list that looks complete.
            print(f'  # {name}: {url} is in the build and the lock has '
                  f'neither a commit nor a digest for it')
    print("}")


if __name__ == "__main__":
    # tools/lock-to-nix.py cme-lock.json [the CPM source cache]
    main(sys.argv[1] if len(sys.argv) > 1 else "cme-lock.json",
         sys.argv[2] if len(sys.argv) > 2 else os.environ.get("CPM_SOURCE_CACHE"))
