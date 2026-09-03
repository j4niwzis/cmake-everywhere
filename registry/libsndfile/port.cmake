# Missing upstream: dependencies resolved rather than assumed. libsndfile looks
# for four libraries with find_package and cannot be handed any of them.
cme_declare_port(
  NAME libsndfile
  PROVIDES SndFile sndfile SNDFILE
  VERSION 1.2.2
  GITHUB_REPOSITORY libsndfile/libsndfile
  GIT_TAG 1.2.2
  DEPENDS ogg vorbis flac opus
  OPTIONS
    "BUILD_PROGRAMS OFF"
    "BUILD_EXAMPLES OFF"
    "BUILD_TESTING OFF"
    "ENABLE_EXTERNAL_LIBS ON"
    "ENABLE_MPEG OFF"
    "ENABLE_CPACK OFF"
  SYSTEM_PKGCONFIG "sndfile:SndFile::sndfile"
)

# One find_package(SndFile) brings ogg, vorbis, FLAC and opus with it,
# because libsndfile asks for them itself and those calls arrive here.
function(cme_adapt_libsndfile source binary)
  cme_alias(SndFile::sndfile sndfile)
  cme_export_variable(SndFile SndFile_FOUND TRUE)
  cme_export_variable(SndFile SNDFILE_FOUND TRUE)
  cme_export_variable(SndFile SNDFILE_LIBRARY SndFile::sndfile)
  cme_export_variable(SndFile SNDFILE_LIBRARIES SndFile::sndfile)
  cme_export_variable(SndFile SNDFILE_INCLUDE_DIR
    "${source}/include;${binary}/include")
  cme_export_variable(SndFile SNDFILE_INCLUDE_DIRS
    "${source}/include;${binary}/include")
  cme_export_variable(SndFile SndFile_VERSION 1.2.2)
endfunction()
