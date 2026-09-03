cmake_minimum_required(VERSION 3.24)
project(unknown-feature LANGUAGES NONE)
# COMPONENTS in a find_package call can be somebody else's word for their own
# parts, so a name that is not a feature here is answered rather than
# refused. cme_features is unambiguous: it is only ever about features.
cme_features(alpha nosuch)
find_package(Alpha)
