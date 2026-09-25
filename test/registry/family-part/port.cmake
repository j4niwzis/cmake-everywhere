# One piece of family, which says for itself how it can be built.
cme_declare_port(
  NAME family-part
  PROVIDES family_part
  VERSION 1.0.0
  FAMILY family
  GITHUB_REPOSITORY nobody/family-part
  GIT_TAG v1.0.0
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE GPL-3.0-only
  TARGETS Family::part
)

cme_port_feature(family-part modules SUMMARY "built as a module"
  OPTIONS "FAMILY_USE_MODULES ON")

function(cme_adapt_family-part source binary)
endfunction()
