#!/usr/bin/env python3
"""The hash Nix and Guix name a directory by.

    python3 tools/nar-hash.py <directory>

Both of them identify a fetched source by the digest of its *contents*, not
of the archive it arrived in and not of the commit it was cut from -- so
neither a git revision nor a tarball digest can be turned into one. It is the
sha256 of the directory serialised the way Nix serialises directories, which
is a small and fixed format: lengths, then bytes, padded to eight.

Written here because the alternative is to leave a hole in a generated file
and ask a person to run `guix hash -rx .` a hundred and fifty-eight times.
Checked against `nix hash path`, which is the thing it is imitating -- an
implementation of somebody else's format that nobody compares to theirs is a
plausible-looking string, and a plausible-looking hash is the worst kind of
wrong answer.
"""
import hashlib
import os
import stat
import sys

ALPHABET = "0123456789abcdfghijklmnpqrsvwxyz"


class Nar:
    def __init__(self):
        self.hash = hashlib.sha256()

    def raw(self, data):
        self.hash.update(data)

    def string(self, value):
        if isinstance(value, str):
            value = value.encode()
        self.raw(len(value).to_bytes(8, "little"))
        self.raw(value)
        if len(value) % 8:
            self.raw(b"\0" * (8 - len(value) % 8))

    # A checkout has a .git in it and what was fetched does not: nix's
    # fetchgit and guix's `hash -rx` both hash the tree without it, so a
    # digest that included it would name something nobody has.
    SKIP = {".git"}

    def node(self, path):
        self.string("(")
        mode = os.lstat(path).st_mode
        if stat.S_ISLNK(mode):
            self.string("type")
            self.string("symlink")
            self.string("target")
            self.string(os.readlink(path))
        elif stat.S_ISDIR(mode):
            self.string("type")
            self.string("directory")
            # By name, as bytes: the order is part of what is being hashed.
            names = [n for n in os.listdir(path) if n not in self.SKIP]
            for name in sorted(names, key=lambda n: n.encode()):
                self.string("entry")
                self.string("(")
                self.string("name")
                self.string(name)
                self.string("node")
                self.node(os.path.join(path, name))
                self.string(")")
        else:
            self.string("type")
            self.string("regular")
            if mode & stat.S_IXUSR:
                self.string("executable")
                self.string("")
            self.string("contents")
            with open(path, "rb") as file:
                contents = file.read()
            self.string(contents)
        self.string(")")


def base32(digest):
    length = (len(digest) * 8 - 1) // 5 + 1
    out = []
    for index in reversed(range(length)):
        bit = index * 5
        byte, offset = divmod(bit, 8)
        value = digest[byte] >> offset
        if byte + 1 < len(digest):
            value |= digest[byte + 1] << (8 - offset)
        out.append(ALPHABET[value & 0x1F])
    return "".join(out)


def nar_hash(path):
    nar = Nar()
    nar.string("nix-archive-1")
    nar.node(path)
    return nar.hash.digest()


def main(path):
    print(base32(nar_hash(path)))


if __name__ == "__main__":
    main(sys.argv[1])
