-- Удаление таблиц, если они существуют
DROP TABLE IF EXISTS Peers CASCADE;
DROP TABLE IF EXISTS Tasks CASCADE;
DROP TYPE IF EXISTS check_state CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TABLE IF EXISTS P2P CASCADE;
DROP TABLE IF EXISTS Verter CASCADE;
DROP TABLE IF EXISTS TransferredPoints CASCADE;
DROP TABLE IF EXISTS Friends CASCADE;
DROP TABLE IF EXISTS Recommendations CASCADE;
DROP TABLE IF EXISTS XP CASCADE;
DROP TABLE IF EXISTS TimeTracking CASCADE;

-- Создание всех заданных таблиц
CREATE TABLE Peers
(
    Nickname varchar NOT NULL PRIMARY KEY,
    Birthday date    NOT NULL
);

CREATE TABLE Tasks
(
    Title      varchar NOT NULL PRIMARY KEY,
    ParentTask varchar,
    MaxXP      integer NOT NULL,
    FOREIGN KEY (ParentTask) REFERENCES Tasks (Title)
);

CREATE TABLE Checks
(
    ID   integer PRIMARY KEY NOT NULL,
    Peer varchar             NOT NULL,
    Task varchar             NOT NULL,
    Date date                NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (Task) REFERENCES Tasks (Title)
);

CREATE TYPE check_state AS enum ( 'Start', 'Success', 'Failure' );

CREATE TABLE P2P
(
    ID           integer PRIMARY KEY NOT NULL,
    "Check"      integer             NOT NULL,
    CheckingPeer varchar             NOT NULL,
    State        check_state         NOT NULL,
    Time         time                NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID),
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname)
);

CREATE TABLE Verter
(
    ID      integer PRIMARY KEY NOT NULL,
    "Check" integer             NOT NULL,
    State   check_state         NOT NULL,
    Time    time                NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID)
);

CREATE TABLE TransferredPoints
(
    ID           integer PRIMARY KEY NOT NULL,
    CheckingPeer varchar             NOT NULL,
    CheckedPeer  varchar             NOT NULL,
    PointsAmount bigint              NOT NULL,
    FOREIGN KEY (CheckingPeer) REFERENCES Peers (Nickname),
    FOREIGN KEY (CheckedPeer) REFERENCES Peers (Nickname)
);

CREATE TABLE Friends
(
    ID    integer PRIMARY KEY NOT NULL,
    Peer1 varchar             NOT NULL,
    Peer2 varchar             NOT NULL,
    FOREIGN KEY (Peer1) REFERENCES Peers (Nickname),
    FOREIGN KEY (Peer2) REFERENCES Peers (Nickname)
);

CREATE TABLE Recommendations
(
    ID              integer PRIMARY KEY NOT NULL,
    Peer            varchar             NOT NULL,
    RecommendedPeer varchar             NOT NULL,
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname),
    FOREIGN KEY (RecommendedPeer) REFERENCES Peers (Nickname)
);

CREATE TABLE XP
(
    ID       integer PRIMARY KEY NOT NULL,
    "Check"  integer             NOT NULL,
    XPAmount integer             NOT NULL,
    FOREIGN KEY ("Check") REFERENCES Checks (ID)
);

CREATE TABLE TimeTracking
(
    ID     integer PRIMARY KEY NOT NULL,
    Peer   varchar             NOT NULL,
    "Date" date                NOT NULL,
    "Time" time                NOT NULL,
    State  int2                NOT NULL CHECK ( State IN (1, 2) ),
    FOREIGN KEY (Peer) REFERENCES Peers (Nickname)
);

-- Заполнение таблиц данными
INSERT INTO Peers (Nickname, Birthday)
VALUES ('achanel', '1992-05-09'),
       ('mmonarch', '1991-10-20'),
       ('rhoke', '1993-04-13'),
       ('fbeatris', '1994-09-28'),
       ('ikathrin', '1997-03-14'),
       ('ikael', '1998-01-07'),
       ('wsei', '1997-01-06'),
       ('bgenia', '1996-06-09');

