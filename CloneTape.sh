#!/bin/bash
########################
# CloneTape.sh
###
# Klonuje savesety na tasme w zdefiniowanej puli tasmowej
# Wymaga argumentu w postaci kodu srodowiska (env)
### # ActiveDirectory

. /nsr/scripts/CloneTape/CloneTape.cfg

# Na wypadek "nieobsluzonego" bledu - koncz natychmiast
set -e

# Nie wykonuj jesli znajdziesz niezaincjowana zmienna
#set -u

# Przechwytywanie sygnalu ctr+c i usuniecie blokady
trap 'remove_lock "${cmd_unlocking}"' SIGINT SIGTERM

echo "" | tee -a $LOGNAME
echo ${line1} | tee -a $LOGNAME
echo ${line1} | tee -a $LOGNAME

echo "" | tee -a $LOGNAME
echo "${TDd} Uruchamiasz proces klonowania backupow m-cznych $env na tasmy za $PM" | tee -a $LOGNAME
echo "" | tee -a $LOGNAME
sleep 2

############### Obsluga pliku logu ## ###############################################
#Wywolanie funkcji sprawdzania/tworzenia logu
echo "" | tee -a $LOGNAME
is_logfile

############### Obsluga pliku blokady ###############################################
#Wywolanie funkcji sprawdzania pliku blokady
echo "" | tee -a $LOGNAME
if is_already_running "${cmd_check_lock}" ; then
    printf "${TDd} Istnieje plik blokady ${LOCK}, sprawdz czy nie zostala uruchomiona inna instancja skryptu.\n" | tee -a $LOGNAME
    exit 1
fi

#Wywolanie funkcji tworzenia pliku blokady
create_lock "${cmd_locking}"
sleep 2
# Wchodzimy do kat. roboczego lub obslugujemy blad
echo "Przechodze do katalogu roboczego ${WORKDIR}" | tee -a $LOGNAME
cd "${working_dir}" || {
    printf "Nie mozna przejsc do katalogu roboczego ${WORKDIR}.\n" >&2
    remove_lock "${cmd_unlocking}"
    exit 4
}
sleep 2

##test
echo "Utawiam retencje na $RTT"

echo "$cmd_unlocking"

ask "${cmd_unlocking}"
echo "Retencja ustawiona na $RTT"
exit 0
## test


############### Lista ssid do pliku ################################################
echo "" | tee -a $LOGNAME
echo "${TDd} Czyszczenie starego pliku z lista save setow." | tee -a $LOGNAME
> $SSFILE
sleep 2
echo "${TDd} Tworze nowy plik z lista save setow:" | tee -a $LOGNAME
echo "$SSFILE" | tee -a $LOGNAME
${APPL1} -q "${CR},${PARAM}" -r "ssid" >> ${SSFILE} | tee -a $LOGNAME
# Sprawdzenie powodzenia operacji zmiany statusu
    if [[ $? -ne 0 ]]; then
        echo "Blad: Nie udalo sie uworzyc pliku "${SSFILE}"" | tee -a "$LOGNAME"
        remove_lock "${cmd_unlocking}"
        exit 1
    else
        echo "Plik "$SSFILE" utworzony poprawnie." | tee -a "$LOGNAME"
    fi

sleep 2

############### Przygotowanie tasm do klonowania ###################################
echo "$line1" | tee -a $LOGNAME
# Wywolanie funkcji wyboru puli tasmowej
choose_pool
# Wywolanie funkcji do sprawdzania duplikatów SSID w puli tsmowej
check_ssid_dupl "$POOL" "$SSFILE"
# Wywolanie funkcji sprawdzajacej pule tasmowa
check_pool
# Wywolanie funkcji przygotowania 1 tasmy do zapisu
prep_tape_1 "$LIBRARY" "$POOL"

############### Przygotowanie retencji klonow ######################################
# Wywolanie funkcji wyboru retencji
choice_retent

############### Tabela b-ckow  miesieczych #########################################
echo "" | tee -a $LOGNAME
echo "PODSUMOWANIE:" | tee -a $LOGNAME 
echo "Klonowanie backupow m-cznych $env do puli $POOL z retencja $RETENT2" | tee -a $LOGNAME
echo "Zakres dat: $RANGE" | tee -a $LOGNAME
echo "$line1" | tee -a $LOGNAME

echo "Czy parametry klonowania sie zgadzaja?"
ask
echo "" | tee -a $LOGNAME

############### Tabela b-ckow miesieczych #########################################

echo "" | tee -a $LOGNAME
echo "${TDd} Sprawdzam parametry backupu m-cznego $env za $PM, poczekaj chwile." | tee -a $LOGNAME
echo "Backupy m-czne ${env} na DD" | tee -a $LOGNAME

