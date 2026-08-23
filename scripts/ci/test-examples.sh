#!/usr/bin/env bash
#
# Build each example, run it, and check that it prints what the related
# chapter says it should print.
#
# Usage:
#
#   ./scripts/ci/test-examples.sh              # test every example
#   ./scripts/ci/test-examples.sh hello sum    # test only the given examples
#
# The exit code is 0 if every example was built and produced the expected
# output, and 1 otherwise.

set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXAMPLES="${ROOT}/examples"
PTY_RUN="${ROOT}/scripts/ci/pty-run.py"

# The list of the examples that this script knows how to test. Each of them has
# a `test_<name>` function below.
ALL_EXAMPLES=(hello sum stack strings float casm1 casm2 casm3)

failed=0
current=""

# Print a message about the failed check and remember that something went
# wrong. The exit code of the script is based on the `failed` variable.
fail() {
        printf '  FAIL  %s\n' "$1" >&2
        failed=1
}

pass() {
        printf '  ok    %s\n' "$1"
}

# Build the example in the given directory. The directory is relative to the
# `examples` directory.
build() {
        local directory="${EXAMPLES}/$1"
        local output

        if ! output="$(make -C "${directory}" 2>&1)"; then
                fail "${current}: build failed"
                printf '%s\n' "${output}" >&2
                return 1
        fi

        pass "${current}: builds"
        return 0
}

# Remove the build artifacts of the example in the given directory.
clean() {
        make -C "${EXAMPLES}/$1" clean >/dev/null 2>&1 || true
}

# Check that the given actual output is exactly the same as the expected one.
expect_output() {
        local description="$1" expected="$2" actual="$3"

        if [ "${actual}" = "${expected}" ]; then
                pass "${current}: ${description}"
        else
                fail "${current}: ${description}"
                printf '    expected: %q\n' "${expected}" >&2
                printf '    actual:   %q\n' "${actual}" >&2
        fi
}

# Check that the given actual output contains the expected substring.
expect_contains() {
        local description="$1" expected="$2" actual="$3"

        case "${actual}" in
        *"${expected}"*)
                pass "${current}: ${description}"
                ;;
        *)
                fail "${current}: ${description}"
                printf '    expected to contain: %q\n' "${expected}" >&2
                printf '    actual:              %q\n' "${actual}" >&2
                ;;
        esac
}

# Check that the given exit code is the expected one.
expect_status() {
        local description="$1" expected="$2" actual="$3"

        if [ "${actual}" -eq "${expected}" ]; then
                pass "${current}: ${description}"
        else
                fail "${current}: ${description}"
                printf '    expected exit code %d, got %d\n' "${expected}" "${actual}" >&2
        fi
}

test_hello() {
        build hello || return
        local output status
        output="$("${EXAMPLES}/hello/hello")"
        status=$?
        expect_output "prints the greeting" "hello, world!" "${output}"
        expect_status "exits with success" 0 "${status}"
        clean hello
}

test_sum() {
        build sum || return
        local output status
        output="$("${EXAMPLES}/sum/sum")"
        status=$?
        expect_output "reports the correct sum" "The sum is correct!" "${output}"
        expect_status "exits with success" 0 "${status}"
        clean sum
}

test_stack() {
        build stack || return
        local output status

        # The program pads every digit of the result to 8 bytes, so the `NUL`
        # bytes are removed before the result is compared.
        output="$("${EXAMPLES}/stack/stack" 5 10 | tr -d '\0')"
        status=$?
        expect_output "sums two command-line arguments" "15" "${output}"
        expect_status "exits with success" 0 "${status}"

        output="$("${EXAMPLES}/stack/stack" 5 | tr -d '\0')"
        expect_output "output contains an error about the number of arguments" \
                "Error: expected two command-line arguments" "${output}"

        clean stack
}

test_strings() {
        build strings || return
        local output status
        output="$("${EXAMPLES}/strings/reverse")"
        status=$?
        expect_output "reverses the string" "!dlrow olleH" "${output}"
        expect_status "exits with success" 0 "${status}"
        clean strings
}

test_float() {
        build float || return
        local output status

        # This example needs a terminal, see the comment in `pty-run.py`.
        output="$(python3 "${PTY_RUN}" "${EXAMPLES}/float/dot_product" \
                --- "2.5 3.17" "4.22 100.1")"
        status=$?
        expect_contains "calculates the dot product" \
                "Dot product = 327.867000" "${output}"
        expect_status "exits with success" 0 "${status}"

        clean float
}

test_casm1() {
        build casm/casm1 || return
        local output status
        output="$("${EXAMPLES}/casm/casm1/casm")"
        status=$?
        expect_output "prints the greeting" "hello, world!" "${output}"
        expect_status "exits with success" 0 "${status}"
        clean casm/casm1
}

test_casm2() {
        build casm/casm2 || return
        local output status
        output="$("${EXAMPLES}/casm/casm2/casm")"
        status=$?
        # The `"=a"` output operand of the inline assembly takes the result of
        # the system call from the `rax` register, so the number of the written
        # bytes is the length of the string and does not depend on how the
        # compiler allocates the registers.
        expect_output "writes the string with inline assembly" \
                "$(printf 'Hello World\nBytes written: 12')" "${output}"
        expect_status "exits with success" 0 "${status}"
        clean casm/casm2
}

test_casm3() {
        build casm/casm3 || return
        local output status

        output="$("${EXAMPLES}/casm/casm3/casm" hello)"
        status=$?
        expect_output "returns the length of the argument" \
                "The argument length is - 5" "${output}"
        expect_status "exits with success" 0 "${status}"

        output="$("${EXAMPLES}/casm/casm3/casm" 2>&1)"
        status=$?
        expect_contains "output contains an error about the number of arguments" \
                "must have 1 command line argument" "${output}"
        expect_status "exits with failure" 1 "${status}"

        clean casm/casm3
}

main() {
        local examples=()

        if [ "$#" -gt 0 ]; then
                examples=("$@")
        else
                examples=("${ALL_EXAMPLES[@]}")
        fi

        for example in "${examples[@]}"; do
                if ! declare -F "test_${example}" >/dev/null; then
                        printf 'unknown example: %s\n' "${example}" >&2
                        printf 'known examples: %s\n' "${ALL_EXAMPLES[*]}" >&2
                        exit 1
                fi

                current="${example}"
                printf '%s\n' "${example}"
                "test_${example}"
        done

        if [ "${failed}" -ne 0 ]; then
                printf '\nsome examples failed\n' >&2
                exit 1
        fi

        printf '\nall examples passed\n'
}

main "$@"
