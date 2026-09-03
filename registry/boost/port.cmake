# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# Boost as one name, for the projects that write find_package(Boost) and name
# what they use as components. Every component is one of the ports beside
# this one, which is where the library actually comes from; this port is the
# name they are asked for by.
#
# It builds nothing itself. Asking for Boost and no components is asking for
# no Boost libraries, which is what Boost's own CMake does with an empty
# BOOST_INCLUDE_LIBRARIES.
# One download of everything instead of one repository each. Worth it from
# about the tenth Boost library a build uses, and the same libraries either
# way.
option(CME_BOOST_ARCHIVE
  "Take Boost as the one release archive rather than a repository per library"
  OFF)

cme_declare_port(
  NAME boost
  PROVIDES Boost boost
  VERSION 1.92.0
  VIRTUAL YES
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE Boost
  TARGETS Boost::boost
)

cme_port_feature(boost system
  SUMMARY "Boost.system"
  IMPLIES assert compat config throw_exception variant2 winapi
  DEPENDS boost-system)
cme_port_feature(boost multi_array
  SUMMARY "Boost.multi array"
  IMPLIES array assert concept_check config core functional iterator mpl type_traits
  DEPENDS boost-multi-array)
cme_port_feature(boost math
  SUMMARY "Boost.math"
  IMPLIES assert concept_check config core integer lexical_cast predef random throw_exception
  DEPENDS boost-math)
cme_port_feature(boost smart_ptr
  SUMMARY "Boost.smart ptr"
  IMPLIES assert config core throw_exception
  DEPENDS boost-smart-ptr)
cme_port_feature(boost parameter
  SUMMARY "Boost.parameter"
  IMPLIES config core function fusion mp11 mpl optional preprocessor type_traits utility
  DEPENDS boost-parameter)
cme_port_feature(boost algorithm
  SUMMARY "Boost.algorithm"
  IMPLIES array assert bind concept_check config core exception function iterator mpl range regex throw_exception tuple type_traits unordered
  DEPENDS boost-algorithm)
cme_port_feature(boost any
  SUMMARY "Boost.any"
  IMPLIES config throw_exception type_index
  DEPENDS boost-any)
cme_port_feature(boost concept_check
  SUMMARY "Boost.concept check"
  IMPLIES config preprocessor type_traits
  DEPENDS boost-concept-check)
cme_port_feature(boost python
  SUMMARY "Boost.python"
  IMPLIES align bind config conversion core detail foreach function graph integer iterator lexical_cast mpl numeric_conversion preprocessor property_map smart_ptr tuple type_traits utility
  DEPENDS boost-python)
cme_port_feature(boost tti
  SUMMARY "Boost.tti"
  IMPLIES config function_types mpl preprocessor type_traits
  DEPENDS boost-tti)
cme_port_feature(boost functional
  SUMMARY "Boost.functional"
  IMPLIES config core function function_types mpl preprocessor type_traits typeof utility
  DEPENDS boost-functional)
cme_port_feature(boost config
  SUMMARY "Boost.config"
  DEPENDS boost-config)
cme_port_feature(boost log
  SUMMARY "Boost.log"
  IMPLIES align asio assert atomic bind config core date_time exception filesystem function_types fusion interprocess intrusive io iterator move mpl optional parameter phoenix predef preprocessor property_tree proto range regex smart_ptr spirit system thread throw_exception type_index type_traits utility winapi xpressive
  DEPENDS boost-log)
cme_port_feature(boost interprocess
  SUMMARY "Boost.interprocess"
  IMPLIES assert config container intrusive move winapi
  DEPENDS boost-interprocess)
cme_port_feature(boost exception
  SUMMARY "Boost.exception"
  IMPLIES assert config core smart_ptr throw_exception tuple type_traits
  DEPENDS boost-exception)
cme_port_feature(boost foreach
  SUMMARY "Boost.foreach"
  IMPLIES config core iterator mpl range type_traits
  DEPENDS boost-foreach)
cme_port_feature(boost spirit
  SUMMARY "Boost.spirit"
  IMPLIES array assert config core endian function function_types fusion integer io iterator move mpl optional phoenix pool preprocessor proto range smart_ptr thread throw_exception type_traits typeof unordered utility variant
  DEPENDS boost-spirit)
cme_port_feature(boost io
  SUMMARY "Boost.io"
  IMPLIES config
  DEPENDS boost-io)
