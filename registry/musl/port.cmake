# The C library, built here rather than taken from the machine.
#
# A program that carries everything carries this too: it is the largest
# thing a "static" binary usually still borrows, and borrowing it means the
# build depends on which musl the machine happens to have. Built here it is
# a pinned revision like every other library, compiled with this build's own
# flags -- which is also what lets the optimiser see across the boundary
# between a program and the calls it makes for memory and strings.
#
# Its configure script is its own, not autotools, and what it produces is a
# prefix: headers, libc.a, and the three object files a program starts and
# ends with.
cme_declare_port(
  NAME musl
  PROVIDES musl
  VERSION 1.2.6
  GIT_REPOSITORY https://git.musl-libc.org/git/musl
  GIT_TAG v1.2.6
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  INSTALLED_TARGETS "lib/libc.a=musl::c"
  INSTALLED_INCLUDE include
  TARGETS musl::c
  CHECK_HEADER stdio.h
  # Static only, and no shared loader: a program that links this has no use
  # for the one and cannot use the other.
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--disable-wrapper"
  CONFIGURE_CROSS "--target=@TRIPLE@"
)

# Compiled so that the optimiser can look through it.
#
# Off by default, and not out of doubt about the idea: musl is written with
# weak symbols, aliases and hand-placed sections, and an optimiser that sees
# all of it at once is a thing musl's own packagers do not do. So it is a
# switch, thrown once everything else in a build works, so that what breaks
# after throwing it is known to be this.
cme_port_feature(musl whole-program
  SUMMARY "compile the C library so the optimiser can see through it"
  CONFIGURE_ARGS "CFLAGS=-flto=full")
