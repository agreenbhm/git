#!/bin/sh
set -ex

# Helper libraries
. ${0%/*}/lib-ci-type.sh

# Parse options
mode_build=
mode_test=
while test $# != 0
do
	case "$1" in
	--build)
		mode_build=t
		;;
	--test)
		mode_test=t
		;;
	-*)
		echo "error: invalid option: $1" >&2
		exit 1
		;;
	*)
		echo "error: invalid argument: $1" >&2
		exit 1
		;;
	esac
	shift
done

# Starting assertions
if test -z "$jobname"
then
	echo "error: must set a CI jobname in the environment" >&2
	exit 1
fi

if test "$mode_test$mode_build" != "t"
then
	echo "error: need one mode, e.g. --build or --test" >&2
	exit 1
fi

# Helper functions
setenv () {
	while test $# != 0
	do
		case "$1" in
		--build)
			if test -z "$mode_build"
			then
				return 0
			fi
			;;
		--test)
			if test -z "$mode_test"
			then
				return 0
			fi
			;;
		-*)
			echo "BUG: bad setenv() option '$1'" >&2
			exit 1
			;;
		*)
			break
			;;
		esac
		shift
	done

	key=$1
	val=$2
	shift 2

	if test -n "$GITHUB_ENV"
	then
		echo "$key=$val" >>"$GITHUB_ENV"
	fi
}

# How many jobs to run in parallel?
NPROC=10

# For "--test" we carry the MAKEFLAGS over from earlier steps, except
# in stand-alone jobs which will use $COMMON_MAKEFLAGS.
COMMON_MAKEFLAGS=--jobs=$NPROC

# Clear MAKEFLAGS that may come from the outside world.
MAKEFLAGS=$COMMON_MAKEFLAGS

case "$CI_TYPE" in
github-actions)
	CC="${CC:-gcc}"

	setenv --test GIT_PROVE_OPTS "--timer --jobs $NPROC"
	GIT_TEST_OPTS="--verbose-log -x"
	test Windows != "$RUNNER_OS" ||
	GIT_TEST_OPTS="--no-chain-lint --no-bin-wrappers $GIT_TEST_OPTS"
	setenv --test GIT_TEST_OPTS "$GIT_TEST_OPTS"
	;;
*)
	echo "Unhandled CI type: $CI_TYPE" >&2
	exit 1
	;;
esac

setenv --build DEVELOPER 1
setenv --test DEFAULT_TEST_TARGET prove
setenv --test GIT_TEST_CLONE_2GB true
setenv --build SKIP_DASHED_BUILT_INS YesPlease

case "$runs_on_pool" in
ubuntu-latest)
	if test "$jobname" = "linux-gcc-default"
	then
		break
	fi

	if test "$jobname" = linux-gcc
	then
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=/usr/bin/python3"
	else
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=/usr/bin/python2"
	fi

	setenv --test GIT_TEST_HTTPD true
	;;
macos-latest)
	if test "$jobname" = osx-gcc
	then
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=$(which python3)"
	else
		MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=$(which python2)"
	fi
	;;
esac

case "$jobname" in
windows-build)
	setenv --build NO_PERL NoThanks
	setenv --build ARTIFACTS_DIRECTORY artifacts
	;;
windows-test)
	setenv --test MAKEFLAGS "$COMMON_MAKEFLAGS"
	;;
vs-build)
	setenv --build NO_PERL NoThanks
	setenv --build NO_GETTEXT NoThanks
	setenv --build ARTIFACTS_DIRECTORY artifacts
	setenv --build INCLUDE_DLLS_IN_ARTIFACTS YesPlease
	setenv --build MSVC YesPlease

	setenv --build GIT_CONFIG_COUNT 2
	setenv --build GIT_CONFIG_KEY_0 user.name
	setenv --build GIT_CONFIG_VALUE_0 CI
	setenv --build GIT_CONFIG_KEY_1 user.emailname
	setenv --build GIT_CONFIG_VALUE_1 ci@git
	setenv --build GIT_CONFIG_VALUE_1 ci@git
	;;
vs-test)
	setenv --test NO_SVN_TESTS YesPlease
	setenv --test MAKEFLAGS "$COMMON_MAKEFLAGS"
	;;
linux-gcc)
	setenv --test GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME main
	;;
linux-TEST-vars)
	setenv --test GIT_TEST_SPLIT_INDEX yes
	setenv --test GIT_TEST_MERGE_ALGORITHM recursive
	setenv --test GIT_TEST_FULL_IN_PACK_ARRAY true
	setenv --test GIT_TEST_OE_SIZE 10
	setenv --test GIT_TEST_OE_DELTA_SIZE 5
	setenv --test GIT_TEST_COMMIT_GRAPH 1
	setenv --test GIT_TEST_COMMIT_GRAPH_CHANGED_PATHS 1
	setenv --test GIT_TEST_MULTI_PACK_INDEX 1
	setenv --test GIT_TEST_MULTI_PACK_INDEX_WRITE_BITMAP 1
	setenv --test GIT_TEST_ADD_I_USE_BUILTIN 1
	setenv --test GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME master
	setenv --test GIT_TEST_WRITE_REV_INDEX 1
	setenv --test GIT_TEST_CHECKOUT_WORKERS 2
	;;
linux-clang)
	setenv --test GIT_TEST_DEFAULT_HASH sha1
	;;
linux-sha256)
	setenv --test GIT_TEST_DEFAULT_HASH sha256
	;;
pedantic)
	# Don't run the tests; we only care about whether Git can be
	# built.
	setenv --build DEVOPTS pedantic
	;;
linux32)
	CC=gcc
	;;
linux-musl)
	CC=gcc
	MAKEFLAGS="$MAKEFLAGS PYTHON_PATH=/usr/bin/python3 USE_LIBPCRE2=Yes"
	MAKEFLAGS="$MAKEFLAGS NO_REGEX=Yes ICONV_OMITS_BOM=Yes"
	MAKEFLAGS="$MAKEFLAGS GIT_TEST_UTF8_LOCALE=C.UTF-8"
	;;
linux-leaks)
	setenv --build SANITIZE leak
	setenv --test GIT_TEST_PASSING_SANITIZE_LEAK true
	;;
esac

setenv --build MAKEFLAGS "$MAKEFLAGS CC=${CC:-cc}"
