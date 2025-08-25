# MiniC-Compiler

This project is a simple compiler that translates a subset of the C programming language (MiniC) into x86 assembly code.

## Features

- Supports basic C-like syntax: variable declarations, arithmetic expressions, conditionals (`if`, `else`), loops (`while`), and functions.
- Handles both `int` and `char` data types.
- Generates x86 assembly code for Linux (AT&T syntax).
- Supports global and local variables, function parameters, and return statements.

## Project Structure

```
MiniC_to_x86/
  ├── a3.l        # Flex lexer: tokenizes MiniC source code
  ├── a3.y        # Bison parser: parses MiniC and generates x86 assembly
  ├── Makefile    # Build instructions
README.md         # Project documentation
```

## How to Build

1. Install [Flex](https://github.com/westes/flex) and [Bison](https://www.gnu.org/software/bison/).
2. Navigate to the `MiniC_to_x86` directory.
3. Run:

   ```sh
   make
   ```

   This will generate `a.out`.

## How to Use

1. Prepare your MiniC source code in a file, e.g., `test.c`.
2. Run the compiler:

   ```sh
   ./a.out < test.c > output.s
   ```

   This will produce the x86 assembly code in `output.s`.

## Example

**MiniC Input:**
```c
#include <stdio.h>
int main() {
    int a;
    a = 5 + 3;
    return a;
}
```

**Generated x86 Output (snippet):**
```assembly
.bss
a: .space 4
.text
.globl main
main:
pushl %ebp
movl %esp, %ebp
subl $4, %esp
movl $5, -4(%ebp)
movl $3, -8(%ebp)
movl -4(%ebp), %eax
addl -8(%ebp), %eax
movl %eax, -12(%ebp)
movl -12(%ebp), %eax
leave
ret
.data
```

## Limitations

- Only a subset of C is supported.
- No pointer or struct support.
- Error handling is basic.
