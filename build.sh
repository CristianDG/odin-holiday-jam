#! /usr/bin/env sh


: ${ODIN_COMMAND=build}
: ${BUILDING_HOT_RELOAD="false"}
: ${DEBUG_ECHO=0}
# Targets: native, js_wasm
: ${BUILD_TARGET=js_wasm}
: ${OUTPUT_FOLDER=bin}
: ${FILE_NAME=out}

case $BUILD_TARGET in
  "native")
    FILE="$FILE_NAME.bin"
    OUTPUT_FOLDER="bin/native/"
  ;;
  "js_wasm")
    FILE="$FILE_NAME.wasm"
    OUTPUT_FOLDER="bin/wasm/"
    [[ $BUILDING_HOT_RELOAD == "true" ]] && echo "wasm target doesn't support hot reload" && exit
    ;;
  *) echo "unknown build target: $BUILD_TARGET" && exit
    ;;
esac


ROOT=$(pwd)
echo $ROOT

SHARED_FLAGS="-debug -collection:bin=$ROOT/bin -thread-count:4 -error-pos-style:unix -min-link-libs"

build_game_so () # {{{
{
  lib_name="game"

  link_flags="-extra-linker-flags=\"-Wl,-rpath=./linux\""
  flags="-build-mode:shared -no-entry-point $SHARED_FLAGS $link_flags"

  odin build "$ROOT/src/$lib_name" -out:"$lib_name" $flags "${@}"
} # }}}

build_platform_functions () # {{{
{
  lib_name="platform_functions"

  flags="-build-mode:shared -no-entry-point $SHARED_FLAGS"

  odin build "$ROOT/src/$lib_name" -out:"$lib_name" $flags "${@:2}"
} # }}}


build_game () # {{{
{
  # TODO: mudar o nome pra quando o arquivo é static no lugar de hot reload
  # set -x

  flags=" -define:HOT_RELOAD=$BUILDING_HOT_RELOAD $SHARED_FLAGS "
  # flags+=" -print-linker-flags "

  [[ $BUILD_TARGET == "js_wasm" ]] && flags+=" -target:js_wasm32 "

  # flags+=" -build-mode:object "
  # flags+=" -no-crt -default-to-panic-allocator "
  
  if [[ BUILDING_HOT_RELOAD == "true" ]]; then
    game_running=0
    found_processes="$(pgrep $FILE | wc -l)"
    [[ $found_processes == 1 ]] && game_running=1
    [[ $found_processes > 1 ]] \
      && echo "found too many processes with the name $FILE" \
      && exit 1
    [[ $game_running == 1 ]] && echo "skipping runner" && exit
  fi

  odin build "$ROOT/src" -out:$FILE $flags $@ 
} # }}}

clear_new_symbols () # {{{
{ 
  # TODO:
  # - bingcc para compilar pra uma versão anterior
  # - adicionar libm.so com patchelf
  # - adicionar libpthread.so com patchelf
  # - remover * @GLIBC_2.38
  # - remover __libc_start_main@GLIBC_2.34
  echo "WIP"
} # }}}

pushd $OUTPUT_FOLDER > /dev/null

# set -x

if [[ $BUILDING_HOT_RELOAD == "true" ]]; then
  [[ $DEBUG_ECHO ]] && echo "building hot reload"
  build_platform_functions && build_game_so && build_game
else 
  [[ $DEBUG_ECHO ]] && echo "building static $BUILD_TARGET"
  build_game $@
fi

popd > /dev/null

