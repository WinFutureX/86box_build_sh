#!/bin/bash

# dir defs
ROOTDIR=~/86Box
SRCDIR=$ROOTDIR/src
OUTDIR=$ROOTDIR/out
ROMDIR=$OUTDIR/roms

# trap defs
trap abort INT

# func defs
usage()
{
	echo "Usage: ./build.sh [OPTIONS] [-a/--all]"
	echo ""
	echo "    -a, --all: updates all repos and build all targets."
	echo ""
	echo "By default, without any arguments, it updates the source and ROM repos and only builds the regular version."
	echo ""
	echo "For example, to only build the debug configuration on 2 CPU threads:"
	echo "$ ./build.sh UPDATE_REPO=n UPDATE_ROMS=n BUILD_REGULAR=n BUILD_DEBUG=y -j2"
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
	scriptdate e
	exit 1
}

fatal2()
{
	printb fatal "$1"
}

abort()
{
	fatal "Script interrupted by user"
}

checkyn()
{
	if [[ $1 != "y" && $1 != "n" ]]; then
		fatal2 "Invalid option in argument(s), check command line"
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
	run "make -f win/Makefile.mingw clean"
}

build()
{
	clean
	if [[ $3 == o ]]; then
		log "build: all optimisations off"
		cmd="\
		make -f win/Makefile.mingw \
			-j$J \
			VNC=n \
			DEV_BUILD=$DEV_BUILD \
			NEW_DYNAREC=$NEW_DYNAREC \
			X64=$X64 \
			DEBUG=$1 \
			OPTIM=n \
			COPTIM=-O0"
	elif [[ $3 == s ]]; then
		log "build: optimising for code size"
		cmd="\
		make -f win/Makefile.mingw \
			-j$J \
			VNC=n \
			DEV_BUILD=$DEV_BUILD \
			NEW_DYNAREC=$NEW_DYNAREC \
			X64=$X64 \
			DEBUG=$1 \
			OPTIM=n \
			COPTIM=-Os"
	else
		cmd="\
		make -f win/Makefile.mingw \
			-j$J \
			VNC=n \
			DEV_BUILD=$DEV_BUILD \
			NEW_DYNAREC=$NEW_DYNAREC \
			X64=$X64 \
			DEBUG=$1 \
			OPTIM=$2"
	fi
	run "$cmd"
	exit=$?
	if (( $exit != 0 )); then
		fatal "build error occurred, exit code is $exit"
	fi
}

scriptdate()
{
	if [[ $1 == s ]]; then
		verb=started
	elif [[ $1 == e ]]; then
		verb=ended
	else
		verb=somethinged # not a real word!
	fi
	scripttime=$(date "+%a %Y/%m/%d %T")
	log "Script $verb on $scripttime"
}

gitrev()
{
	head_l=$(git rev-parse HEAD)
	head_s=$(git rev-parse --short HEAD)
	list "Current local commit of $1: $head_l (short $head_s)"
}

# script exec
echo ""
echo "*********************************"
echo "*                               *"
echo "* 86Box unofficial build script *"
echo "*                               *"
echo "*********************************"
echo ""
SECONDS=0
proc=start
if [[ $(UNAME -s) == "MINGW64"* ]]; then
	X64=y
elif [[ $(UNAME -s) == "MINGW32"* ]]; then
	X64=n
else
	fatal "Unknown target platform"