INSERT INTO Tasks (Title, ParentTask, MaxXP)
VALUES ('C2_SimpleBashUtils', NULL, 250),
       ('C3_s21_string+', 'C2_SimpleBashUtils', 500),
       ('C4_s21_math', 'C2_SimpleBashUtils', 300),
       ('C5_s21_decimal', 'C4_s21_math', 350),
       ('C6_s21_matrix', 'C5_s21_decimal', 200),
       ('C7_SmartCalc_v1.0', 'C6_s21_matrix', 500),
       ('C8_3DViewer_v1.0', 'C7_SmartCalc_v1.0', 750),
       ('DO1_Linux', 'C3_s21_string+', 300),
       ('DO2_Linux Network', 'DO1_Linux', 250),
       ('DO3_LinuxMonitoring v1.0', 'DO2_Linux Network', 350),
       ('DO4_LinuxMonitoring v2.0', 'DO3_LinuxMonitoring v1.0', 350),
       ('DO5_SimpleDocker', 'DO3_LinuxMonitoring v1.0', 300),
       ('DO6_CICD', 'DO5_SimpleDocker', 300),
       ('CPP1_s21_matrix+', 'C8_3DViewer_v1.0', 300),
       ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350),
       ('CPP3_SmartCalc_v2.0', 'CPP2_s21_containers', 600),
       ('CPP4_3DViewer_v2.0', 'CPP3_SmartCalc_v2.0', 750),
       ('CPP5_3DViewer_v2.1', 'CPP4_3DViewer_v2.0', 600),
       ('CPP6_3DViewer_v2.2', 'CPP4_3DViewer_v2.0', 800),
       ('CPP7_MLP', 'CPP4_3DViewer_v2.0', 700),
       ('CPP8_PhotoLab_v1.0', 'CPP4_3DViewer_v2.0', 450),
       ('CPP9_MonitoringSystem', 'CPP4_3DViewer_v2.0', 1000),
       ('A1_Maze', 'CPP4_3DViewer_v2.0', 300),
       ('A2_SimpleNavigator v1.0', 'A1_Maze', 400),
       ('A3_Parallels', 'A2_SimpleNavigator v1.0', 300),
       ('A4_Crypto', 'A2_SimpleNavigator v1.0', 350),
       ('A5_s21_memory', 'A2_SimpleNavigator v1.0', 400),
       ('A6_Transactions', 'A2_SimpleNavigator v1.0', 700),
       ('A7_DNA Analyzer', 'A2_SimpleNavigator v1.0', 800),
       ('A8_Algorithmic trading', 'A2_SimpleNavigator v1.0', 800),
       ('SQL1_Bootcamp', 'C8_3DViewer_v1.0', 1500),
       ('SQL2_Info21 v1.0', 'SQL1_Bootcamp', 500),
       ('SQL3_RetailAnalitycs v1.0', 'SQL2_Info21 v1.0', 600);

INSERT INTO Checks (ID, Peer, Task, Date)
VALUES (1, 'bgenia', 'SQL1_Bootcamp', '2023-06-09'),
       (2, 'rhoke', 'A6_Transactions', '2023-06-09'),
       (3, 'wsei', 'A3_Parallels', '2023-01-06'),
       (4, 'fbeatris', 'CPP9_MonitoringSystem', '2023-02-26'),
       (5, 'ikathrin', 'CPP6_3DViewer_v2.2', '2023-01-20'),
       (6, 'mmonarch', 'CPP2_s21_containers', '2022-06-30'),
       (7, 'achanel', 'C8_3DViewer_v1.0', '2022-05-09'),
       (8, 'rhoke', 'A7_DNA Analyzer', '2022-11-09'),
       (9, 'achanel', 'DO2_Linux Network', '2022-11-30'),
       (10, 'rhoke', 'SQL1_Bootcamp', '2022-09-01'),
       (11, 'achanel', 'SQL1_Bootcamp', '2023-06-08'),
       (12, 'achanel', 'SQL1_Bootcamp', '2022-09-01'),
       (13, 'mmonarch', 'SQL1_Bootcamp', '2023-06-09'),
       (14, 'rhoke', 'SQL1_Bootcamp', '2023-06-10');

