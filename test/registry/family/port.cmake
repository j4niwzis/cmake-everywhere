# A library cut into pieces and asked for by one name, as Boost is: the name
# builds nothing, and each piece is a port of its own.
cme_declare_port(
  NAME family
  PROVIDES Family family
  VERSION 1.0.0
  VIRTUAL YES
  LICENSE GPL-3.0-only
  TARGETS Family::family
)

# How the pieces are built, which only means something in the pieces.
cme_port_feature(family modules SUMMARY "every piece built as a module"
  OPTIONS "FAMILY_USE_MODULES ON")
# A piece, asked for as a component.
cme_port_feature(family part SUMMARY "the part" DEPENDS family-part)