cme_port_feature(boost units
  SUMMARY "Boost.units"
  IMPLIES assert config core integer io lambda math mpl preprocessor type_traits typeof
  DEPENDS boost-units)
cme_port_feature(boost preprocessor
  SUMMARY "Boost.preprocessor"
  DEPENDS boost-preprocessor)
cme_port_feature(boost format
  SUMMARY "Boost.format"
  IMPLIES assert config core optional smart_ptr throw_exception utility
  DEPENDS boost-format)
cme_port_feature(boost xpressive
  SUMMARY "Boost.xpressive"
  IMPLIES assert config conversion core exception fusion integer iterator lexical_cast mpl numeric_conversion optional preprocessor proto range smart_ptr throw_exception type_traits typeof utility
  DEPENDS boost-xpressive)
cme_port_feature(boost integer
  SUMMARY "Boost.integer"
  IMPLIES assert config core throw_exception type_traits
  DEPENDS boost-integer)
cme_port_feature(boost thread
  SUMMARY "Boost.thread"
  IMPLIES assert atomic bind chrono concept_check config container container_hash core date_time exception function io move optional predef preprocessor smart_ptr system throw_exception tuple type_traits utility winapi
  DEPENDS boost-thread)
cme_port_feature(boost tokenizer
  SUMMARY "Boost.tokenizer"
  IMPLIES assert config iterator mpl throw_exception type_traits
  DEPENDS boost-tokenizer)
cme_port_feature(boost timer
  SUMMARY "Boost.timer"
  IMPLIES config io predef
  DEPENDS boost-timer)
cme_port_feature(boost regex
  SUMMARY "Boost.regex"
  IMPLIES assert config predef throw_exception
  DEPENDS boost-regex)
cme_port_feature(boost crc
  SUMMARY "Boost.crc"
  DEPENDS boost-crc)
cme_port_feature(boost random
  SUMMARY "Boost.random"
  IMPLIES assert config core dynamic_bitset integer io system throw_exception type_traits utility
  DEPENDS boost-random)
cme_port_feature(boost serialization
  SUMMARY "Boost.serialization"
  IMPLIES array assert config core detail function integer io iterator move mpl optional predef preprocessor smart_ptr spirit type_traits unordered utility variant
  DEPENDS boost-serialization)
cme_port_feature(boost unit_test_framework
  SUMMARY "Boost.unit test framework"
  IMPLIES algorithm assert bind config core describe detail exception function io iterator mpl numeric_conversion optional preprocessor smart_ptr type_traits utility
  DEPENDS boost-test)
cme_port_feature(boost prg_exec_monitor
  SUMMARY "Boost.prg exec monitor"
  IMPLIES algorithm assert bind config core describe detail exception function io iterator mpl numeric_conversion optional preprocessor smart_ptr type_traits utility
  DEPENDS boost-test)
cme_port_feature(boost test_exec_monitor
  SUMMARY "Boost.test exec monitor"
  IMPLIES algorithm assert bind config core describe detail exception function io iterator mpl numeric_conversion optional preprocessor smart_ptr type_traits utility
  DEPENDS boost-test)
cme_port_feature(boost date_time
  SUMMARY "Boost.date time"
  IMPLIES algorithm assert config core io lexical_cast numeric_conversion range smart_ptr throw_exception tokenizer type_traits utility winapi
  DEPENDS boost-date-time)
cme_port_feature(boost logic
  SUMMARY "Boost.logic"
  IMPLIES config core
  DEPENDS boost-logic)
cme_port_feature(boost graph
  SUMMARY "Boost.graph"
  IMPLIES algorithm any array assert bimap concept_check config container_hash conversion core detail foreach function integer iterator lexical_cast math move mpl multi_index multiprecision optional parameter preprocessor property_map property_tree random range regex serialization smart_ptr spirit throw_exception tti tuple type_traits typeof unordered utility xpressive
  DEPENDS boost-graph)
cme_port_feature(boost numeric_conversion
  SUMMARY "Boost.numeric conversion"
  IMPLIES config conversion core mpl preprocessor throw_exception type_traits
  DEPENDS boost-numeric-conversion)
cme_port_feature(boost lambda
  SUMMARY "Boost.lambda"
  IMPLIES config core detail iterator mpl preprocessor tuple type_traits utility
  DEPENDS boost-lambda)
