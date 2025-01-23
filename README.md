# READ_QE_DATA

This script reads data from Quantum Espresso output files and converts it to $\mathrm{eV}$/$\mathrm{\AA}$ units. Results are printed to and output file called `info.dat` (filename can be changed within the script), in a format that also allows values to be directly copied into a QE input file for continuation jobs. In addition, the (final) crystal structure is written to a VASP POSCAR file (this option can also be disabled within the script).


Usage
---
The script requires a filename prefix to be provided as a command line argument:
```shell
read_QE_data.sh <prefix>
```
e.g. if the QE output file is called `Sr2Co2O5.relax.out` then the `<prefix>` should be replaced by `Sr2Co2O5.relax`.
