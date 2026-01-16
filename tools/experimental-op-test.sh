#!/usr/bin/env bash

set -eo pipefail  # Exit on error or pipe failure

# 1. Environment Check
if [[ -z "$BASE_SHA" || -z "$HEAD_SHA" ]]; then
    echo "Error: BASE_SHA or HEAD_SHA is not set."
    exit 1
fi

echo "Diffing $BASE_SHA...$HEAD_SHA"

# 2. Identify Changed Files
changed_files=$(git diff --name-only --diff-filter=AM "$BASE_SHA...$HEAD_SHA" || true)

if [[ -z "$changed_files" ]]; then
    echo "No changed files detected, skipping."
    exit 0
fi

# 3. Categorize Tests
functional_tests_to_run=""
performance_tests_to_run=""
functional_missing_tests=""
performance_missing_tests=""

for f in $changed_files; do
    # Logic for files in experimental_ops
    if [[ $f == src/flag_gems/experimental_ops/*.py ]]; then
        if [[ $(basename "$f") == __*__* ]]; then continue; fi

        base=$(basename "$f" .py)

        # Check Functional
        func_file="experimental_tests/functional/${base}_test.py"
        [[ -f "$func_file" ]] && functional_tests_to_run+=" $func_file" || functional_missing_tests+=" $func_file"

        # Check Performance
        perf_file="experimental_tests/performance/${base}_test.py"
        [[ -f "$perf_file" ]] && performance_tests_to_run+=" $perf_file" || performance_missing_tests+=" $perf_file"

    # Logic for direct test file changes
    elif [[ $f == experimental_tests/functional/*_test.py && -f "$f" ]]; then
        functional_tests_to_run+=" $f"
    elif [[ $f == experimental_tests/performance/*_test.py && -f "$f" ]]; then
        performance_tests_to_run+=" $f"
    fi
done

# 4. Error Handling for Missing Tests
if [[ -n "$functional_missing_tests" || -n "$performance_missing_tests" ]]; then
    echo "::error:: Modified operators are missing required test files."
    [[ -n "$functional_missing_tests" ]] && echo "Missing Functional: $functional_missing_tests"
    [[ -n "$performance_missing_tests" ]] && echo "Missing Performance: $performance_missing_tests"
    exit 1
fi

# 5. Execution Helper
run_pytest_group() {
    local label=$1
    local files=$2
    if [[ -n "$files" ]]; then
        unique_files=$(echo "$files" | tr ' ' '\n' | sort -u | xargs)
        echo "Running $label tests: $unique_files"
        run_command pytest -s $unique_files
    else
        echo "No $label tests to run."
    fi
}

run_pytest_group "Functional" "$functional_tests_to_run"
run_pytest_group "Performance" "$performance_tests_to_run"