cme_port_feature(boost mpl
  SUMMARY "Boost.mpl"
  IMPLIES config core predef preprocessor type_traits utility
  DEPENDS boost-mpl)
cme_port_feature(boost typeof
  SUMMARY "Boost.typeof"
  IMPLIES config
  DEPENDS boost-typeof)
cme_port_feature(boost tuple
  SUMMARY "Boost.tuple"
  IMPLIES config core type_traits
  DEPENDS boost-tuple)
cme_port_feature(boost utility
  SUMMARY "Boost.utility"
  IMPLIES config core io preprocessor throw_exception type_traits
  DEPENDS boost-utility)
cme_port_feature(boost dynamic_bitset
  SUMMARY "Boost.dynamic bitset"
  IMPLIES assert config container_hash core throw_exception
  DEPENDS boost-dynamic-bitset)
cme_port_feature(boost assign
  SUMMARY "Boost.assign"
  IMPLIES array config core move mpl preprocessor ptr_container range throw_exception tuple type_traits
  DEPENDS boost-assign)
cme_port_feature(boost filesystem
  SUMMARY "Boost.filesystem"
  IMPLIES assert atomic config container_hash core detail io iterator predef scope smart_ptr system type_traits winapi
  DEPENDS boost-filesystem)
cme_port_feature(boost function
  SUMMARY "Boost.function"
  IMPLIES assert bind config core throw_exception
  DEPENDS boost-function)
cme_port_feature(boost conversion
  SUMMARY "Boost.conversion"
  IMPLIES assert config smart_ptr throw_exception
  DEPENDS boost-conversion)
cme_port_feature(boost optional
  SUMMARY "Boost.optional"
  IMPLIES assert config core throw_exception type_traits
  DEPENDS boost-optional)
cme_port_feature(boost property_tree
  SUMMARY "Boost.property tree"
  IMPLIES any assert bind config core iterator mpl multi_index optional range serialization throw_exception type_traits
  DEPENDS boost-property-tree)
cme_port_feature(boost bimap
  SUMMARY "Boost.bimap"
  IMPLIES concept_check config container_hash core iterator lambda mpl multi_index preprocessor throw_exception type_traits utility
  DEPENDS boost-bimap)
cme_port_feature(boost variant
  SUMMARY "Boost.variant"
  IMPLIES assert config container_hash core detail integer mpl preprocessor throw_exception type_index type_traits utility
  DEPENDS boost-variant)
cme_port_feature(boost array
  SUMMARY "Boost.array"
  IMPLIES assert config throw_exception
  DEPENDS boost-array)
cme_port_feature(boost iostreams
  SUMMARY "Boost.iostreams"
  IMPLIES assert config core detail function integer iterator mpl numeric_conversion preprocessor random range regex smart_ptr throw_exception type_traits utility
  DEPENDS boost-iostreams)
cme_port_feature(boost multi_index
  SUMMARY "Boost.multi index"
  IMPLIES assert bind config container_hash core integer mp11 preprocessor smart_ptr throw_exception tuple type_traits utility
  DEPENDS boost-multi-index)
cme_port_feature(boost ptr_container
  SUMMARY "Boost.ptr container"
  IMPLIES array assert circular_buffer config core iterator mpl range smart_ptr type_traits unordered utility
  DEPENDS boost-ptr-container)
cme_port_feature(boost statechart
  SUMMARY "Boost.statechart"
  IMPLIES assert bind config conversion core detail function mpl smart_ptr thread type_traits
  DEPENDS boost-statechart)
cme_port_feature(boost static_assert
  SUMMARY "Boost.static assert"
  IMPLIES config
  DEPENDS boost-static-assert)
cme_port_feature(boost range
  SUMMARY "Boost.range"
  IMPLIES array assert concept_check config container_hash conversion core detail iterator mpl optional preprocessor regex tuple type_traits utility
  DEPENDS boost-range)
cme_port_feature(boost rational
  SUMMARY "Boost.rational"
  IMPLIES assert config core integer throw_exception type_traits utility
  DEPENDS boost-rational)
cme_port_feature(boost iterator
  SUMMARY "Boost.iterator"
  IMPLIES assert concept_check config core detail fusion mpl optional type_traits utility
  DEPENDS boost-iterator)
