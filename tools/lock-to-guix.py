#!/usr/bin/env python3
"""Turn cme-lock.json into Guix origins.

    python3 tools/lock-to-guix.py cme-lock.json > sources.scm

The same list as the Nix generator writes, in the other spelling. Guix wants
the digest of the *contents* rather than of the archive for a git checkout,
and nothing but fetching produces that -- so a repository comes out with the
place to put it and a note saying which command says what to put there, and
an archive comes out complete, because the lock has its digest.

A generated file that filled that in with a plausible-looking string would
be worse than one that says it does not know.
"""
import json
import os
import subprocess
import sys
import tempfile

# Nix's base32, which Guix uses too: an alphabet without the letters that
# are read wrong out loud, and bits taken from the end.
ALPHABET = "0123456789abcdfghijklmnpqrsvwxyz"


def base32(hexadecimal):
    data = bytes.fromhex(hexadecimal)
    length = (len(data) * 8 - 1) // 5 + 1
    out = []
    for index in reversed(range(length)):
        bit = index * 5
        byte, offset = divmod(bit, 8)
        value = data[byte] >> offset
        if byte + 1 < len(data):
            value |= data[byte + 1] << (8 - offset)
        out.append(ALPHABET[value & 0x1F])
    return "".join(out)


def checkout(cache, port):
    """Where a fetched source is, if this machine has fetched it."""
    if not cache:
        return None
    root = os.path.join(cache, port)
    if not os.path.isdir(root):
        return None
    inside = [os.path.join(root, name) for name in sorted(os.listdir(root))]
    inside = [name for name in inside if os.path.isdir(name)]
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


def extension(url):
    """What the file is, when the URL says so.

    A name without one reaches Guix's unpacker as a name it cannot read, and
    the answer is not to guess: a URL that ends in nothing recognisable gets
    no extension here and the archive keeps whatever name the fetch gave it.
    """
    for suffix in (".tar.gz", ".tar.xz", ".tar.bz2", ".tar.zst", ".tgz",
                   ".zip", ".tar"):
        if url.endswith(suffix):
            return suffix
    return ""


def main(path, cache=None):
    with open(path) as file:
        lock = json.load(file)
    print(f";; Written by tools/lock-to-guix.py from {path}.")
    print(";; Every one of these is a fact the lock is already holding the "
          "build to.")
    print(";;")
    print(";; A list of (port version origin): the name is what the port is")
    print(";; called, so a package can name the input after it and write the")
    print(";; declaration that says where its sources landed.")
    print("(list")
    for port, facts in sorted(lock.get("ports", {}).items()):
        url = facts.get("url")
        if not url:
            continue
        version = facts.get("version", "")
        if facts.get("commit"):
            # The digest of the contents, which is not the commit and not
            # the archive: it comes from the checkout, so it can be filled
            # in here only when this machine has one.
            where = checkout(cache, port)
            digest = contents(where, facts.get("commit")) if where else ""
            print(f'  (list "{port}" "{version}"')
            print(f'    (origin')
            print(f'      (method git-fetch)')
            print(f'      (uri (git-reference (url "{url}")')
            print(f'                          (commit "{facts["commit"]}")))')
            print(f'      (file-name "{port}-{version}-checkout")')
            if not digest:
                print(f'      ;; guix hash -rx . in a checkout of that commit,')
                print(f'      ;; or run this again with the source cache')
            print(f'      (sha256 (base32 "{digest}"))))')
        elif facts.get("archive"):
            stated = facts["archive"]
            algorithm, _, digest = stated.rpartition("=")
            # In lowercase, because the lock spells it the way CMake does
            # and Guix reads content-hash algorithms in lowercase: given
            # SHA512 it says the expression matched no pattern.
            algorithm = (algorithm or "sha256").lower()
            try:
                encoded = base32(digest)
            except ValueError:
                print(f'  ;; {port}: {stated} is not a digest in hexadecimal')
                continue
            print(f'  (list "{port}" "{version}"')
            print(f'    (origin')
            print(f'      (method url-fetch)')
            print(f'      (uri "{url}")')
            print(f'      (file-name "{port}-{version}{extension(url)}")')
            if algorithm == "sha256":
                print(f'      (sha256 (base32 "{encoded}"))))')
            else:
                # (sha256 ...) is the short way of saying the usual one,
                # and it is a claim about the algorithm as well as the
                # value: a sha512 put there is refused for its length.
                # content-hash says which algorithm, and reads the same
                # base32 -- not the hexadecimal the lock holds, which it
                # takes for base32 and stops at the first e.
                print(f'      (hash (content-hash "{encoded}" {algorithm}))))')
        else:
            print(f'  ;; {port}: neither a commit nor a digest in the lock')
    print("  )")


if __name__ == "__main__":
    # tools/lock-to-guix.py cme-lock.json [the CPM source cache]
    main(sys.argv[1] if len(sys.argv) > 1 else "cme-lock.json",
         sys.argv[2] if len(sys.argv) > 2 else os.environ.get("CPM_SOURCE_CACHE"))