# Tworzenie podsumowan
env1=(`$APPL1 -q "$CR,$PARAM" -r "ssid" | wc -l`)  # liczba savesetów
env2=(`$APPL1 -q "$CR,$PARAM" -r "totalsize" | awk '{ c+=$1 } END {x=c/1024/1000/1000/1000 ; printf "%4.2f", x}'`)  # rozmiar savesetów w TB
env3=(`$APPL1 -q "$CR,$PARAM" -r "sscreate(1)" | sort -d | uniq`)  # daty utworzenia savesetów
env4=(`$APPL1 -q "$CR,$PARAM" -r "ssretent(1)" | sort -d | cut -c 1-2,6-8 | uniq`)  # daty retencji savesetów
env5=(`$APPL1 -q "$CR,$PARAM" -r "level(1)" | sort -d | uniq`)  # poziomy backupu

# Ustal maksymalna liczbe wierszy
max=0
for arr in "${#env3[@]}" "${#env4[@]}" "${#env5[@]}"; do
    (( arr > max )) && max=$arr
done

# Wywolanie funkcji tworzenia aglowka tabeli
mm2

# Wpisywanie danych do tabeli
for ((i=0; i<max; i++)); do
    # Liczba savesetów i clkowity rozmiar - tylko w pierwszym wierszu
    ss="${env1[0]}"      # liczba savesetów
    tb="${env2[0]}"      # calkowity rozmiar savesetów w TB

    if (( i > 0 )); then
        ss=""   # Puste po pierwszym wierszu
        tb=""
    fi

    # Wywwietlenie wiersza tabeli
    printf "|  %-4s | %-6s | %-10s | %-10s | %-6s |\n" \
        "$ss" "$tb" \
        "${env3[$i]:- }" "${env4[$i]:- }" "${env5[$i]:- }" | tee -a "$LOGNAME"
done

echo "$line2" | tee -a $LOGNAME
echo "" | tee -a $LOGNAME

##################################################################################################################
############### Kopiowanie savesetow na tasme ####################################################################
echo "Wykonam nast. polecenie:"
echo "$APPL2 -F -v -s $serv -J $SSN -d $DSN -S -f $SSFILE -b \"$POOL\" -y \"$RETENT2\" -w \"$RETENT2\""
echo "Robimy? y|n"

read znak
case $znak in
    y)
        echo "Rozpoczynam kopiowanie save setow $env za okres $TM01c do puli $POOL z retencja $RETENT2" | tee -a $LOGNAME
        echo "`date +%x' '%X` !!!!!Zapisz godzine rozpoczecia w excelu!!!!!" | tee -a $LOGNAME
        $APPL2 -F -v -s $serv -J $SSN -d $DSN -S -f $SSFILE -b "$POOL" -y "$RETENT2" -w "$RETENT2" 2>&1 | tee -a $LOGNAME
	RET=$?
	echo "Klonowanie wszystkich savesetów zaonczone."
        RET=$?
        ;;
    n)
        echo "`date +%x' '%X` Skrypt zostal przerwany przez operatora. Usuwam plik blokady i koncze." | tee -a $LOGNAME
	${cmd_unlocking}
        exit 1
        ;;
    *)
        echo "Niepoprawna odpowiedź. Wybierz y lub n."
        echo "`date +%x' '%X` Skrypt zostal przerwany przez operatora" | tee -a $LOGNAME
        ;;
esac
echo "" | tee -a $LOGNAME

##################################################################################################################
##################################################################################################################

# Okreslenie wolumenu
TAPE=$($APPL1 -q "sscreate>$LMD,pool=TS4300 PCO 01,pool=TS4300 PCO 02" -r volume)

############### Sprawdzanie satusow  ############################################
echo "" | tee -a $LOGNAME
if [ $RET -eq 0 ]; then
  echo "Proces klonowania $env do puli $POOL zakonczony pomyslnie" | tee -a $LOGNAME
  echo "${TDd} !!!!!Zapisz godzine zakonczenia w excelu!!!!!" | tee -a $LOGNAME
else
  echo "${TDd} RET=$RET Blad klonowania $env do puli $POOL" | tee -a $LOGNAME
fi

## Sprawdzenie volumenow

volumes=()

while read -r ssid; do
    volume=$(mminfo -av -q "ssid=$ssid,pool=$POOL" -r "volume")
    volumes+=("$volume")
done < "$SSFILE"

vol=$(printf "%s\n" "${volumes[@]}" | sort -d | uniq)

# Zapisanie wolumenow do zmiennej w jednej linii, oddzielonych spacjami
volumes=$(printf "%s\n" "${volumes[@]}" | sort -d | uniq | tr '\n' ' ')

## Sprawdzanie liczby savesetow
missing=false
count=0  # Inicjalizacja zmiennej count

while read -r ssid; do
    result=$(mminfo -av -q "ssid=$ssid,pool=$POOL" -r "ssid")
    if [ -n "$result" ]; then
        count=$((count + 1))
    else
        echo "Saveset $ssid nie znajduje sie w puli $POOL"
        missing=true
    fi
