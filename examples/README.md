# Code examples

These are the sample programs that accompany the book. Each directory is a standalone program with its own `Makefile` and `README.md`.

| Example               | Description                           | Chapter                                                                                   |
| --------------------- | ------------------------------------- | ----------------------------------------------------------------------------------------- |
| [hello](./hello/)     | The basic "Hello, World!" program     | [Part 1. Introduction](../content/asm_1.md)                                               |
| [sum](./sum/)         | Sum of two integer numbers            | [Part 2. The `x86_64` concepts](../content/asm_2.md)                                      |
| [stack](./stack/)     | Sum of two command line arguments     | [Part 3. Journey through the stack](../content/asm_3.md)                                  |
| [strings](./strings/) | Reverse a given input string          | [Part 4. Data manipulation](../content/asm_4.md)                                          |
| [float](./float/)     | Dot product of two vectors of doubles | [Part 6. Floating-point arithmetic](../content/asm_6.md)                                  |
| [casm](./casm/)       | Interaction between assembly and C    | [Part 7. Assembly interaction with high-level programming languages](../content/asm_7.md) |

To build an example, go to its directory and run the following command:

```bash
make
```

The tools you need to build and run the examples are listed in the [Requirements](../README.md#requirements) section.
