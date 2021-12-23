#!/bin/bash

# dir defs (todo: remove this)
#ROOT_DIR=~/86Box
#SRC_DIR=$ROOT_DIR/src
#BUILD_DIR=$ROOT_DIR/build # cmake builds only
#OUT_DIR=$ROOT_DIR/out
#ROM_DIR=$OUT_DIR/roms
#MAKEFILE=$SRC_DIR/win/Makefile.mingw # todo: allow makefiles other than default

# trap defs
trap abort INT

# func defs
usage()
{
	echo "Usage:"
	echo ""
	echo "    ./build.sh [OPTIONS] [PATHS]"
	echo "    - or -"
	echo "    ./build.sh [-a/--all]"
	echo ""
	echo "    -jN      : build using N CPU threads."
	echo "    -a, --all: updates all repos and build all targets."
	echo ""
	echo "By default, without any arguments, it updates the source and ROM repos and only builds the regular version."
	echo ""
	echo "For example, to only build the debug configuration on 2 CPU threads:"
	echo "$ ./build.sh UPDATE_REPO=n UPDATE_ROMS=n BUILD_REGULAR=n BUILD_DEBUG=y -j2"
	echo ""
	echo "Available build options:"
	echo "    CMAKE         Build with CMake (default: off in MinGW, always on otherwise)."
	echo "    DEV_BUILD     Enables experimental features and code (default: off)."
	echo "    NEW_DYNAREC   Enables the new dynamic recompiler from PCem (default: off)."
	echo "    UPDATE_REPO   Update the main source repository (default: on)."
	echo "    UPDATE_ROMS   Update the ROM repository (default: on)."
	echo "    BUILD_REGULAR Build a normal executable (default: on)."
	echo "    BUILD_DEBUG   Build a debug executable with symbols (default: off)."
	echo "    BUILD_SIZE    Build a size-optimised executable (default: off)."
	echo "    BUILD_OPT     Build a CPU-optimised executable (default: off)."
	echo ""
	echo "Available paths:"
	echo "    ROOT_DIR  Root directory (default: the folder that this script is run from)."
	echo "    SRC_DIR   Source directory (makefile builds, default: \$ROOT_DIR/src)."
	echo "    BUILD_DIR CMake directory (CMake builds, default: \$ROOT_DIR/build)."
	echo "    OUT_DIR   Build output directory (default: \$ROOT_DIR/out)."
	echo "    ROM_DIR   ROM repository directory (default: \$OUT_DIR/roms)."
	echo "    MAKEFILE  Makefile (makefile builds, default: \$SRC_DIR/win/Makefile.mingw)."
}

printb()
{
	echo "[$1] $2"
}

log()
{
	printb info "$1"
}

list()
{
	printb list "$1"
}

warn()
{
	printb warn "$1"
}

fatal()
{
	printb fatal "$1"
	script_date finish
	exit 1
}

fatal_early()
{
	printb fatal "$1"
	exit 1
}

abort()
{
	fatal "Script interrupted by user"
}

check_yn()
{
	if [[ $1 != "y" && $1 != "n" ]]; then
		fatal_early "Invalid option in argument(s), check command line"
		exit 1
	fi
}

run()
{
	$1 > /dev/null
	exit=$?
	if (( $exit != 0 )); then
		fatal "Error occurred while executing command $1, exit code is $exit"
	fi
}

clean()
{
	run "make -f $MAKEFILE clean"
}

