
# Edge AI Accelerator SoC (RISC-V + MAC Engine)

## Overview

This project implements a 32-bit System-on-Chip (SoC) consisting of a bare-metal RISC-V (RV32I) processor integrated with a custom hardware Multiply-Accumulate (MAC) accelerator.

The design demonstrates how compute-intensive operations such as vector dot products, which are fundamental to machine learning workloads, can be offloaded from the CPU to dedicated hardware. The system uses memory-mapped I/O (MMIO) and a dual-port memory architecture to enable parallel execution and efficient hardware-software interaction.

The RTL design was verified through simulation and implemented on an FPGA.

---

## Motivation

Machine learning workloads rely heavily on repeated multiply-accumulate operations. Executing these operations on a general-purpose CPU is inefficient in terms of latency and resource utilization.

This project explores:

* Hardware acceleration of arithmetic-heavy workloads
* Reduction of CPU workload
* Basic principles of edge AI system design

---

## System Architecture

### 1. RISC-V Processor (RV32I)

* 5-stage pipeline: Fetch, Decode, Execute, Memory, Writeback
* Hazard detection unit for pipeline stalling
* Forwarding unit for resolving data hazards
* Handles control flow and accelerator configuration

### 2. MAC Accelerator

* Dedicated hardware unit for computing vector dot products
* Controlled by a finite state machine (FSM)
* Uses FPGA DSP resources for multiplication
* Operates independently once triggered

Mathematical operation:
Result = Σ (A[i] × B[i]) for i = 0 to N-1

### 3. Dual-Port Memory

* Port A: CPU access (read/write)
* Port B: Accelerator access (read-only)

This allows simultaneous data access without stalling the CPU pipeline.

### 4. Memory-Mapped I/O (MMIO)

| Address    | Function                 |
| ---------- | ------------------------ |
| 0x40000000 | Start MAC execution      |
| 0x40000004 | Base address of Vector A |
| 0x40000008 | Base address of Vector B |
| 0x4000000C | Vector length            |
| 0x40000010 | Result register          |
| 0x60000000 | FPGA LED output          |

---

## Execution Flow

### Hardware Flow

1. CPU writes configuration values to MMIO registers
2. CPU triggers the accelerator
3. MAC FSM reads data from memory
4. Multiply-accumulate operation is performed iteratively
5. Completion signal is asserted
6. Result is stored in the result register

### Software Flow

1. Initialize vectors in memory
2. Configure MMIO registers
3. Trigger accelerator
4. Poll for completion
5. Read final result

---

## Simulation

The design was verified using a Verilog simulation environment.

Steps:

1. Add RTL and testbench files
2. Run behavioral simulation
3. Observe waveform outputs
4. Verify correctness of results

---

## FPGA Implementation

The design was implemented on the Terasic DE10-Nano (Intel Cyclone V).

Key aspects:

* Clock division for stable operation
* Debounced push-button reset
* Memory-mapped output to onboard LEDs

### Test Case

Input:
A = [1, 2, 3, 4]
B = [2, 3, 4, 5]

Output:
Result = 40
LED Output = 00101000

---

## Performance Insight

The accelerator reduces computation overhead by offloading arithmetic operations from the CPU. Parallel memory access and dedicated datapath execution improve efficiency compared to sequential CPU execution.

(Exact cycle counts can be added after measurement.)

---

## Project Structure

rtl/        Verilog modules (CPU, MAC, memory)
tb/         Testbench files
fpga/       FPGA top-level integration
docs/       Architecture diagrams
results/    Simulation outputs

---

## Applications

* Edge AI inference
* Embedded systems
* Signal processing
* Hardware acceleration research

---

## Future Work

* Extend to matrix multiplication
* Implement systolic array architecture
* Add quantized (INT8) computation
* Integrate as a custom RISC-V instruction
* Improve performance benchmarking

---

## Author

Sarthak Bokade
LinkedIn: https://www.linkedin.com/in/sarthakbokade/
GitHub: https://github.com/SarthakBokade

---

## License

This project is released under the MIT License.
