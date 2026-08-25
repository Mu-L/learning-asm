#!/usr/bin/env python3
"""Run a program on a pseudo-terminal and feed it lines of input.

Some of the examples only behave correctly when their standard input and
output are a terminal:

  - They read the input with a single `sys_read` per vector. On a pipe, one
    `read` returns every line that is already buffered, so the program sees
    all of the input at once instead of one line at a time.
  - They print the result with the C `printf` and then exit with the raw
    `sys_exit` system call. Outside of a terminal, the C library buffers the
    output fully and nothing flushes it before the program exits.

Both of these go away on a terminal, where reads return a line at a time and
the C library flushes the output on every new line.

Usage:

    pty-run.py <program> [argument ...] --- [input line ...]

The output of the program is written to the standard output and the exit code
of the program becomes the exit code of this script.
"""

import os
import pty
import select
import sys

# How long to wait for the program to stop producing output before the next
# input line is sent, and before the program is considered stuck.
QUIET_TIMEOUT = 0.5
TOTAL_TIMEOUT = 30.0


def main():
    argv = sys.argv[1:]
    if "---" in argv:
        split = argv.index("---")
        command, lines = argv[:split], argv[split + 1:]
    else:
        command, lines = argv, []

    if not command:
        sys.exit("usage: pty-run.py <program> [argument ...] --- [input line ...]")

    pid, fd = pty.fork()
    if pid == 0:
        # The child process becomes the program that we want to run.
        try:
            os.execvp(command[0], command)
        except OSError as error:
            print(f"failed to execute {command[0]}: {error}", file=sys.stderr)
            os._exit(127)

    output = bytearray()
    deadline = TOTAL_TIMEOUT
    pending = list(lines)

    while True:
        try:
            readable, _, _ = select.select([fd], [], [], QUIET_TIMEOUT)
        except OSError:
            break

        if readable:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                # The child closed the terminal, which means it has exited.
                break
            if not chunk:
                break
            output.extend(chunk)
            continue

        # The program produced no output for QUIET_TIMEOUT seconds. It is
        # either waiting for the next line of input or it is done.
        if pending:
            os.write(fd, pending.pop(0).encode() + b"\n")
            continue

        deadline -= QUIET_TIMEOUT
        if deadline <= 0:
            break

    os.close(fd)
    _, status = os.waitpid(pid, 0)

    # The terminal echoes back everything that we write to it, so drop the
    # echoed input lines to leave only what the program itself printed.
    text = output.decode(errors="replace").replace("\r\n", "\n")
    for line in lines:
        text = text.replace(line + "\n", "", 1)

    sys.stdout.write(text)
    sys.stdout.flush()

    if os.WIFEXITED(status):
        sys.exit(os.WEXITSTATUS(status))
    sys.exit(1)


if __name__ == "__main__":
    main()
