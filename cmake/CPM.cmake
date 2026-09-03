# SPDX-License-Identifier: MIT
#
# SPDX-FileCopyrightText: Copyright (c) 2019-2023 Lars Melchior and contributors
#
# CPM.cmake itself, beside this file rather than downloaded when a build
# starts.
#
# It used to be fetched from a release, with its digest checked, which is the
# right way to fetch a thing and the wrong thing to do at all: a build that
# cannot reach the network could not begin, and the first configure in a
# sandbox failed on a file that had nothing to do with what was being built.
# It is forty-five kilobytes of MIT-licensed CMake and this repository is the
# place it is needed, so it is here.
#
# CPM_0.42.1.cmake is the release file, unmodified, sha256
# f3a6dcc6a04ce9e7f51a127307fa4f699fb2bade357a8eb4c5b45df76e1dc6a5. Changing
# versions means putting the new one beside this and changing the name here,
# which is a smaller thing than it was to change a version and a digest.
include("${CMAKE_CURRENT_LIST_DIR}/CPM_0.42.1.cmake")
