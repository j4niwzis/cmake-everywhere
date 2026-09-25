# Whether a feature of a name that builds nothing reaches the pieces it stands
# for, asked without building anything: refuse it on the piece.
#
# family is virtual and has a modules feature, which only a piece can act on.
# Asked for as Family COMPONENTS part[modules], the piece must be asked for
# modules too -- so refusing modules on family-part stops the build, saying
# so; and if it configures, modules stayed with the name.
cmake_minimum_required(VERSION 3.24)
project(handed-down LANGUAGES NONE)
cme_features(family-part -modules)
find_package(Family REQUIRED COMPONENTS part[modules])