done < "$SSFILE"

if [ "$missing" = false ]; then
    echo "Wszystkie savesety z listy znajduja sie w puli $POOL"
fi

## Sprawdzenie totalsize
sizes=()  # Inicjalizacja tablicy sizes
while read -r ssid; do
    size=$(mminfo -av -q "ssid=$ssid,pool=$POOL" -r "totalsize")
    sizes+=("$size")
done < "$SSFILE"

totalsize=$(printf "%s\n" "${sizes[@]}" | awk '{ c+=$1 } END {x=c/1024/1000/1000/1000 ; printf "%4.2f\n", x}')

## Sprawdzenie savetime
sts=()  # Inicjalizacja tablicy sts
while read -r ssid; do
    st=$(mminfo -av -q "ssid=$ssid,pool=$POOL" -r "sscreate")
    sts+=("$st")
done < "$SSFILE"

savetime=$(printf "%s\n" "${sts[@]}" | sort -d | uniq)

## Sprawdzenie retencji
rets=()  # Inicjalizacja tablicy rets
while read -r ssid; do
    ret=$(mminfo -av -q "ssid=$ssid,pool=$POOL" -r "ssretent")
    rets+=("$ret")
done < "$SSFILE"

ssretent=$(printf "%s\n" "${rets[@]}" | sort -d | uniq)

## Sprawdzenie LEVEL
levs=()  # Inicjalizacja tablicy levs
while read -r ssid; do
    lev=$(mminfo -av -q "ssid=$ssid,pool=$POOL" -r "LEVEL")
    levs+=("$lev")
done < "$SSFILE"

level=$(printf "%s\n" "${levs[@]}" | sort -d | uniq)

############### Tabela klonow na tasmach # #######################################
echo "" | tee -a $LOGNAME
echo "${TDd} Sprawdzam parametry klonowania $env na tasmy, poczekaj chwile." | tee -a $LOGNAME
echo "Klony $env zapisane zostaly w volumenach: $volumes" | tee -a $LOGNAME

#Wywoalnie funkcji formatowania tabeli
mm2

# Przygotowanie danych
env1="${count[0]}"  # Liczba savesetów
env2="${totalsize[0]}"  # Calkowity rozmiar savesetów w TB
env3=($(printf "%s\n" "${savetime[@]}" | sort -d | uniq))  # Daty utworzenia savesetów
env4=($(printf "%s\n" "${rets[@]}" | sort -d | uniq))  # Daty retencji savesetów
env5=($(printf "%s\n" "${levs[@]}" | sort -d | uniq))  # Poziomy backupu

# Ustal maksymalna liczbe wierszy
max=0
for arr in "${#env3[@]}" "${#env4[@]}" "${#env5[@]}"; do
    (( arr > max )) && max=$arr
done

# Wpisywanie danych do tabeli
for ((i=0; i<max; i++)); do
    # Liczba savesetów i clkowity rozmiar - tylko w pierwszym wierszu
    ss="$env1"
    tb="$env2"

    if (( i > 0 )); then
        ss=""  # Puste po pierwszym wierszu
        tb=""
    fi

    # Wyswietlanie wiersza tabeli
    printf "|  %-4s | %-6s | %-10s | %-10s | %-6s |\n" \
        "$ss" "$tb" \
        "${env3[$i]:- }" "${env4[$i]:- }" "${env5[$i]:- }" | tee -a "$LOGNAME"
done

echo "$line2" | tee -a $LOGNAME

echo "UWAGA!!! Sprawdz, czy tabela klonow zgadza sie z tabela backupow!!!" | tee -a $LOGNAME
echo "" | tee -a $LOGNAME

############### Koniec pracy - sprzatanie  #######################################

# Na koniec usuwanie blokady
sleep 5
echo "${TDd} Usuwam plik blokady ${LOCK}"  | tee -a $LOGNAME
remove_lock "${cmd_unlocking}"

############### Usuwanie pliku blokady ### #######################################
if [ -f "$LOCK" ]; then
    echo "Usuwanie pliku blokady nie powiodlo sie" | tee -a $LOGNAME
    exit 99
else
    echo "Plik blokady zostal usuniety. Konczymy" | tee -a $LOGNAME
fi

############### Obsluga maili ####################################################
echo "Wysylam email z logiem klonowania ${env} do ${MAILADRR}" | tee -a $LOGNAME

html_log=$(convert_log_to_html "$LOGNAME")

# Zapisanie logu HTML do pliku
echo "$html_log" > "${HTML_FILE}" | tee -a "${LOGNAME}"

# Uzycie narzedzia 'mailx' do wysylania e-maila
echo "${BODY}" | mailx -s "${SUBJECT}" -a "${ATTACH}" "${MAILADRR}"