cme_port_feature(boost graph_parallel
  SUMMARY "Boost.graph parallel"
  IMPLIES assert concept_check config container_hash core detail dynamic_bitset filesystem foreach function graph iterator lexical_cast mpi mpl optional property_map property_map_parallel random serialization smart_ptr tuple type_traits variant
  DEPENDS boost-graph-parallel)
cme_port_feature(boost property_map
  SUMMARY "Boost.property map"
  IMPLIES any assert concept_check config core function iterator lexical_cast mpl smart_ptr throw_exception type_traits utility
  DEPENDS boost-property-map)
cme_port_feature(boost program_options
  SUMMARY "Boost.program options"
  IMPLIES any bind config core detail function iterator lexical_cast smart_ptr throw_exception tokenizer type_traits
  DEPENDS boost-program-options)
cme_port_feature(boost detail
  SUMMARY "Boost.detail"
  IMPLIES config core preprocessor type_traits
  DEPENDS boost-detail)
cme_port_feature(boost numeric_interval
  SUMMARY "Boost.numeric interval"
  IMPLIES config detail logic
  DEPENDS boost-numeric-interval)
cme_port_feature(boost numeric_ublas
  SUMMARY "Boost.numeric ublas"
  IMPLIES compute concept_check config core iterator mpl numeric_interval range serialization smart_ptr type_traits typeof
  DEPENDS boost-numeric-ublas)
cme_port_feature(boost wave
  SUMMARY "Boost.wave"
  IMPLIES assert concept_check config core filesystem format iterator lexical_cast mpl multi_index optional pool preprocessor serialization smart_ptr spirit throw_exception type_traits
  DEPENDS boost-wave)
cme_port_feature(boost type_traits
  SUMMARY "Boost.type traits"
  IMPLIES config
  DEPENDS boost-type-traits)
cme_port_feature(boost bind
  SUMMARY "Boost.bind"
  IMPLIES config core
  DEPENDS boost-bind)
cme_port_feature(boost pool
  SUMMARY "Boost.pool"
  IMPLIES assert config integer throw_exception type_traits winapi
  DEPENDS boost-pool)
cme_port_feature(boost proto
  SUMMARY "Boost.proto"
  IMPLIES config core fusion mpl preprocessor range type_traits typeof utility
  DEPENDS boost-proto)
cme_port_feature(boost fusion
  SUMMARY "Boost.fusion"
  IMPLIES config container_hash core function_types mpl preprocessor tuple type_traits typeof utility
  DEPENDS boost-fusion)
cme_port_feature(boost function_types
  SUMMARY "Boost.function types"
  IMPLIES config core detail mpl preprocessor type_traits
  DEPENDS boost-function-types)
cme_port_feature(boost gil
  SUMMARY "Boost.gil"
  IMPLIES assert concept_check config container_hash core filesystem headers integer iterator mp11 preprocessor type_traits variant2
  DEPENDS boost-gil)
cme_port_feature(boost intrusive
  SUMMARY "Boost.intrusive"
  IMPLIES assert config move
  DEPENDS boost-intrusive)
cme_port_feature(boost asio
  SUMMARY "Boost.asio"
  IMPLIES align assert config context date_time system throw_exception
  DEPENDS boost-asio)
cme_port_feature(boost uuid
  SUMMARY "Boost.uuid"
  IMPLIES assert config throw_exception type_traits
  DEPENDS boost-uuid)
cme_port_feature(boost circular_buffer
  SUMMARY "Boost.circular buffer"
  IMPLIES assert concept_check config core move throw_exception type_traits
  DEPENDS boost-circular-buffer)
cme_port_feature(boost mpi
  SUMMARY "Boost.mpi"
  IMPLIES assert config core foreach function graph integer iterator lexical_cast mpl optional serialization smart_ptr throw_exception type_traits utility
  DEPENDS boost-mpi)
cme_port_feature(boost unordered
  SUMMARY "Boost.unordered"
  IMPLIES assert config container_hash core mp11 predef throw_exception
  DEPENDS boost-unordered)
cme_port_feature(boost signals2
  SUMMARY "Boost.signals2"
  IMPLIES assert bind config core function iterator move mpl optional parameter preprocessor smart_ptr throw_exception tuple type_traits variant
  DEPENDS boost-signals2)
