#!/bin/bash

# provide prefix as command line argument
# assume input file has suffix '.in' and output is printed to file with suffix '.out'
# assume that if ibrav==0 the units in the CELL_PARAMETERS block have been provided in units of Angstrom
#####default parameters########
outfile=info.dat
create_poscar=1 #1:true, 0:false
##############################

if [ $# -eq 0 ]; then
  echo "Missing argument: input/output file prefix not provided."  >&2
  exit 1
fi

prefix=$1
stdin=$(echo "$prefix.in")
stdout=$(echo "$prefix.out")
bohr2ang=0.529177
Ry2eV=13.6057039763 

[ -f "$outfile" ] && rm "$outfile"

# check if scf cycle has converged
converged=$(grep 'convergence NOT achieved' "$stdout" )

if [ ! -z "${converged}" ]; then
  echo "SCF cycle did not converge within electron_maxstep steps."  >&2
  exit 1
fi

# extract various data from output file
natoms=$(grep 'nat' "$stdin" | tr -cd '[:digit:]')
energy=$(grep ! "$stdout" | tail -1 | awk '{print $5}')
energy_eV=$(echo "$energy * $Ry2eV" | bc -l)
fermi=$(grep "the Fermi energy is" "$stdout" | tail -1 | awk '{print $5}')
force=$(grep 'Total force' "$stdout" | tail -1 | awk '{print $4}')
force_eVAng=$(echo "$force * $Ry2eV / $bohr2ang" | bc -l)

echo -e "E(eV)= $energy_eV" > "$outfile"
echo -e "E_f(eV)= $fermi" >> "$outfile"

# if using twochem calculation
twochem_tag=$(grep 'twochem' "$stdin" | tr "." "\n" | awk 'NR==2')
if [[ $twochem_tag == "true" ]]; then
  fermi_cond=$(grep "the conduction Fermi energy is" "$stdout" | tail -1 | awk '{print $6}')
  echo -e "cond. E_f(eV)= $fermi_cond" >> "$outfile"
fi

echo -e "F_tot(eV/Ang)= $force_eVAng" >>  "$outfile"


# Read Cell parameters block
IFS='$\n'
matrix=$(grep -A 3 CELL_PARAMETERS "$stdout" | tail -3)
unset IFS

# Read lattice type from the input file
ibrav=$(grep 'ibrav' "$prefix.in" | awk '{print $3}' | rev | cut -c2- | rev)

if [ "$ibrav" -ne 0 ]; then
  # Convert lattice matrix from Bohr to Angstrom
  alat=$(grep CELL_PARAMETERS "$stdout" -A 3 | head -1 | awk '{print $3}'| rev | cut -c2- | rev)
  result=""
  while IFS= read -r row; do
    row_result=""
    for value in $row; do
      transformed_value=$(echo "$value * $alat * $bohr2ang" | bc -l)
      row_result="$row_result$(printf "%.8f " "$transformed_value")"
    done
    result="$result$row_result\n"
  done <<< "$matrix"
  # Add cell parameter block (in Angstrom) to info file
  IFS='$\n'
  celldm=$(grep 'celldm(1)' "$stdout" -A 2 | tail -3)
  echo -e "$celldm \n" >> "$outfile"
  echo "CELL_PARAMETERS (angstrom)" >> "$outfile"
else
  # Cell parameters are already in Angstrom
  IFS='$\n'
  result=$matrix
  echo "CELL_PARAMETERS (angstrom)" >> "$outfile"
fi
  echo -e "$result" >> "$outfile"

# Add positions to info file
IFS='$\n'
positions=$(grep ATOMIC_POSITIONS "$prefix.out" -A $natoms | tail -$(($natoms + 1)))
echo -e "$positions" >> "$outfile"

# Check whether POSCAR file creation is requested
if [ $create_poscar -eq 0 ]; then
  exit 0
fi

echo "Creating POSCAR file from QE output..."

# Read the ATOMIC_POSITIONS block from info file
atomic_positions=$(grep -A 100 "ATOMIC_POSITIONS" "$outfile" | tail -n +2)

# Initialize output for the POSCAR
poscar=""

# Add the comment line
poscar="# Converted POSCAR from QE output"

# Scaling factor (usually 1.0)
poscar="$poscar\n1.0"

# Add lattice matrix output to POSCAR
poscar=$(echo -e "$poscar\n$result")

# Extract element names and counts (remove any numbers)
mapfile -t elements < <(echo "$atomic_positions" | awk '{print $1}' | tr -d '0123456789' | uniq)

counts=()

for element in "${elements[@]}"; do
    count=$(echo "$atomic_positions" | grep -c "^$element")
    counts+=("$count")
done

# Add the element names and counts to the POSCAR
poscar="$poscar\n$(IFS=" "; echo "${elements[*]}")"  # Atom types in one line
poscar="$poscar\n$(printf "%d " "${counts[@]}")"    # Counts

# Add the coordinates type (Direct)
poscar="$poscar\nDirect"

# Add the positions
while IFS= read -r line; do
    # Extract fractional coordinates (the 3 columns after the atom name)
    poscar="$poscar\n$(echo "$line" | awk '{printf "% .8f % .8f % .8f", $2, $3, $4}')"
done <<< "$atomic_positions"

# Save to the POSCAR file
output_file="POSCAR"
echo -e "$poscar" > "$output_file"

echo "POSCAR file created successfully."


