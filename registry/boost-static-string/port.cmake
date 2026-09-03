# Written by tools/boost-ports.py from what boostorg/static_string
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-static-string
  PROVIDES boost_static_string BoostStaticString
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_static_string
  TARGETS Boost::static_string
  DEPENDS boost-assert boost-container-hash boost-core boost-headers boost-throw-exception boost-utility
)

function(cme_adapt_boost-static-string source binary)
  get_target_property(target Boost::static_string ALIASED_TARGET)
  if(NOT target)
    set(target Boost::static_string)
  endif()
  target_link_libraries(${target} INTERFACE Boost::utility)
endfunction()

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-static-string
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/static_string)
else()
  cme_port_source(boost-static-string
    GITHUB_REPOSITORY boostorg/static_string
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