cme_port_feature(boost accumulators
  SUMMARY "Boost.accumulators"
  IMPLIES array assert circular_buffer concept_check config core fusion iterator mpl numeric_conversion numeric_ublas parameter preprocessor range serialization throw_exception tuple type_traits typeof
  DEPENDS boost-accumulators)
cme_port_feature(boost atomic
  SUMMARY "Boost.atomic"
  IMPLIES align assert config predef preprocessor type_traits winapi
  DEPENDS boost-atomic)
cme_port_feature(boost scope_exit
  SUMMARY "Boost.scope exit"
  IMPLIES config function preprocessor type_traits typeof
  DEPENDS boost-scope-exit)
cme_port_feature(boost flyweight
  SUMMARY "Boost.flyweight"
  IMPLIES assert config container_hash core detail interprocess mpl multi_index parameter preprocessor smart_ptr throw_exception type_traits
  DEPENDS boost-flyweight)
cme_port_feature(boost icl
  SUMMARY "Boost.icl"
  IMPLIES assert concept_check config container core date_time detail iterator move mpl range rational type_traits utility
  DEPENDS boost-icl)
cme_port_feature(boost predef
  SUMMARY "Boost.predef"
  DEPENDS boost-predef)
cme_port_feature(boost chrono
  SUMMARY "Boost.chrono"
  IMPLIES assert config core integer move mpl predef ratio system throw_exception type_traits typeof utility winapi
  DEPENDS boost-chrono)
cme_port_feature(boost polygon
  SUMMARY "Boost.polygon"
  IMPLIES config
  DEPENDS boost-polygon)
cme_port_feature(boost msm
  SUMMARY "Boost.msm"
  IMPLIES any assert bind circular_buffer config core function fusion mp11 mpl parameter phoenix preprocessor proto serialization tuple type_traits typeof
  DEPENDS boost-msm)
cme_port_feature(boost heap
  SUMMARY "Boost.heap"
  IMPLIES assert concept_check config core intrusive iterator parameter throw_exception
  DEPENDS boost-heap)
cme_port_feature(boost coroutine
  SUMMARY "Boost.coroutine"
  IMPLIES assert config context core exception move system throw_exception type_traits utility
  DEPENDS boost-coroutine)
cme_port_feature(boost coroutine2
  SUMMARY "Boost.coroutine2"
  IMPLIES assert config context
  DEPENDS boost-coroutine2)
cme_port_feature(boost ratio
  SUMMARY "Boost.ratio"
  DEPENDS boost-ratio)
cme_port_feature(boost numeric_odeint
  SUMMARY "Boost.numeric odeint"
  IMPLIES assert compute config core fusion iterator math mpi mpl multi_array numeric_ublas preprocessor range throw_exception type_traits units utility
  DEPENDS boost-numeric-odeint)
cme_port_feature(boost geometry
  SUMMARY "Boost.geometry"
  IMPLIES algorithm any array assert concept_check config container core endian function_types fusion graph headers integer iterator lexical_cast math move mpl multiprecision numeric_conversion polygon predef qvm range rational serialization thread throw_exception tokenizer tuple utility variant variant2
  DEPENDS boost-geometry)
cme_port_feature(boost phoenix
  SUMMARY "Boost.phoenix"
  IMPLIES assert bind config core function fusion mpl predef preprocessor proto range smart_ptr type_traits utility
  DEPENDS boost-phoenix)
cme_port_feature(boost move
  SUMMARY "Boost.move"
  IMPLIES config
  DEPENDS boost-move)
cme_port_feature(boost locale
  SUMMARY "Boost.locale"
  IMPLIES assert charconv config core iterator predef thread
  DEPENDS boost-locale)
cme_port_feature(boost container
  SUMMARY "Boost.container"
  IMPLIES assert config intrusive move
  DEPENDS boost-container)
cme_port_feature(boost local_function
  SUMMARY "Boost.local function"
  IMPLIES config mpl preprocessor scope_exit type_traits typeof utility
  DEPENDS boost-local-function)
cme_port_feature(boost context
  SUMMARY "Boost.context"
  IMPLIES assert config core mp11 pool predef smart_ptr
  DEPENDS boost-context)
cme_port_feature(boost type_erasure
  SUMMARY "Boost.type erasure"
  IMPLIES assert config core fusion iterator mp11 mpl preprocessor smart_ptr thread throw_exception type_traits typeof vmd
  DEPENDS boost-type-erasure)
