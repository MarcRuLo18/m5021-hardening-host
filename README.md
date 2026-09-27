# M5021 - Bastionat i Hardening de Servidor Linux (Azure)

Repositori destinat a l'automatització i documentació de les mesures de seguretat aplicades sobre una instància d'Ubuntu en entorn cloud (Azure).

## Autoria
* **Alumne:** Marc Ruiz López
* **Grup:** CIB1

## Contingut del Projecte
* **`hardening.sh`**: Script en Bash idempotent que automatitza tot el procés de bastionat per fases.

## Mesures Implementades
1. **Complexitat de Credencials:** Configuració del mòdul `libpam-pwquality` amb una longitud mínima de 12 caràcters i obligació d'utilitzar majúscules, minúscules, dígits i símbols (`minclass = 4`).
2. **Cicle de Vida de Contrasenyes:** Restricció a `/etc/login.defs` establint un màxim de 90 dies de validesa (`PASS_MAX_DAYS`), un mínim de 7 dies abans del canvi (`PASS_MIN_DAYS`) i 14 dies d'avís previ (`PASS_WARN_AGE`).
3. **Enduriment de l'SSH:** Modificació del fitxer principal `/etc/ssh/sshd_config` per assignar el **port 2222**, bloquejar l'accés directe de l'usuari `root` (`PermitRootLogin no`) i limitar els intents d'autenticació a 3 (`MaxAuthTries 3`).
4. **Idempotència i Validació:** L'script comprova l'estat real del sistema abans de modificar fitxers, valida la sintaxi del dimoni amb `sshd -t` i executa un reinici condicionat per evitar talls innecessaris de connexió.

## Execució del Script
Per executar el procés de bastionat de forma automatitzada, cal disposar de privilegis d'administrador (`sudo`):

```bash
sudo bash hardening.sh
