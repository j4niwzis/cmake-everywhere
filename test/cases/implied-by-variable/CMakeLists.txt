# The same conflict, reached the other way round.
#
# cme_features() and -DCME_FEATURES_<port>= are not the components of a
# find_package call and do not go through the same code, so a feature that
# implies others has to bring them here too. alpha's "both" implies one and
# two, and the port says at most one of those -- so if the implications are
# expanded, this is refused, and if they are not, it configures happily with
# a feature set the port forbids.
cmake_minimum_required(VERSION 3.24)
project(implied-by-variable LANGUAGES NONE)
cme_features(alpha both)
find_package(Alpha)