cme_port_feature(boost multiprecision
  SUMMARY "Boost.multiprecision"
  IMPLIES assert config core integer lexical_cast math random
  DEPENDS boost-multiprecision)
cme_port_feature(boost lockfree
  SUMMARY "Boost.lockfree"
  IMPLIES align assert atomic config core parameter predef utility
  DEPENDS boost-lockfree)
cme_port_feature(boost assert
  SUMMARY "Boost.assert"
  IMPLIES config
  DEPENDS boost-assert)
cme_port_feature(boost align
  SUMMARY "Boost.align"
  IMPLIES assert config core
  DEPENDS boost-align)
cme_port_feature(boost type_index
  SUMMARY "Boost.type index"
  IMPLIES config container_hash throw_exception
  DEPENDS boost-type-index)
cme_port_feature(boost core
  SUMMARY "Boost.core"
  IMPLIES assert config throw_exception
  DEPENDS boost-core)
cme_port_feature(boost throw_exception
  SUMMARY "Boost.throw exception"
  IMPLIES assert config
  DEPENDS boost-throw-exception)
cme_port_feature(boost winapi
  SUMMARY "Boost.winapi"
  IMPLIES config predef
  DEPENDS boost-winapi)
cme_port_feature(boost lexical_cast
  SUMMARY "Boost.lexical cast"
  IMPLIES config container core throw_exception
  DEPENDS boost-lexical-cast)
cme_port_feature(boost sort
  SUMMARY "Boost.sort"
  IMPLIES config core range type_traits
  DEPENDS boost-sort)
cme_port_feature(boost convert
  SUMMARY "Boost.convert"
  IMPLIES config core function_types lexical_cast math mpl optional parameter range spirit type_traits
  DEPENDS boost-convert)
cme_port_feature(boost endian
  SUMMARY "Boost.endian"
  IMPLIES config
  DEPENDS boost-endian)
cme_port_feature(boost vmd
  SUMMARY "Boost.vmd"
  IMPLIES preprocessor
  DEPENDS boost-vmd)
cme_port_feature(boost dll
  SUMMARY "Boost.dll"
  IMPLIES assert config core filesystem predef system throw_exception type_index winapi
  DEPENDS boost-dll)
cme_port_feature(boost compute
  SUMMARY "Boost.compute"
  IMPLIES algorithm array assert atomic chrono config core filesystem function function_types fusion iterator lexical_cast mpl optional preprocessor property_tree proto range smart_ptr thread throw_exception tuple type_traits typeof utility uuid
  DEPENDS boost-compute)
cme_port_feature(boost hana
  SUMMARY "Boost.hana"
  IMPLIES config core fusion mpl tuple
  DEPENDS boost-hana)
cme_port_feature(boost metaparse
  SUMMARY "Boost.metaparse"
  IMPLIES config mpl predef preprocessor type_traits
  DEPENDS boost-metaparse)
cme_port_feature(boost qvm
  SUMMARY "Boost.qvm"
  DEPENDS boost-qvm)
cme_port_feature(boost fiber
  SUMMARY "Boost.fiber"
  IMPLIES algorithm assert config context core filesystem format intrusive predef smart_ptr
  DEPENDS boost-fiber)
cme_port_feature(boost process
  SUMMARY "Boost.process"
  IMPLIES algorithm asio config core filesystem fusion iterator move optional system tokenizer type_index winapi
  DEPENDS boost-process)
cme_port_feature(boost stacktrace
  SUMMARY "Boost.stacktrace"
  IMPLIES config container_hash core predef winapi
  DEPENDS boost-stacktrace)
cme_port_feature(boost poly_collection
  SUMMARY "Boost.poly collection"
  IMPLIES assert config core iterator mp11 mpl type_erasure type_traits
  DEPENDS boost-poly-collection)
cme_port_feature(boost beast
  SUMMARY "Boost.beast"
  IMPLIES asio assert bind config container container_hash core endian headers intrusive logic mp11 optional smart_ptr static_string system throw_exception type_index type_traits winapi
  DEPENDS boost-beast)
cme_port_feature(boost mp11
  SUMMARY "Boost.mp11"
  DEPENDS boost-mp11)
cme_port_feature(boost callable_traits
  SUMMARY "Boost.callable traits"
  DEPENDS boost-callable-traits)
