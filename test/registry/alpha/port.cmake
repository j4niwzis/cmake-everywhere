# A library that does not exist, for testing the parts that are decided
# before anything is fetched. Every error these cases are about is raised
# while the graph is being walked, so the repository below is never reached.
cme_declare_port(
  NAME alpha
  PROVIDES Alpha alpha
  VERSION 1.0.0
  GITHUB_REPOSITORY nobody/alpha
  GIT_TAG v1.0.0
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE GPL-3.0-only
  DEPENDS "beta[x]"
)

cme_port_feature(alpha one SUMMARY "one way of doing it")
cme_port_feature(alpha two SUMMARY "the other way")
cme_port_feature(alpha both SUMMARY "asks for both ways at once" IMPLIES one two)
cme_port_feature(alpha needs-delta SUMMARY "wants something that is not here"
  DEPENDS delta)

cme_port_rule(alpha AT_MOST_ONE_OF one two)

function(cme_adapt_alpha source binary)
endfunction()

# Three links, for asking whether an implication follows a chain: chain-a
# implies chain-b, which implies chain-c, and nothing else says a word about
# chain-c.
cme_port_feature(alpha chain-a SUMMARY "the first link" IMPLIES chain-b)
cme_port_feature(alpha chain-b SUMMARY "the second link" IMPLIES chain-c)
cme_port_feature(alpha chain-c SUMMARY "the third link")
