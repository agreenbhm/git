#!/bin/sh
#
# Print output of failing tests
#

. ${0%/*}/lib.sh

# Tracing executed commands would produce too much noise in the loop below.
set +x

cd t/

if ! ls test-results/*.exit >/dev/null 2>/dev/null
then
	echo "Build job failed before the tests could have been run"
	exit
fi

for TEST_EXIT in test-results/*.exit
do
	if [ "$(cat "$TEST_EXIT")" != "0" ]
	then
		TEST_OUT="${TEST_EXIT%exit}out"
		echo "------------------------------------------------------------------------"
		echo "$(tput setaf 1)${TEST_OUT}...$(tput sgr0)"
		echo "------------------------------------------------------------------------"
		cat "${TEST_OUT}"

		test_name="${TEST_EXIT%.exit}"
		test_name="${test_name##*/}"
		trash_dir="trash directory.$test_name"
		case "$CI_TYPE" in
		azure-pipelines)
			mkdir -p failed-test-artifacts
			mv "$trash_dir" failed-test-artifacts
			;;
		github-actions)
			mkdir -p failed-test-artifacts
			echo "FAILED_TEST_ARTIFACTS=t/failed-test-artifacts" >>$GITHUB_ENV
			cp "${TEST_EXIT%.exit}.out" failed-test-artifacts/
			tar czf failed-test-artifacts/"$test_name".trash.tar.gz "$trash_dir"
			;;
		*)
			echo "Unhandled CI type: $CI_TYPE" >&2
			exit 1
			;;
		esac
	fi
done