cme_port_feature(boost contract
  SUMMARY "Boost.contract"
  IMPLIES any assert config core exception function function_types mpl optional preprocessor smart_ptr thread type_traits typeof utility
  DEPENDS boost-contract)
cme_port_feature(boost container_hash
  SUMMARY "Boost.container hash"
  IMPLIES config describe mp11
  DEPENDS boost-container-hash)
cme_port_feature(boost hof
  SUMMARY "Boost.hof"
  DEPENDS boost-hof)
cme_port_feature(boost yap
  SUMMARY "Boost.yap"
  IMPLIES hana preprocessor type_index
  DEPENDS boost-yap)
cme_port_feature(boost safe_numerics
  SUMMARY "Boost.safe numerics"
  IMPLIES concept_check config core integer logic mp11
  DEPENDS boost-safe-numerics)
cme_port_feature(boost parameter_python
  SUMMARY "Boost.parameter python"
  IMPLIES mpl parameter preprocessor python
  DEPENDS boost-parameter-python)
cme_port_feature(boost headers
  SUMMARY "Boost.headers"
  DEPENDS boost-headers)
cme_port_feature(boost outcome
  SUMMARY "Boost.outcome"
  IMPLIES config exception headers system throw_exception
  DEPENDS boost-outcome)
cme_port_feature(boost histogram
  SUMMARY "Boost.histogram"
  IMPLIES config core mp11 throw_exception variant2
  DEPENDS boost-histogram)
cme_port_feature(boost variant2
  SUMMARY "Boost.variant2"
  IMPLIES assert config mp11
  DEPENDS boost-variant2)
cme_port_feature(boost nowide
  SUMMARY "Boost.nowide"
  IMPLIES config
  DEPENDS boost-nowide)
cme_port_feature(boost static_string
  SUMMARY "Boost.static string"
  IMPLIES assert container_hash core headers throw_exception utility
  DEPENDS boost-static-string)
cme_port_feature(boost stl_interfaces
  SUMMARY "Boost.stl interfaces"
  IMPLIES assert config
  DEPENDS boost-stl-interfaces)
cme_port_feature(boost leaf
  SUMMARY "Boost.leaf"
  DEPENDS boost-leaf)
cme_port_feature(boost json
  SUMMARY "Boost.json"
  IMPLIES assert config container container_hash core describe endian mp11 system throw_exception
  DEPENDS boost-json)
cme_port_feature(boost pfr
  SUMMARY "Boost.pfr"
  DEPENDS boost-pfr)
cme_port_feature(boost describe
  SUMMARY "Boost.describe"
  IMPLIES mp11
  DEPENDS boost-describe)
cme_port_feature(boost lambda2
  SUMMARY "Boost.lambda2"
  DEPENDS boost-lambda2)
cme_port_feature(boost property_map_parallel
  SUMMARY "Boost.property map parallel"
  IMPLIES assert bind concept_check config function mpi mpl multi_index optional property_map serialization smart_ptr type_traits
  DEPENDS boost-property-map-parallel)
cme_port_feature(boost url
  SUMMARY "Boost.url"
  IMPLIES align assert config core headers mp11 optional system throw_exception type_traits variant2
  DEPENDS boost-url)
cme_port_feature(boost mysql
  SUMMARY "Boost.mysql"
  IMPLIES asio assert charconv compat config container core describe endian intrusive mp11 optional system throw_exception variant2
  DEPENDS boost-mysql)
cme_port_feature(boost compat
  SUMMARY "Boost.compat"
  IMPLIES assert config throw_exception
  DEPENDS boost-compat)
cme_port_feature(boost redis
  SUMMARY "Boost.redis"
  IMPLIES asio assert core mp11 system throw_exception
  DEPENDS boost-redis)
cme_port_feature(boost cobalt
  SUMMARY "Boost.cobalt"
  IMPLIES asio callable_traits circular_buffer config container core endian intrusive mp11 preprocessor smart_ptr static_string system throw_exception variant2
  DEPENDS boost-cobalt)
cme_port_feature(boost charconv
  SUMMARY "Boost.charconv"
  IMPLIES assert config core
  DEPENDS boost-charconv)
cme_port_feature(boost scope
  SUMMARY "Boost.scope"
  IMPLIES config core type_traits
  DEPENDS boost-scope)
cme_port_feature(boost parser
  SUMMARY "Boost.parser"
  IMPLIES assert hana type_index
  DEPENDS boost-parser)
