# Depends on a port that is not in the registry, which is a mistake a
# registry should report rather than trip over.
cme_declare_port(
  NAME delta
  PROVIDES Delta delta
  VERSION 1.0.0
  GITHUB_REPOSITORY nobody/delta
  GIT_TAG v1.0.0
  LICENSE MIT
  DEPENDS nosuchport
)

function(cme_adapt_delta source binary)
endfunction()