# todo: cmake support
build()
{
	clean
	if [[ $3 == o ]]; then
		log "build: all optimisations off"
		if [[ $CMAKE == y ]]; then
			cmd="cd $ROOT_DIR && cmake -G \"MSYS Makefiles\" -S $ROOT_DIR -B $BUILD_DIR -DVNC=n -DDEV_BRANCH=$DEV_BUILD -DNEW_DYNAREC=$NEW_DYNAREC -DX64=$X64 -DDEBUG=$DEBUG -DCMAKE_CXXFLAGS=-O0 && cd $BUILD_DIR && make -j$J"
		else
			cmd="make -f $MAKEFILE -j$J VNC=n DEV_BUILD=$DEV_BUILD NEW_DYNAREC=$NEW_DYNAREC X64=$X64 DEBUG=$1 OPTIM=n COPTIM=-O0"
		fi
	elif [[ $3 == s ]]; then
		log "build: optimising for code size"
		if [[ $CMAKE == y ]]; then
			cmd="cd $ROOT_DIR && cmake -G \"MSYS Makefiles\" -S $ROOT_DIR -B $BUILD_DIR -DVNC=n -DDEV_BRANCH=$DEV_BUILD -DNEW_DYNAREC=$NEW_DYNAREC -DX64=$X64 -DDEBUG=$DEBUG -DCMAKE_CXXFLAGS=-Os && cd $BUILD_DIR && make -j$J"
		else
			cmd="make -f $MAKEFILE -j$J VNC=n DEV_BUILD=$DEV_BUILD NEW_DYNAREC=$NEW_DYNAREC X64=$X64 DEBUG=$1 OPTIM=n COPTIM=-Os"
		fi
	elif [[ $3 == g ]]; then
		log "build: optimising for debugging"
		if [[ $CMAKE == y ]]; then
			cmd="cd $ROOT_DIR && cmake -G \"MSYS Makefiles\" -S $ROOT_DIR -B $BUILD_DIR -DVNC=n -DDEV_BRANCH=$DEV_BUILD -DNEW_DYNAREC=$NEW_DYNAREC -DX64=$X64 -DDEBUG=$DEBUG -DCMAKE_CXXFLAGS=-Og && cd $BUILD_DIR && make -j$J"
		else
			cmd="make -f $MAKEFILE -j$J VNC=n DEV_BUILD=$DEV_BUILD NEW_DYNAREC=$NEW_DYNAREC X64=$X64 DEBUG=$1 OPTIM=n COPTIM=-Og"
		fi
	else
		if [[ $CMAKE == y ]]; then
			cmd="cd $ROOT_DIR && cmake -G \"MSYS Makefiles\" -S $ROOT_DIR -B $BUILD_DIR -DVNC=n -DDEV_BRANCH=$DEV_BUILD -DNEW_DYNAREC=$NEW_DYNAREC -DX64=$X64 -DDEBUG=$DEBUG && cd $BUILD_DIR && make -j$J"
		else
			cmd="make -f $MAKEFILE -j$J VNC=n DEV_BUILD=$DEV_BUILD NEW_DYNAREC=$NEW_DYNAREC X64=$X64 DEBUG=$1 OPTIM=$2"
		fi
	fi
	run "$cmd"
}

script_date()
{
	log "Script ${1}ed on $(date "+%a %Y-%m-%d %T")"
}

gitrev()
{
	head_l=$(git rev-parse HEAD)
	head_s=$(git rev-parse --short HEAD)
	list "Current local commit of $1: $head_l (short $head_s)"
}

# script exec
SECONDS=0
proc=start

for a in "$@"; do
	if [[ "$a" == "-h" || "$a" == "--help" ]]; then
		usage
		exit 2
	fi
done

# print banner
echo ""
echo "*********************************"
echo "*                               *"
echo "* 86Box unofficial build script *"
echo "*                               *"
echo "*********************************"
echo ""

# os detection
if [[ $(UNAME -s) == "MINGW"* ]]; then
	platform=windows
	log "Platform: Windows"
elif [[ $(UNAME -s) == "Linux" ]]; then
	platform=linux
	log "Platform: Linux"
elif [[ $(UNAME -s) == "Darwin" ]]; then
	platform=macos
	log "Platform: macOS"
else
	fatal_early "Unknown target platform"
fi

# cpu arch detection
cpu=$(UNAME -m)
case $cpu in
	"i686")
		log "CPU: x86 (32 bit)"
		;;
	"x86_64")
		if [[ $(UNAME -s) == "MINGW64"* ]]; then X64=y; fi
		log "CPU: x86 (64 bit)"
		;;
	"armv7l")
		log "CPU: ARMv7"
		;;
	"arm64" | "aarch64")
		log "CPU: ARMv8"
		;;
	*)
		fatal_early "Unknown target CPU"
		;;