cme_port_feature(boost mqtt5
  SUMMARY "Boost.mqtt5"
  IMPLIES asio assert container core endian headers random range smart_ptr system type_traits
  DEPENDS boost-mqtt5)
cme_port_feature(boost hash2
  SUMMARY "Boost.hash2"
  IMPLIES assert config container_hash describe mp11
  DEPENDS boost-hash2)
cme_port_feature(boost bloom
  SUMMARY "Boost.bloom"
  IMPLIES assert config container_hash core throw_exception type_traits
  DEPENDS boost-bloom)
cme_port_feature(boost openmethod
  SUMMARY "Boost.openmethod"
  IMPLIES assert config core dynamic_bitset headers mp11 preprocessor smart_ptr
  DEPENDS boost-openmethod)
cme_port_feature(boost decimal
  SUMMARY "Boost.decimal"
  DEPENDS boost-decimal)

# The rest of what find_package(Boost) hands back, which is a good deal more
# than a target. Projects written against FindBoost read these variables and
# nothing else, and a library that only exports targets correctly leaves them
# unset -- which is a build failing on a bare Boost_INCLUDE_DIRS rather than
# on anything to do with Boost.
function(cme_adapt_boost source binary)
  get_property(parts GLOBAL PROPERTY CME_VIRTUAL_PARTS_boost)
  get_property(trees GLOBAL PROPERTY CME_VIRTUAL_TREES_boost)
  cme_enabled_features(boost enabled)

  set(includes "")
  foreach(tree IN LISTS trees)
    if(EXISTS "${tree}/include")
      list(APPEND includes "${tree}/include")
    endif()
  endforeach()

  # The four that FindBoost makes beside the libraries. Two of them are about
  # linking Boost as shared libraries and one is about MSVC's autolinking;
  # this builds static archives with no autolinking, so they exist, name what
  # they are, and carry nothing.
  #
  # Made here only when nothing else made them. Boost::headers is a library
  # of Boost's own, so when anything asked for it there is already a target
  # by that name -- an alias to a real one, which nothing may set a property
  # on, and which needs nothing set on it because it is the real thing.
  set(made "")
  foreach(name Boost::headers Boost::diagnostic_definitions
               Boost::disable_autolinking Boost::dynamic_linking)
    if(NOT TARGET ${name})
      add_library(${name} INTERFACE IMPORTED GLOBAL)
      list(APPEND made ${name})
    endif()
  endforeach()
  if(includes AND "Boost::headers" IN_LIST made)
    set_property(TARGET Boost::headers PROPERTY
                 INTERFACE_INCLUDE_DIRECTORIES ${includes})
  endif()

  cme_export_variable(Boost Boost_FOUND TRUE)
  cme_export_variable(Boost Boost_INCLUDE_DIRS "${includes}")
  cme_export_variable(Boost Boost_INCLUDE_DIR "${includes}")
  cme_export_variable(Boost Boost_LIBRARIES "${parts}")
  cme_export_variable(Boost Boost_LIBRARY_DIRS "")
  cme_export_variable(Boost Boost_VERSION "1.92.0")
  cme_export_variable(Boost Boost_VERSION_STRING "1.92.0")
  cme_export_variable(Boost Boost_VERSION_MACRO 109200)
  cme_export_variable(Boost Boost_MAJOR_VERSION 1)
  cme_export_variable(Boost Boost_MINOR_VERSION 92)
  cme_export_variable(Boost Boost_SUBMINOR_VERSION 0)
  cme_export_variable(Boost Boost_LIB_VERSION "1_92")
  foreach(component IN LISTS enabled)
    string(TOUPPER "${component}" upper)
    cme_export_variable(Boost Boost_${upper}_FOUND TRUE)
    cme_export_variable(Boost Boost_${component}_FOUND TRUE)
  endforeach()

  # Said rather than ignored: this cannot be answered, and a project that
  # asked for it would otherwise link static archives while believing it had
  # shared ones.
  if(DEFINED Boost_USE_STATIC_LIBS AND NOT Boost_USE_STATIC_LIBS)
    message(WARNING
      "cmake-everywhere: this project sets Boost_USE_STATIC_LIBS OFF, and "
      "every library built here is a static archive. What you get is the "
      "static one.")
  endif()
endfunction()
