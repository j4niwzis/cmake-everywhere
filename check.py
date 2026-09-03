"""Every cme_ command that is called has to be defined somewhere.

Written after an edit removed a function and left its calls behind: the
configure that found it had already fetched Skia and run gn, which is a long
way to go to be told about a typo.
"""
import glob, re, sys

defined = set()
called = {}
files = (["cmake-everywhere.cmake", "cmake/gn.cmake"]
         + sorted(glob.glob("registry/*/*.cmake"))
         + sorted(glob.glob("test/registry/*/*.cmake"))
         + sorted(glob.glob("profiles/*.cmake")))
for path in files:
    text = re.sub(r"#[^\n]*", "", open(path).read())
    defined |= set(re.findall(r"(?:function|macro)\(\s*(cme_[A-Za-z0-9_]+)", text))
    for name in re.findall(r"\b(cme_[A-Za-z0-9_]+)\s*\(", text):
        called.setdefault(name, path)

problems = 0
for name, where in sorted(called.items()):
    if name not in defined:
        print(f"  called and never defined: {name}  ({where})")
        problems += 1
for path in files:
    text = re.sub(r"#[^\n]*", "", open(path).read())
    if text.count("(") != text.count(")"):
        print(f"  unbalanced parentheses: {path}")
        problems += 1
print(f"{len(defined)} commands defined, {len(called)} called, {problems} problems")
sys.exit(1 if problems else 0)