esac

if [[ $# == 0 ]]; then
	log "No arguments specified, using defaults"
	UPDATE_REPO=y
	UPDATE_ROMS=y
	BUILD_REGULAR=y
fi

# iterate arguments list
for a in "$@"; do
	arg=$a
	#if [[ "$arg" == "CMAKE="* ]]; then
	#	CMAKE="${arg/'CMAKE='}"
	#elif [[ "$arg" == "DEV_BUILD="* ]]; then
	#	DEV_BUILD="${arg/'DEV_BUILD='}"
	#elif [[ "$arg" == "NEW_DYNAREC="* ]]; then
	#	NEW_DYNAREC="${arg/'NEW_DYNAREC='}"
	#elif [[ "$arg" == "UPDATE_REPO="* ]]; then
	#	UPDATE_REPO="${arg/'UPDATE_REPO='}"
	#elif [[ "$arg" == "UPDATE_ROMS="* ]]; then
	#	UPDATE_ROMS="${arg/'UPDATE_ROMS='}"
	#elif [[ "$arg" == "BUILD_REGULAR="* ]]; then
	#	BUILD_REGULAR="${arg/'BUILD_REGULAR='}"
	#elif [[ "$arg" == "BUILD_DEBUG="* ]]; then
	#	BUILD_DEBUG="${arg/'BUILD_DEBUG='}"
	#elif [[ "$arg" == "BUILD_SIZE="* ]]; then
	#	BUILD_SIZE="${arg/'BUILD_SIZE='}"
	#elif [[ "$arg" == "BUILD_OPT="* ]]; then
	#	BUILD_OPT="${arg/'BUILD_OPT='}"
	#elif [[ "$arg" == "ROOT_DIR="* ]]; then
	#	ROOT_DIR="${arg/'ROOT_DIR='}"
	#elif [[ "$arg" == "SRC_DIR="* ]]; then
	#	SRC_DIR="${arg/'SRC_DIR='}"
	#elif [[ "$arg" == "BUILD_DIR="* ]]; then
	#	BUILD_DIR="${arg/'BUILD_DIR='}"
	#elif [[ "$arg" == "OUT_DIR="* ]]; then
	#	OUT_DIR="${arg/'OUT_DIR='}"
	#elif [[ "$arg" == "ROM_DIR="* ]]; then
	#	ROM_DIR="${arg/'ROM_DIR='}"
	#elif [[ "$arg" == "MAKEFILE="* ]]; then
	#	MAKEFILE="${arg/'MAKEFILE='}"
	#elif [[ "$arg" == "-j"* ]]; then
	#	J="${arg//[^0-9]/}"
	#elif [[ "$arg" == "-a" || "$arg" == "--all" ]]; then
	#	DEV_BUILD=y
	#	UPDATE_REPO=y
	#	UPDATE_ROMS=y
	#	BUILD_REGULAR=y
	#	BUILD_DEBUG=y
	#	BUILD_SIZE=y
	#	BUILD_OPT=y
	#else
	#	fatal_early "Unrecognised argument $arg"
	#	exit 1
	#fi
	case $arg in
		"CMAKE=")
			CMAKE="${arg/'CMAKE='}"
			;;
		"DEV_BUILD="*)
			DEV_BUILD="${arg/'DEV_BUILD='}"
			;;
		"NEW_DYNAREC="*)
			NEW_DYNAREC="${arg/'NEW_DYNAREC='}"
			;;
		"UPDATE_REPO="*)
			UPDATE_REPO="${arg/'UPDATE_REPO='}"
			;;
		"UPDATE_ROMS="*)
			UPDATE_ROMS="${arg/'UPDATE_ROMS='}"
			;;
		"BUILD_REGULAR="*)
			BUILD_REGULAR="${arg/'BUILD_REGULAR='}"
			;;
		"BUILD_DEBUG="*)
			BUILD_DEBUG="${arg/'BUILD_DEBUG='}"
			;;
		"BUILD_SIZE="*)
			BUILD_SIZE="${arg/'BUILD_SIZE='}"
			;;
		"BUILD_OPT="*)
			BUILD_OPT="${arg/'BUILD_OPT='}"
			;;
		"ROOT_DIR="*)
			ROOT_DIR="${arg/'ROOT_DIR='}"
			;;
		"SRC_DIR="*)
			SRC_DIR="${arg/'SRC_DIR='}"
			;;
		"BUILD_DIR="*)
			BUILD_DIR="${arg/'BUILD_DIR='}"
			;;
		"OUT_DIR="*)
			OUT_DIR="${arg/'OUT_DIR='}"
			;;
		"ROM_DIR="*)
			ROM_DIR="${arg/'ROM_DIR='}"
			;;
		"MAKEFILE="*)
			MAKEFILE="${arg/'MAKEFILE='}"
			;;
		"-j"*)
			J="${arg//[^0-9]/}"
			;;
		"-a" | "--all")
			DEV_BUILD=y
			UPDATE_REPO=y
			UPDATE_ROMS=y
			BUILD_REGULAR=y
			BUILD_DEBUG=y
			BUILD_SIZE=y
			BUILD_OPT=y
			;;
		*)
			fatal_early "Unrecognised argument $arg"
			;;
	esac
