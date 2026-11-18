## Copyright (C) 2021 Ekaitz Zarraga
## Copyright (C) 2021 Andrius Štikonas
## Copyright (C) 2022 Gabriel Wicki
## This file is part of stage0.
##
## stage0 is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## stage0 is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with stage0.  If not, see <http://www.gnu.org/licenses/>.
# Compile this thing with -nostdlib


# Register use:
# s2: input fd
# s3: output fd
# s4: pending high nibble or -1

# Uses top of the stack as i/o buffer

.text
.global _start
_start:
    ld a1, 16(sp)         # Input file name

    # Open input file and store FD in s2
    li a7, 56             # sys_openat
    li a0, -100           # AT_FDCWD
    li a2, 0              # read only
    ecall
    mv s2, a0             # Save fd in s2 for later

    # Open output file and store the FD in s3
    li a0, -100           # AT_FDCWD
    ld a1, 24(sp)         # Output file (argument 3)
    li a2, 00001101
    # O_TRUNC   00001000
    # O_CREAT   00000100
    # O_WRONLY  00000001
    # OCTAL!
    li a3, 00700          # Set read, write, execute permission on user
    # S_IRWXU  00700
    # OCTAL!
    ecall
    mv s3, a0             # Save fd in s3 for later

    mv a1, sp
    li a2, 1

pair:
    li s4, -1             # No high nibble yet

normal:
    jal t2, read          # Save the return address in t2
    li t0, 35             # Check for '#'
    beq a0, t0, comment
    li t0, 59             # Check for ';'
    bne a0, t0, decode

comment:
    jal t2, read
    li t0, 10
    beq a0, t0, normal    # a0 eq to \n
    li t0, 13
    bne a0, t0, comment   # CR also ends the comment
    j normal

decode:
    addi t0, a0, -48      # Subtract ASCII '0'
    sltiu t1, t0, 10      # Unsigned range 0 through 9
    bnez t1, digit
    ori t0, a0, 32        # Fold upper case to lower case
    addi t0, t0, -97
    sltiu t1, t0, 6
    beqz t1, normal       # Not hex, continue reading
    addi t0, t0, 10

digit:
    bltz s4, first        # Negative means this is the first digit
    or t0, t0, s4         # Combine two half bytes
    sb t0, 0(sp)          # Store prepared byte in buffer
    mv a0, s3
    li a7, 64             # sys_write
    ecall
    j pair

first:
    slli s4, t0, 4        # Shift logical left 4 times
    j normal

read:
    mv a0, s2
    li a7, 63             # sys_read
    ecall
    beqz a0, exit         # If the file ended (0 bytes read) terminate
    lb a0, 0(sp)
    jr t2                 # Return to the caller

exit:
    li a7, 93             # sys_exit
    ecall
