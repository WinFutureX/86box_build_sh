#!/bin/bash

# action defs
UPDATE_REPO=y
BUILD_EXE=y
BUILD_REGULAR=y # depends on BUILD_EXE
BUILD_DEBUG=y # same
BUILD_OPTIMISED=y # ditto
UPDATE_ROMS=y

# build vars
DEV_BUILD=y
J=4
if [[ $(UNAME) == "MINGW64"* ]]; then
	X64=y
elif [[ $(UNAME) == "MINGW32"* ]]; then
	X64=n
else
	fatal "Unknown platform"
fi

# dir defs
ROOTDIR=~/86Box
SRCDIR=$ROOTDIR/src
OUTDIR=$ROOTDIR/out
ROMDIR=$OUTDIR/roms

# trap defs
trap abort INT

# func defs
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

abort()
{
	fatal "Script interrupted by user"
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
	scripttime=$(date "+%a %d %b %Y %T")
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
proc=start
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
if [[ $BUILD_EXE == y ]]; then
	proc=build
	log "Preparing to build EXEs"
	log "Switching to source dir"
	run "cd $SRCDIR"
	if [[ $BUILD_REGULAR == y ]]; then
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
	if [[ $BUILD_OPTIMISED == y ]]; then
		if [[ $X64 == y ]]; then
			outexe=86Box_opt_64.exe
		else
			outexe=86Box_opt.exe
		fi
		log "Optimised build in progress"
		build y y n
		run "cp 86Box.exe $OUTDIR/$outexe"
		log "Optimised build completed"
	fi
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
exit 0

