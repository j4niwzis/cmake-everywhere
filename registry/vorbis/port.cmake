# Missing upstream: dependencies resolved rather than assumed. libvorbis calls
# find_package(Ogg) and cannot be handed one.
cme_declare_port(
  NAME vorbis
  PROVIDES Vorbis vorbis VORBIS
  VERSION 1.3.7
  GITHUB_REPOSITORY xiph/vorbis
  GIT_TAG v1.3.7
  DEPENDS ogg
  SYSTEM_PKGCONFIG
    "vorbis:Vorbis::vorbis"
    "vorbisenc:Vorbis::vorbisenc"
    "vorbisfile:Vorbis::vorbisfile"
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE BSD-3-Clause
  # What this library answers to when something asks the linker for it by
  # name. A bare -l finds whatever is installed; a target is an archive
  # with a path.
  LINK_NAMES
    "vorbis=Vorbis::vorbis"
    "vorbisenc=Vorbis::vorbisenc"
    "vorbisfile=Vorbis::vorbisfile"
  # What a consumer links. Said here so that something other than a
  # human can check that the port still produces it.
  TARGETS Vorbis::vorbis Vorbis::vorbisenc Vorbis::vorbisfile
  CHECK_HEADER vorbis/codec.h
)

function(cme_adapt_vorbis source binary)
  # libvorbis builds vorbis, vorbisenc and vorbisfile and gives them their
  # Vorbis:: names only in the config file it installs, which a build tree
  # does not have. libsndfile links Vorbis::vorbisenc, so they are made here.
  cme_alias(Vorbis::vorbis vorbis)
  cme_alias(Vorbis::vorbisenc vorbisenc)
  cme_alias(Vorbis::vorbisfile vorbisfile)
  cme_export_variable(Vorbis VORBIS_FOUND TRUE)
  cme_export_variable(Vorbis Vorbis_Vorbis_FOUND TRUE)
  cme_export_variable(Vorbis Vorbis_Enc_FOUND TRUE)
  cme_export_variable(Vorbis Vorbis_File_FOUND TRUE)
  cme_export_variable(Vorbis VORBIS_LIBRARIES
    "Vorbis::vorbis;Vorbis::vorbisenc;Vorbis::vorbisfile")
  cme_export_variable(Vorbis VORBIS_INCLUDE_DIR "${source}/include")
  cme_export_variable(Vorbis VORBIS_INCLUDE_DIRS "${source}/include")
  cme_export_variable(Vorbis VORBIS_VERSION 1.3.7)
endfunction()
