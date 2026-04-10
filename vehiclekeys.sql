-- Tabelle für persistente Fahrzeugschlüssel
CREATE TABLE IF NOT EXISTS `player_carkeys` (
    `plate` VARCHAR(20) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `is_original` BOOLEAN NOT NULL DEFAULT 0,
    PRIMARY KEY (`plate`, `citizenid`)
);

-- Tabelle für Fahrzeugbesitz (falls nicht schon vorhanden)
CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `citizenid` VARCHAR(50) NOT NULL,
    `plate` VARCHAR(20) NOT NULL,
    `vehicle` VARCHAR(50) NOT NULL,
    `mods` LONGTEXT,
    `state` INT DEFAULT 0,
    `garage` VARCHAR(50) DEFAULT 'public',
    PRIMARY KEY (`plate`)
); 