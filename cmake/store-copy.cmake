# A directory copied into a store entry, with its links followed.
#
# file(COPY) copies a symbolic link as a link. That is right for a tree that
# stays where it is, and wrong for an entry, which is kept to be used where
# the tree it came from is not -- another machine, another container,
# another module of a Flatpak build. And the trees an entry keeps have links
# in them on purpose: cme_header_prefix offers a library's headers under the
# name its consumers use by linking to where they are, and a copy of that
# link points back into a source tree the entry was meant not to need. The
# consumer is handed a link to nowhere and reports the header missing: Skia,
# kept by one Flatpak module and used by the next, offered skia/ as a link
# into a directory the second module does not have.
#
# So the tree is copied as it is, which is quick, and every link in the copy
# is then replaced by what it pointed at when it was copied. A link to
# nothing is left out, as file(COPY) would have left it useless.
function(cme_store_copy from to)
  file(COPY "${from}/" DESTINATION "${to}"
       PATTERN "CMakeFiles" EXCLUDE PATTERN ".git" EXCLUDE)
  file(GLOB_RECURSE entries LIST_DIRECTORIES true "${to}/*")
  foreach(entry IN LISTS entries)
    if(NOT IS_SYMLINK "${entry}")
      continue()
    endif()
    # Where it led in the tree that was copied, not in the copy: a relative
    # link means the same thing in both, an absolute one names the original.
    file(RELATIVE_PATH inside "${to}" "${entry}")
    get_filename_component(real "${from}/${inside}" REALPATH)
    file(REMOVE "${entry}")
    if(IS_DIRECTORY "${real}")
      cme_store_copy("${real}" "${entry}")
    elseif(EXISTS "${real}")
      file(COPY_FILE "${real}" "${entry}")
    endif()
  endforeach()
endfunction()
