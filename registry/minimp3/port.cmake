# A library with no build system at all: minimp3 is a header that compiles
# itself into whatever includes it with one macro defined.
#
# Upstream publishes no releases, so this names a commit. A branch would work
# and would also make every configure of every project re-fetch it, because a
# moving ref has to be checked -- which is what the update step in the log
# was. A commit is checked once.
cme_declare_port(
  NAME minimp3
  PROVIDES minimp3 MiniMP3
  VERSION 0.0.0
  GITHUB_REPOSITORY lieff/minimp3
  GIT_TAG ea99364f61c14656440e8d77e9c233ccf3124633
  OVERLAY overlay
  LICENSE CC0-1.0
  # What a consumer links. Said here so that something other than a
  # human can check that the port still produces it.
  TARGETS minimp3::minimp3
)

function(cme_adapt_minimp3 source binary)
  cme_export_variable(minimp3 MINIMP3_FOUND TRUE)
  cme_export_variable(minimp3 MINIMP3_LIBRARY minimp3::minimp3)
  cme_export_variable(minimp3 MINIMP3_LIBRARIES minimp3::minimp3)
  cme_export_variable(minimp3 MINIMP3_INCLUDE_DIR "${source}")
  cme_export_variable(minimp3 MINIMP3_INCLUDE_DIRS "${source}")
endfunction()
