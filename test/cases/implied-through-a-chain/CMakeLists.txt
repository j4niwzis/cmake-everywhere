# Whether an implication follows a chain, asked in the only way that can be
# checked without building anything: refuse the far end of it.
#
# chain-a implies chain-b implies chain-c. Nothing here mentions chain-b or
# chain-c except the refusal, so if the build stops saying it refuses chain-c,
# the chain was followed both links; and if it configures, it was not.
cmake_minimum_required(VERSION 3.24)
project(implied-through-a-chain LANGUAGES NONE)
cme_features(alpha chain-a -chain-c)
find_package(Alpha)
