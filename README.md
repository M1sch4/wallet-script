# wallet

Wallet- und Lizenzsystem fuer Qbox/QBCore mit NUI.

## Was das Script macht

- Zeigt ein Wallet-UI per `/wallet` mit:
  - Name, Geburtsdatum, Einreisedatum, Groesse, Citizen ID
  - Hunger-/Durst-Balken
  - Lizenzen und Dokumente
  - Fahrzeugschluessel (Original/Kopie)
- Speichert Lizenzen serverseitig in MySQL (`wallet_licenses`).
- Ermoeglicht das Anzeigen von Lizenzen:
  - an sich selbst
  - an den naechsten Spieler (Naehe-Check)
- Unterstuetzt Fahrzeugpapier als Lizenztyp (`fahrzeugpapier_<plate>`) inkl. Overlay-Ansicht.
- Kann Schluessel im UI laden und Kopien an nahe Spieler uebergeben (je nach angebundenem Vehicle-Key-System).

## Voraussetzungen

- `qb-core`
- `oxmysql`
- NUI wird ueber `ui/index.html` geladen.

## Datenbank

Beim Start wird diese Tabelle automatisch erstellt:

- `wallet_licenses (citizenid, type, label)`

Zusaetzlich nutzt das Script Fahrzeugschluessel-Daten aus einer Key-Tabelle (im Code: `vehicle_keys`).

Im Ordner liegt auch `vehiclekeys.sql` als Beispiel fuer Key-/Vehicle-Tabellen.

## Befehle

- `/wallet`  
  Oeffnet das Wallet-UI fuer den Spieler.

- `/setlizenz <id> <typ>` (Admin)  
  Vergibt eine Lizenz an einen Spieler.

- `/removelizenz <id> <typ>` (Admin)  
  Entfernt eine Lizenz von einem Spieler.

## Konfiguration

In `shared/config.lua`:

- `LicenseTypes` definiert alle Lizenzarten (Name + Label)
- `vehiclekey` ist als uebertragbar markiert (`transferable = true`)

## Wichtige Events/Callbacks

- Server Callback: `wallet:getLicenses`
- Client NUI Callbacks:
  - `close`
  - `licenseAction`
  - `giveCarKey`
- Netzwerk-Events:
  - `wallet:showLicenseTo`
  - `wallet:receiveLicense`
  - `wallet:setLicenses`
  - `wallet:requestVehicleKeys`
  - `wallet:setVehicleKeys`

## Hinweise

- Das Script nutzt aktuell Debug-Ausgaben in Client/UI (`print`, `console.log`).
- Fuer Schluessel-Uebergabe muss euer Vehicle-Key-Resource-Event korrekt angebunden sein.
- Datei `ui/fahrzeugpapier.png` wird im `fxmanifest.lua` referenziert und fuer Fahrzeugpapier-Darstellung genutzt.

