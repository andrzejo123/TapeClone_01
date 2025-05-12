#!/bin/ksh

clear

cd /nsr/scripts/CloneTape

echo
echo
echo "\t\t Wybierz backup"
echo "\t\t ====================================================="
echo
echo "\t\t 1) AIX DB (1)"
echo "\t\t -----------------------"
echo "\t\t 2) Exchange (2)"
echo "\t\t 3) FAXYS (2)"
echo "\t\t 4) SQL (2)"
echo "\t\t 5) SHAREPOINT (2)"
echo "\t\t -----------------------"
echo "\t\t 6) AIX FS (1)"
echo "\t\t 7) Active Directory (1)"
echo "\t\t 8) Oracle (2)"
echo "\t\t 9) Vmware_servers (2)"
echo "\t\t 10) Vmware_witness (2)"
echo "\t\t 11) WIN_DATA (1)"
echo "\t\t 12) WIN_SYS (1)"
echo "\t\t 13) Serwer Protection (1)"
echo
echo "\t\t ====================================================="
echo "\t\t Postepuj zgodnie z instrukcjami"

read c

case $c in

7) /nsr/scripts/CloneTape/CloneTape.sh AD;;
1) /nsr/scripts/CloneTape/CloneTape.sh AIX_DB;;
6) /nsr/scripts/CloneTape/CloneTape.sh AIX_FS;;
2) /nsr/scripts/CloneTape/CloneTape.sh EXCH;;
3) /nsr/scripts/CloneTape/CloneTape.sh FAX;;
4) /nsr/scripts/CloneTape/CloneTape.sh SQL;;
5) /nsr/scripts/CloneTape/CloneTape.sh SHRP;;
8) /nsr/scripts/CloneTape/CloneTape.sh Oracle;;
9) /nsr/scripts/CloneTape/CloneTape.sh VS;;
10) /nsr/scripts/CloneTape/CloneTape.sh VW;;
11) /nsr/scripts/CloneTape/CloneTape.sh WD;;
12) /nsr/scripts/CloneTape/CloneTape.sh WS;;
13) /nsr/scripts/CloneTape/CloneTape.sh SB;;
 *) echo "Niewlasciwa wartosc, sprobuj ponownie" 

esac

exit