INSERT INTO P2P (ID, "Check", CheckingPeer, State, Time)
VALUES (1, 1, 'achanel', 'Start', '18:30:21'),
       (2, 1, 'achanel', 'Success', '19:01:12'),

       (3, 2, 'mmonarch', 'Start', '13:02:01'),
       (4, 2, 'mmonarch', 'Success', '13:10:01'),

       (5, 3, 'ikathrin', 'Start', '09:11:45'),
       (6, 3, 'ikathrin', 'Failure', '11:06:23'),

       (7, 4, 'rhoke', 'Start', '19:10:45'),
       (8, 4, 'rhoke', 'Success', '20:06:23'),

       (9, 5, 'ikael', 'Start', '20:11:45'),
       (10, 5, 'ikael', 'Success', '20:15:23'),

       (11, 6, 'wsei', 'Start', '00:00:00'),

       (12, 7, 'bgenia', 'Start', '11:11:45'),
       (13, 7, 'bgenia', 'Success', '11:15:23'),

       (14, 8, 'achanel', 'Start', '10:51:45'),
       (15, 8, 'achanel', 'Success', '11:15:13'),

       (16, 10, 'ikael', 'Start', '10:51:45'),
       (17, 10, 'ikael', 'Failure', '11:15:13'),

       (18, 11, 'bgenia', 'Start', '10:00:01'),
       (19, 11, 'bgenia', 'Failure', '10:15:01'),

       (20, 12, 'bgenia', 'Start', '10:00:01'),
       (21, 12, 'bgenia', 'Success', '10:15:01'),

       (22, 13, 'achanel', 'Start', '22:00:01'),
       (23, 13, 'achanel', 'Success', '22:15:01'),

       (24, 14, 'mmonarch', 'Start', '09:00:01'),
       (25, 14, 'mmonarch', 'Success', '09:15:01');



INSERT INTO Verter (ID, "Check", State, Time)
VALUES (1, 1, 'Start', '19:21:12'),
       (2, 1, 'Success', '19:51:12'),

       (3, 2, 'Start', '13:30:01'),
       (4, 2, 'Success', '14:00:01'),

       (5, 4, 'Start', '20:26:23'),
       (6, 4, 'Success', '20:56:23'),

       (7, 5, 'Start', '19:21:12'),
       (8, 5, 'Success', '19:51:12'),

       (9, 7, 'Start', '11:35:23'),
       (10, 7, 'Failure', '12:05:23'),

       (11, 8, 'Start', '11:35:13'),
       (12, 8, 'Success', '12:05:13');

INSERT INTO TransferredPoints (ID, CheckingPeer, CheckedPeer, PointsAmount)
VALUES (1, 'achanel', 'bgenia', 5),
       (2, 'mmonarch', 'rhoke', 1),
       (3, 'ikathrin', 'wsei', 1),
       (4, 'rhoke', 'mmonarch', 2),
       (5, 'wsei', 'ikathrin', 1),
       (6, 'bgenia', 'achanel', 3),
       (7, 'achanel', 'rhoke', 1),
       (8, 'rhoke', 'achanel', 5);

INSERT INTO Friends (ID, Peer1, Peer2)
VALUES (1, 'achanel', 'mmonarch'),
       (2, 'achanel', 'ikathrin'),
       (3, 'ikael', 'wsei'),
       (4, 'ikathrin', 'mmonarch'),
       (5, 'mmonarch', 'rhoke'),
       (6, 'fbeatris', 'wsei'),
       (7, 'wsei', 'achanel'),
       (8, 'bgenia', 'rhoke');

INSERT INTO Recommendations (ID, Peer, RecommendedPeer)
VALUES (1, 'achanel', 'mmonarch'),
       (2, 'achanel', 'rhoke'),
       (3, 'rhoke', 'wsei'),
       (4, 'ikael', 'fbeatris'),
       (5, 'mmonarch', 'bgenia'),
       (6, 'bgenia', 'ikathrin'),
       (7, 'ikael', 'achanel'),
       (8, 'mmonarch', 'achanel');

INSERT INTO XP (ID, "Check", XPAmount)
VALUES (1, 1, 1500),
       (2, 2, 700),
       (3, 4, 1000),
       (4, 5, 800),
       (5, 8, 800),
       (6, 1, 1500),
       (7, 2, 700),
       (8, 4, 1000),
       (9, 5, 800),
       (10, 8, 800);

