# Dot product

This is a simple program that reads two double vectors and calculates the [dot product](https://en.wikipedia.org/wiki/Dot_product) of their values.

To build the program, run:

```bash
make
```

Run the program in a terminal and type the values of the vectors when it asks for them:

```bash
$ ./dot_product
Input the first vector: 2.5 3.17
Input the second vector: 4.22 100.1
Dot product = 327.867000
```

> [!IMPORTANT]
> Do not pipe the input to the program. It expects a terminal and gives either a wrong answer or no answer at all when the standard input and output are a pipe or a file:
>
> ```bash
> $ printf '2.5 3.17\n4.22 100.1\n' | ./dot_product
> Input the first vector: Input the second vector: Error: the number of values in vectors should be the same
> ```
>
> There are two reasons for this behavior:
>
> - The program reads each vector with a single `sys_read` system call. A terminal returns one line per read, but a pipe returns everything that was already written to it. So the first read takes both lines, and the program sees all the values as the first vector and no values as the second one.
> - The program prints the result with the C `printf` function, but exits with the raw `sys_exit` system call. The C library writes to a terminal line by line, but buffers the whole output when it writes to a pipe or a file. Nothing flushes that buffer before `sys_exit` ends the program, so the result never gets printed.

For more details, read [Part 6. Floating-point arithmetic](../../content/asm_6.md).
