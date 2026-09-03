# A library with no build system at all: minimp3 is a header that compiles
# itself into whatever includes it with one macro defined. Upstream publishes
# no releases either, so the tag here is a branch -- a port meant for
# reproducible builds should carry a commit instead, and this one says so
# rather than pretending.
cme_declare_port(
  NAME minimp3
  PROVIDES minimp3 MiniMP3
  VERSION 0.0.0
  GITHUB_REPOSITORY lieff/minimp3
  GIT_TAG master
  OVERLAY overlay
)

function(cme_adapt_minimp3 source binary)
  cme_export_variable(minimp3 MINIMP3_FOUND TRUE)
  cme_export_variable(minimp3 MINIMP3_LIBRARY minimp3::minimp3)
  cme_export_variable(minimp3 MINIMP3_LIBRARIES minimp3::minimp3)
  cme_export_variable(minimp3 MINIMP3_INCLUDE_DIR "${source}")
  cme_export_variable(minimp3 MINIMP3_INCLUDE_DIRS "${source}")
endfunction()
