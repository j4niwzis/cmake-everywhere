# Written by tools/boost-ports.py from what boostorg/program_options
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-program-options
  PROVIDES boost_program_options BoostProgramOptions
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_program_options
  TARGETS Boost::program_options
  DEPENDS boost-any boost-bind boost-config boost-core boost-detail boost-function boost-iterator boost-lexical-cast boost-smart-ptr boost-throw-exception boost-tokenizer boost-type-traits
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-program-options
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/program_options)
else()
  cme_port_source(boost-program-options
    GITHUB_REPOSITORY boostorg/program_options
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
