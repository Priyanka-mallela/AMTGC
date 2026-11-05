# AMTGC
Adaptive Multi-Junction Traffic Grid Controller using Verilog HDL and ModelSim

## Project Overview

The Adaptive Multi-Junction Traffic Grid Controller (AMTGC) is a Verilog HDL-based traffic management system designed to control two connected four-way traffic junctions.

The main aim of this project is to improve traffic coordination, manage pedestrian requests and provide priority to emergency vehicles.

## Features

- **Traffic Signal Control:** Controls North-South and East-West traffic signals at two junctions.
- **Green-Wave Coordination:** Coordinates the green signal timing between Junction A and Junction B.
- **Pedestrian Management:** Uses a single shared pedestrian arbiter to handle requests from both junctions fairly.
- **Emergency Override:** Changes both junctions to an all-red condition during an emergency.
- **Reset Functionality:** Supports resetting the system to its initial state.

## Tools and Technologies

- Verilog HDL
- ModelSim Intel FPGA Starter Edition 2020.1
- Digital Design and Finite State Machines (FSM)

## Project Structure

```text
AMTGC_VLSI_Internship/
│
├── rtl/
│   ├── generic_timer.sv
│   ├── junction_controller.sv
│   ├── ped_arbiter.sv
│   ├── emergency_override.sv
│   ├── green_wave_coordinator.sv
│   └── amtgc_top.sv
│
├── tb/
│   ├── tb_generic_timer.v
│   ├── tb_junction_controller.v
│   ├── tb_amtgc_top.v
│   └── tb_full_verification.v
│
├── docs/
│   ├── technical_report.pdf
│   ├── BUG_LOG.md
│   ├── ASSUMPTIONS_DOCUMENT.md
│   └── SELF_ATTESTATION_CHECKLIST.md
│
└── README.md
```

## Simulation and Verification

The project was simulated and verified using ModelSim.

The full verification included:
- Different traffic-density combinations.
- Green-wave timing verification.
- Pedestrian request handling.
- Emergency override testing.
- Reset and rapid emergency input testing.
- 1000-cycle deterministic pseudo-random testing.

## Simulation Results

The successful full regression produced the following results:

- Green-wave offset: **8 clock cycles**
- Pedestrian service count: **120 for Junction A and 120 for Junction B**
- Emergency override testing completed.
- Reset testing completed.
- Final simulation result: **FULL_REGRESSION_PASS**

## Conclusion

The AMTGC project demonstrates how Verilog HDL can be used to design a coordinated traffic management system. The simulation results show that the implemented system successfully performs traffic signal control, green-wave coordination, pedestrian request handling and emergency override under the tested conditions.


