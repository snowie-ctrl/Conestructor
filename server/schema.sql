-- Conestructor's team server (part 5). Run once on coneDB by the owner (server/README.md, "Cut-over"): it replaces
-- the prototype's tracks table, whose three old tracks are not kept. Times are UTC. Only a key's SHA-256 is stored.
-- Track files live at /pool/appFiles/conestructor/teams/<teamId>/<trackId>.cone and .jpg, named by ids, so no path
-- is stored.

DROP TABLE IF EXISTS tracks;
DROP TABLE IF EXISTS teams;

CREATE TABLE teams (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    keyHash CHAR(64) NOT NULL,
    created DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY keyHash (keyHash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tracks (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    teamId INT UNSIGNED NOT NULL,
    name VARCHAR(200) NOT NULL,
    cones INT UNSIGNED NOT NULL,
    uploaded DATETIME NOT NULL,
    bytes INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY teamUploaded (teamId, uploaded),
    CONSTRAINT tracksTeam FOREIGN KEY (teamId) REFERENCES teams (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