INSERT INTO TimeTracking (ID, Peer, "Date", "Time", State)
VALUES (1, 'mmonarch', '2023-01-30', '11:05:16', 1),
       (2, 'mmonarch', '2023-01-30', '20:15:22', 2),
       (3, 'achanel', '2023-02-01', '17:13:01', 1),
       (4, 'achanel', '2023-02-01', '03:10:12', 2),
       (5, 'rhoke', '2022-09-03', '12:45:38', 1),
       (6, 'rhoke', '2022-09-03', '22:43:56', 2),
       (7, 'ikathrin', '2022-12-23', '08:00:00', 1),
       (8, 'ikathrin', '2023-12-23', '21:00:00', 2),
       (9, 'wsei', '2020-01-02', '00:00:00', 1),
       (10, 'wsei', '2020-01-02', '03:02:11', 2),
       (11, 'wsei', '2020-01-02', '03:11:00', 1),
       (12, 'wsei', '2020-01-02', '04:00:00', 2),
       (13, 'rhoke', '2023-04-20', '03:11:00', 1),
       (14, 'rhoke', '2023-04-20', '04:11:00', 2),
       (15, 'rhoke', '2023-04-21', '03:11:00', 1),
       (16, 'rhoke', '2023-04-21', '04:11:00', 2),
       (17, 'rhoke', '2023-04-23', '03:11:00', 1),
       (18, 'rhoke', '2023-04-23', '04:11:00', 2),
       (19, 'rhoke', '2023-04-23', '13:11:00', 1),
       (20, 'rhoke', '2023-04-23', '04:11:00', 2),
       (21, 'rhoke', '2023-04-23', '13:11:00', 1),
       (22, 'rhoke', '2023-04-23', '04:11:00', 2);

-- Процедуры экспорта и импорта их .csv файла
DROP PROCEDURE IF EXISTS export() CASCADE;

CREATE OR REPLACE PROCEDURE export(IN tablename varchar, IN path text, IN separator char) AS
$$
BEGIN
    EXECUTE FORMAT('copy %s to ''%s'' delimiter ''%s'' csv header;',
                   tablename, path, separator);
END;
$$ LANGUAGE plpgsql;

DROP PROCEDURE IF EXISTS import() CASCADE;

CREATE OR REPLACE PROCEDURE import(IN tablename varchar, IN path text, IN separator char) AS
$$
BEGIN
    EXECUTE FORMAT('copy %s from ''%s'' delimiter ''%s'' csv header;',
                   tablename, path, separator);
END;
$$ LANGUAGE plpgsql;

-- -- Тестирование работы процедур
-- -- Запись таблиц в файлы
-- CALL export('Peers', '/tmp/peers.csv', ',');
-- CALL export('Tasks', '/tmp/tasks.csv', ',');
-- CALL export('Checks', '/tmp/checks.csv', ',');
-- CALL export('P2P', '/tmp/p2p.csv', ',');
-- CALL export('verter', '/tmp/verter.csv', ',');
-- CALL export('transferredpoints', '/tmp/transferredpoints.csv', ',');
-- CALL export('friends', '/tmp/friends.csv', ',');
-- CALL export('recommendations', '/tmp/recommendations.csv', ',');
-- CALL export('xp', '/tmp/xp.csv', ',');
-- CALL export('timetracking', '/tmp/timetracking.csv', ',');
--
-- -- Удвление запись из таблиц
-- TRUNCATE TABLE Peers CASCADE;
-- TRUNCATE TABLE Tasks CASCADE;
-- TRUNCATE TABLE Checks CASCADE;
-- TRUNCATE TABLE P2P CASCADE;
-- TRUNCATE TABLE Verter CASCADE;
-- TRUNCATE TABLE Transferredpoints CASCADE;
-- TRUNCATE TABLE Friends CASCADE;
-- TRUNCATE TABLE Recommendations CASCADE;
-- TRUNCATE TABLE XP CASCADE;
-- TRUNCATE TABLE TimeTracking CASCADE;
--
-- -- Заполнение таблиц данными из файлов
-- CALL import('Peers', '/tmp/peers.csv', ',');
-- CALL import('Tasks', '/tmp/tasks.csv', ',');
-- CALL import('Checks', '/tmp/checks.csv', ',');
-- CALL import('P2P', '/tmp/p2p.csv', ',');
-- CALL import('verter', '/tmp/verter.csv', ',');
-- CALL import('transferredpoints', '/tmp/transferredpoints.csv', ',');
-- CALL import('friends', '/tmp/friends.csv', ',');
-- CALL import('recommendations', '/tmp/recommendations.csv', ',');
-- CALL import('xp', '/tmp/xp.csv', ',');
-- CALL import('timetracking', '/tmp/timetracking.csv', ',');