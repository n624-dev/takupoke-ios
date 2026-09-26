import Foundation

extension LocalMaterialDatabase {
    static let schema = """
        CREATE TABLE library (
            id INTEGER PRIMARY KEY CHECK (id = 1), folder BLOB,
            migrationComplete INTEGER NOT NULL DEFAULT 0 CHECK (migrationComplete IN (0, 1))
        );
        CREATE TABLE source (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL CHECK (kind IN ('timetable', 'changes', 'events')),
            settings BLOB NOT NULL, UNIQUE (id, kind)
        );
        CREATE TABLE original (
            id TEXT PRIMARY KEY NOT NULL, sourceID TEXT,
            kind TEXT NOT NULL CHECK (kind IN ('timetable', 'changes', 'events')),
            digest TEXT NOT NULL CHECK (length(digest) > 0), originalName TEXT NOT NULL,
            storedName TEXT UNIQUE, record BLOB, legacyPosition INTEGER UNIQUE,
            UNIQUE (id, kind),
            FOREIGN KEY (sourceID, kind) REFERENCES source (id, kind),
            CHECK ((record IS NULL AND storedName IS NULL AND legacyPosition IS NULL) OR
                   (record IS NOT NULL AND storedName IS NOT NULL AND legacyPosition IS NOT NULL))
        );
        CREATE INDEX original_content ON original (kind, digest);
        CREATE TABLE analysis (
            id TEXT PRIMARY KEY NOT NULL, originalID TEXT NOT NULL, kind TEXT NOT NULL,
            parserVersion INTEGER NOT NULL CHECK (parserVersion > 0), conditions BLOB NOT NULL,
            parsedAt REAL NOT NULL, payload BLOB NOT NULL,
            applicability TEXT NOT NULL DEFAULT 'unknown' CHECK (applicability = 'unknown'),
            UNIQUE (id, kind), UNIQUE (originalID, kind, parserVersion, conditions, parsedAt),
            FOREIGN KEY (originalID, kind) REFERENCES original (id, kind)
        );
        CREATE TABLE lesson (
            analysisID TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind = 'timetable'),
            ordinal INTEGER NOT NULL CHECK (ordinal >= 0), className TEXT NOT NULL,
            weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 5),
            period INTEGER NOT NULL CHECK (period BETWEEN 1 AND 8), payload BLOB NOT NULL,
            PRIMARY KEY (analysisID, ordinal),
            FOREIGN KEY (analysisID, kind) REFERENCES analysis (id, kind)
        );
        CREATE INDEX lesson_slot ON lesson (analysisID, className, weekday, period);
        CREATE TABLE changeRow (
            analysisID TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind = 'changes'),
            ordinal INTEGER NOT NULL CHECK (ordinal >= 0), actualDate TEXT NOT NULL,
            className TEXT NOT NULL, period TEXT NOT NULL, sourceRow INTEGER,
            payload BLOB NOT NULL, PRIMARY KEY (analysisID, ordinal),
            FOREIGN KEY (analysisID, kind) REFERENCES analysis (id, kind)
        );
        CREATE INDEX change_day ON changeRow (analysisID, actualDate, className);
        CREATE TABLE attempt (
            id INTEGER PRIMARY KEY, kind TEXT NOT NULL CHECK (kind IN ('timetable', 'changes', 'events')),
            operation TEXT NOT NULL CHECK (operation IN ('acquire', 'parse')),
            finishedAt REAL NOT NULL, succeeded INTEGER NOT NULL CHECK (succeeded IN (0, 1)), payload BLOB NOT NULL
        );
        CREATE TABLE currentLibrary (
            id INTEGER PRIMARY KEY CHECK (id = 1), generation INTEGER NOT NULL CHECK (generation >= 0), folder BLOB
        );
        CREATE TABLE currentRecord (
            kind TEXT PRIMARY KEY NOT NULL, originalID TEXT NOT NULL, record BLOB NOT NULL,
            position INTEGER NOT NULL UNIQUE,
            FOREIGN KEY (originalID, kind) REFERENCES original (id, kind)
        );
        CREATE TABLE currentAnalysis (
            kind TEXT PRIMARY KEY NOT NULL, analysisID TEXT NOT NULL,
            FOREIGN KEY (analysisID, kind) REFERENCES analysis (id, kind)
        );
        CREATE TRIGGER original_immutable BEFORE UPDATE ON original BEGIN SELECT RAISE(ABORT, 'immutable original'); END;
        CREATE TRIGGER analysis_immutable BEFORE UPDATE ON analysis BEGIN SELECT RAISE(ABORT, 'immutable analysis'); END;
        CREATE TRIGGER lesson_immutable BEFORE UPDATE ON lesson BEGIN SELECT RAISE(ABORT, 'immutable lesson'); END;
        CREATE TRIGGER change_immutable BEFORE UPDATE ON changeRow BEGIN SELECT RAISE(ABORT, 'immutable change'); END;
        """
}