done

# set defaults
if [[ -z "$CMAKE" && "$platform" == windows ]]; then CMAKE=n; else CMAKE=y; fi
if [[ -z "$DEV_BUILD" ]]; then DEV_BUILD=n; fi
if [[ -z "$NEW_DYNAREC" ]]; then NEW_DYNAREC=n; fi
#if [[ -z "$UPDATE_REPO" ]]; then UPDATE_REPO=y; fi
#if [[ -z "$UPDATE_ROMS" ]]; then UPDATE_ROMS=y; fi
#if [[ -z "$BUILD_REGULAR" ]]; then BUILD_REGULAR=y; fi
if [[ -z "$BUILD_DEBUG" ]]; then BUILD_DEBUG=n; fi
if [[ -z "$BUILD_SIZE" ]]; then BUILD_SIZE=n; fi
if [[ -z "$BUILD_OPT" ]]; then BUILD_OPT=n; fi
if [[ -z "$J" ]]; then J=1; fi
if [[ -z "$ROOT_DIR" ]]; then ROOT_DIR=$(pwd); fi
if [[ -z "$SRC_DIR" ]]; then SRC_DIR=$ROOT_DIR/src; fi
if [[ -z "$BUILD_DIR" ]]; then BUILD_DIR=$ROOT_DIR/build; fi
if [[ -z "$OUT_DIR" ]]; then OUT_DIR=$ROOT_DIR/out; fi
if [[ -z "$ROM_DIR" ]]; then ROM_DIR=$OUT_DIR/roms; fi
if [[ -z "$MAKEFILE" ]]; then MAKEFILE=$SRC_DIR/win/Makefile.mingw; fi

if [[ ! -d "$ROOT_DIR" ]]; then fatal_early "Root directory \"$ROOT_DIR\" not found."; fi
if [[ ! -d "$SRC_DIR" ]]; then fatal_early "Source directory \"$SRC_DIR\" not found."; fi
if [[ ! -d "$BUILD_DIR" ]]; then fatal_early "CMake build directory \"$BUILD_DIR\" not found."; fi
if [[ ! -d "$OUT_DIR" ]]; then fatal_early "Output directory \"$OUT_DIR\" not found."; fi
if [[ ! -d "$ROM_DIR" ]]; then fatal_early "ROM directory \"$ROM_DIR\" not found."; fi
if [[ ! -f "$MAKEFILE" ]]; then fatal_early "Makefile \"$MAKEFILE\" not found."; fi

