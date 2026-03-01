#!/bin/bash

# Função para criar os arquivos .inp do ORCA
criar_inputs_orca() {
    nome_arquivo=$1
    ultima_linha=$2

    echo "! r2scan-3c" > "$nome_arquivo"
    echo "! DEFGRID2" >> "$nome_arquivo"
    echo "! normalscf" >> "$nome_arquivo"
    echo "! smallprint printgap noloewdin" >> "$nome_arquivo"
    echo "! NOSOSCF" >> "$nome_arquivo"
    echo "%MaxCore 8000" >> "$nome_arquivo"
    echo "%output" >> "$nome_arquivo"
    echo "       print[P_BondOrder_M] 1" >> "$nome_arquivo"
    echo "       print[P_Mayer] 1" >> "$nome_arquivo"
    echo "       print[P_basis] 2" >> "$nome_arquivo"
    echo "end" >> "$nome_arquivo"
    echo "%pal" >> "$nome_arquivo"
    echo "    nprocs 6" >> "$nome_arquivo"
    echo "end" >> "$nome_arquivo"
    echo "%cpcm" >> "$nome_arquivo"
    echo "    smd    true" >> "$nome_arquivo"
    echo "    smdsolvent \"WATER\"" >> "$nome_arquivo"
    echo "end" >> "$nome_arquivo"
    echo "$ultima_linha" >> "$nome_arquivo"
}

# Loop sobre os arquivos xyz
for file in *.xyz; do
    [ -f "$file" ] || continue

    folder_name=$(basename "$file" .xyz)
    mkdir -p "$folder_name"
    cp "$file" "$folder_name/"
    cp create_orca.sh "$folder_name/"
    cd "$folder_name" || exit

    # ===============================
    # DETECÇÃO AUTOMÁTICA DA CARGA
    # ===============================
    if [[ "$file" == *"+.xyz" ]]; then
        charge_acid=+1
        mult_acid=1
        charge_base=0
        mult_base=1

    elif [[ "$file" == *"-.xyz" ]]; then
        charge_acid=-1
        mult_acid=1
        charge_base=-2
        mult_base=1

    else
        charge_acid=0
        mult_acid=1
        charge_base=-1
        mult_base=1
    fi

    # ===============================
    # INPUTS ORCA
    # ===============================
    criar_inputs_orca "r2scan3c_acid.inp" "* xyzfile $charge_acid $mult_acid xtbopt.xyz"
    criar_inputs_orca "r2scan3c_base.inp" "* xyzfile $charge_base $mult_base xtbopt.xyz"

    mkdir ACIDcalc BASEcalc
    mv "$file" r2scan3c_acid.inp ACIDcalc/
    mv r2scan3c_base.inp BASEcalc/

    # ===============================
    # CÁLCULO DO ÁCIDO
    # ===============================
    cd ACIDcalc || exit
    crest "$file" --dry --chrg $charge_acid
    xtb crest_input_copy.xyz --ohess --alpb water --chrg $charge_acid > o_acid.out

    /home/sandro/binarios/orca601/orca r2scan3c_acid.inp > r2scan3c_acid.out &
    acid_pid=$!
    tail -f r2scan3c_acid.out &
    tail_pid_acid=$!

    wait $acid_pid
    kill $tail_pid_acid
    cp xtbopt.xyz ../BASEcalc/
    cd ..

    # ===============================
    # CÁLCULO DA BASE
    # ===============================
    cd BASEcalc || exit
    crest xtbopt.xyz --alpb water --chrg $charge_acid --deprotonate > deprotonate.out
    xtb deprotonated.xyz --ohess --alpb water --chrg $charge_base > o_base.out

    /home/sandro/binarios/orca601/orca r2scan3c_base.inp > r2scan3c_base.out &
    base_pid=$!
    tail -f r2scan3c_base.out &
    tail_pid_base=$!

    wait $base_pid
    kill $tail_pid_base
    cd ..

    cd ..
done
