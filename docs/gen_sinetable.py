# This script generates a sine wave table for the FPGA
# The table is generated for one quarter of a sine wave
# Written by gfcwfzkm

import numpy as np
import matplotlib.pyplot as plt

TABLE_LEN = 256
VAL_MAX = 255
VAL_MIN = 0

# Generate the first quarter of a sine wave table
table = np.round((np.sin(np.linspace(0, np.pi*2, TABLE_LEN)) + 1) * 127.5)

QuarterTable = table[1:TABLE_LEN//4+1] - (int(np.pi) if TABLE_LEN > 128 else int(np.ceil(np.pi))) # Korrekturfaktoren, damit der Sinus hübscher ist :D

print("constant SINEWAVE_LUT : std_logic_array := (")
for i in range(TABLE_LEN//4):
	print(f'\t{i} => x"{int(QuarterTable[i]):02X}",')

print(");")

# Sinewave function test on the quartertable for two periods from here:

def sinewave(x):
	# Quartertable ist von 0 bis 31
	# x ist von 0 bis 127
	x = x % TABLE_LEN

	if x < TABLE_LEN//4:
		return (QuarterTable[x])
	elif x < TABLE_LEN//2:
		return (QuarterTable[TABLE_LEN//2 - 1 - x])
	elif x < (TABLE_LEN//2+TABLE_LEN//4):
		return VAL_MAX - (QuarterTable[x - TABLE_LEN//2])
	else:
		return VAL_MAX - (QuarterTable[TABLE_LEN-1 - x])

# Plot the sine wave
x = np.arange(TABLE_LEN*2+1)
y = [sinewave(i) for i in x]
z = table

plt.figure("Test", figsize=(10, 5))
plt.plot(x, y, '-o')
# plt.plot(x, z)
plt.xticks(np.arange(0, 256, 8))
plt.grid()
plt.show()