for opt in $CMAKE \
	$DEV_BUILD \
	$NEW_DYNAREC \
	$UPDATE_REPO \
	$UPDATE_ROMS \
	$BUILD_REGULAR \
	$BUILD_DEBUG \
	$BUILD_SIZE \
	$BUILD_OPT; \
do
	check_yn $opt
done

script_date start

list "Root dir: $ROOT_DIR"
list "Source dir: $SRC_DIR"
list "CMake build dir: $BUILD_DIR"
list "Output dir: $OUT_DIR"
list "ROM dir: $ROM_DIR"

cd $ROOT_DIR

if [[ $UPDATE_REPO == y ]]; then
	proc=repo
	log "Repo update in progress"
	run "git pull -q"
	log "Repo update completed"
fi
gitrev "sources"
echo "source commit: $(git rev-parse HEAD)" > $OUT_DIR/commit_id
if [[ $CMAKE == n ]]; then
	log "Switching to source dir"
	run "cd $SRC_DIR"
fi
if [[ $BUILD_REGULAR == y || \
	$BUILD_DEBUG == y || \
	$BUILD_SIZE == y || \
	$BUILD_OPT == y ]]; then
	log "Building with $J CPU thread(s)"
fi
if [[ $NEW_DYNAREC == y ]]; then
	log "note: new dynarec enabled for this build"
fi
if [[ $BUILD_REGULAR == y ]]; then
	proc=build_r
	if [[ $X64 == y ]]; then
		outexe=86Box_64.exe
	else
		outexe=86Box.exe
	fi
	log "Regular build in progress"
	build n n n
	if [[ $CMAKE == y ]]; then
		run "cp $BUILD_DIR/86Box.exe $OUT_DIR/$outexe"
	else
		run "cp $SRC_DIR/86Box.exe $OUT_DIR/$outexe"
	fi
	log "Regular build completed"
fi
if [[ $BUILD_DEBUG == y ]]; then
	proc=build_d
	if [[ $X64 == y ]]; then
		outexe=86Box_debug_64.exe
	else
		outexe=86Box_debug.exe
	fi
	log "Debug build in progress"
	build y n g
	if [[ $CMAKE == y ]]; then
		run "cp $BUILD_DIR/86Box.exe $OUT_DIR/$outexe"
	else
		run "cp $SRC_DIR/86Box.exe $OUT_DIR/$outexe"
	fi
	log "Debug build completed"
fi
if [[ $BUILD_SIZE == y ]]; then
	proc=build_s
	if [[ $X64 == y ]]; then
		outexe=86Box_size_64.exe
	else
		outexe=86Box_size.exe
	fi
	log "Size-optimised build in progress"
	build n n s
	if [[ $CMAKE == y ]]; then
		run "cp $BUILD_DIR/86Box.exe $OUT_DIR/$outexe"
	else
		run "cp $SRC_DIR/86Box.exe $OUT_DIR/$outexe"
	fi
	log "Size-optimised build completed"
fi
if [[ $BUILD_OPT == y ]]; then
	proc=build_o
	if [[ $X64 == y ]]; then
		outexe=86Box_opt_64.exe
	else
		outexe=86Box_opt.exe
	fi
	log "Optimised build in progress"
	build n y n
	if [[ $CMAKE == y ]]; then
		run "cp $BUILD_DIR/86Box.exe $OUT_DIR/$outexe"
	else
		run "cp $SRC_DIR/86Box.exe $OUT_DIR/$outexe"
	fi
	log "Optimised build completed"
fi
if [[ $UPDATE_ROMS == y ]]; then
	proc=roms
	log "Switching to ROM dir"
	run "cd $ROM_DIR"
	log "ROM update in progress"
	run "git pull -q"
	log "ROM update completed"
fi
gitrev "ROMs"
if [[ $proc != start ]]; then
	log "All build tasks completed"
else
	log "Nothing to do"
fi
script_date finish
time_h=$(( $SECONDS / 3600 ))
time_m=$(( $SECONDS % 3600 / 60 ))
time_s=$(( $SECONDS % 60 ))
log "Script took $time_h hour(s), $time_m minute(s) and $time_s second(s)"
exit 0

