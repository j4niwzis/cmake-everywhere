# Missing upstream: nothing that stops it building. Oboe is Android's, and
# this port exists so that something can ask for it by name and so that
# OpenAL Soft can be handed one.
cme_declare_port(
  NAME oboe
  PROVIDES oboe Oboe OBOE
  VERSION 1.9.0
  GITHUB_REPOSITORY google/oboe
  GIT_TAG 1.9.0
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE Apache-2.0
  # Oboe is Android's, and its build says so: it compiles with warning flags
  # only Clang has. Asking for it anywhere else is a mistake worth catching
  # at the point it is made rather than at the first flag the compiler does
  # not know.
  SYSTEMS Android
  LINK_NAMES "oboe=oboe::oboe"
  TARGETS oboe::oboe
  OPTIONS
    "BUILD_TESTING OFF"
)

function(cme_adapt_oboe source binary)
  cme_alias(oboe::oboe oboe)
  cme_export_variable(oboe OBOE_FOUND TRUE)
  cme_export_variable(oboe OBOE_LIBRARY oboe::oboe)
  cme_export_variable(oboe OBOE_LIBRARIES oboe::oboe)
  cme_export_variable(oboe OBOE_INCLUDE_DIR "${source}/include")
  cme_export_variable(oboe OBOE_INCLUDE_DIRS "${source}/include")
endfunction()