fi
if [[ $# == 0 && UPDATE_REPO == "" && UPDATE_ROMS == "" && BUILD_REGULAR == "" ]]; then
	log "No arguments specified, using defaults"
fi
for a in "$@"; do
	arg=$a
	if [[ "$arg" == "DEV_BUILD="* ]]; then
		DEV_BUILD="${arg/'DEV_BUILD='}"
	elif [[ "$arg" == "NEW_DYNAREC="* ]]; then
		NEW_DYNAREC="${arg/'NEW_DYNAREC='}"
	elif [[ "$arg" == "UPDATE_REPO="* ]]; then
		UPDATE_REPO="${arg/'UPDATE_REPO='}"
	elif [[ "$arg" == "UPDATE_ROMS="* ]]; then
		UPDATE_ROMS="${arg/'UPDATE_ROMS='}"
	elif [[ "$arg" == "BUILD_REGULAR="* ]]; then
		BUILD_REGULAR="${arg/'BUILD_REGULAR='}"
	elif [[ "$arg" == "BUILD_DEBUG="* ]]; then
		BUILD_DEBUG="${arg/'BUILD_DEBUG='}"
	elif [[ "$arg" == "BUILD_SIZE="* ]]; then
		BUILD_SIZE="${arg/'BUILD_SIZE='}"
	elif [[ "$arg" == "BUILD_OPTIMISED="* ]]; then
		BUILD_OPTIMISED="${arg/'BUILD_OPTIMISED='}"
	elif [[ "$arg" == "-j"* ]]; then
		J="${arg//[^0-9]/}"
	elif [[ "$arg" == "-a" || "$arg" == "--all" ]]; then
		DEV_BUILD=y
		UPDATE_REPO=y
		UPDATE_ROMS=y
		BUILD_REGULAR=y
		BUILD_DEBUG=y
		BUILD_SIZE=y
		BUILD_OPTIMISED=y
	elif [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
		usage
		exit 2
	else
		fatal2 "Unrecognised argument $arg"
		exit 1
	fi
done
# set defaults
if [[ -z "$DEV_BUILD" ]]; then DEV_BUILD=n; fi
if [[ -z "$NEW_DYNAREC" ]]; then NEW_DYNAREC=n; fi
if [[ -z "$UPDATE_REPO" ]]; then UPDATE_REPO=y; fi
if [[ -z "$UPDATE_ROMS" ]]; then UPDATE_ROMS=y; fi
if [[ -z "$BUILD_REGULAR" ]]; then BUILD_REGULAR=y; fi
if [[ -z "$BUILD_DEBUG" ]]; then BUILD_DEBUG=n; fi
if [[ -z "$BUILD_SIZE" ]]; then BUILD_SIZE=n; fi
if [[ -z "$BUILD_OPTIMISED" ]]; then BUILD_OPTIMISED=n; fi
if [[ -z "$J" ]]; then J=1; fi
for opt in $DEV_BUILD \
	$NEW_DYNAREC \
	$UPDATE_REPO \
	$UPDATE_ROMS \
	$BUILD_REGULAR \
	$BUILD_DEBUG \
	$BUILD_SIZE \
	$BUILD_OPTIMISED; \
do
	checkyn $opt
done
scriptdate s
list "Root dir: $ROOTDIR"
list "Source dir: $SRCDIR"
list "Output dir: $OUTDIR"
list "ROM dir: $ROMDIR"
cd $ROOTDIR
if [[ $X64 == y ]]; then
	list "Target arch: MinGW 64 bit"
else
	list "Target arch: MinGW 32 bit"
fi
if [[ $UPDATE_REPO == y ]]; then
	proc=repo
	log "Repo update in progress"
	run "git pull -q"
	log "Repo update completed"
fi
gitrev "sources"
echo "source commit: $(git rev-parse HEAD)" > $OUTDIR/commit_id
log "Switching to source dir"
run "cd $SRCDIR"
if [[ $BUILD_REGULAR == y && \
	$BUILD_DEBUG == y && \
	$BUILD_SIZE == y && \
	$BUILD_OPTIMISED == y ]]; then
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
	run "cp 86Box.exe $OUTDIR/$outexe"
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
	build y n o
	run "cp 86Box.exe $OUTDIR/$outexe"
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
	run "cp 86Box.exe $OUTDIR/$outexe"
	log "Size-optimised build completed"
fi
if [[ $BUILD_OPTIMISED == y ]]; then
	proc=build_o
	if [[ $X64 == y ]]; then
		outexe=86Box_opt_64.exe
	else
		outexe=86Box_opt.exe
	fi
	log "Optimised build in progress"
	build n y n
	run "cp 86Box.exe $OUTDIR/$outexe"
	log "Optimised build completed"
fi
if [[ $UPDATE_ROMS == y ]]; then
	proc=roms
	log "Switching to ROM dir"
	run "cd $ROMDIR"
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
scriptdate e
time_h=$(( $SECONDS / 3600 ))
time_m=$(( $SECONDS % 3600 / 60 ))
time_s=$(( $SECONDS % 60 ))
log "Script took $time_h hour(s), $time_m minute(s) and $time_s second(s)"
exit 0

