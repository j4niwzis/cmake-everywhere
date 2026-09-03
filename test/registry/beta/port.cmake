cme_declare_port(
  NAME beta
  PROVIDES Beta beta
  VERSION 1.0.0
  GITHUB_REPOSITORY nobody/beta
  GIT_TAG v1.0.0
  LICENSE MIT
)

cme_port_feature(beta x SUMMARY "the thing alpha needs from it")

function(cme_adapt_beta source binary)
endfunction()
