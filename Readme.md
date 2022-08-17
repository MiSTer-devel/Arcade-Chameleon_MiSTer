# Jaleco Chameleon for MiSTer

Work in progress.

ToDo:
- Sound, the two JT89 chips are there but sound is noisy and different from the original machine.
- The video module requires one additionnal vertical row and image is offset to the right on CRT.
- The 2 joysticks, they are directly connected from hps_io to the core for now.
- Coins, a NMI is generated on coin insertion. Does not work yet. Is NMI not detected by the CPU? It needs to be verified with SignalTap.
- Nice to have: replace the current CPU with a more accurate one, the chip_6502!!
