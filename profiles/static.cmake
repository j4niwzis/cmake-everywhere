# One file, and nothing outside it.
#
# Everything a program needs is built here and linked into it: no library
# comes from the machine, and nothing is opened at run time. That is what
# makes a binary that runs on a machine which has neither the libraries it
# was built against nor the loader that would find them -- and it is also
# what makes the graphics drivers this program draws through part of the
# program, since a driver is a shared object and a static program cannot
# open one.
#
# What this profile says is only the part that belongs to the provider. The
# rest -- which drivers, which window systems -- is what the project asks
# for, because the project is what knows.
set(CME_SYSTEM "NEVER" CACHE STRING "" FORCE)

# A shared library is a file to be found again at run time, and there will
# be nothing to find it with. Some libraries decide otherwise for
# themselves; this is said once, here, so that they are all told.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
