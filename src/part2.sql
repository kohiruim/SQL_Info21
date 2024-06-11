-- 2.1) Процедура добавления P2P проверки

CREATE OR REPLACE PROCEDURE add_P2P(nickname_checked VARCHAR, nickname_checking VARCHAR,
                                    project_name VARCHAR, project_state check_state, check_time time)
AS
$$
BEGIN
    IF (check_input(project_name, project_state, nickname_checked, nickname_checking))
    THEN
        INSERT INTO checks (id, peer, task, date)
        VALUES ((SELECT MAX(id) + 1 FROM checks), nickname_checked, project_name, NOW()::DATE);
        INSERT INTO p2p (id, "Check", checkingPeer, state, time)
        VALUES ((SELECT MAX(id) + 1 FROM P2P), (SELECT MAX(id) FROM Checks), nickname_checking,
                project_state, check_time);
    ELSE
        INSERT INTO p2p (id, "Check", checkingPeer, state, time)
        VALUES ((SELECT MAX(id) + 1 FROM p2p),
                (SELECT "Check"
                 FROM p2p
                          JOIN checks ON p2p."Check" = checks.id
                 WHERE p2p.checkingPeer = nickname_checking
                   AND checks.peer = nickname_checked
                   AND checks.task = project_name),
                nickname_checking, project_state, check_time);
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION count_incomplete_check(project_name VARCHAR, nickname_checked VARCHAR,
                                                  nickname_checking VARCHAR)
    RETURNS INT AS
$$
BEGIN
    RETURN (SELECT COUNT(*)
            FROM p2p
                     JOIN checks ON p2p."Check" = checks.id
            WHERE checks.task = project_name
              AND checks.peer = nickname_checked
              AND p2p.checkingPeer = nickname_checking);
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_p2p_parentTask(project_name VARCHAR, nickname_checked VARCHAR,
                                                nickname_checking VARCHAR)
    RETURNS BOOLEAN AS
$$
BEGIN
    IF ((SELECT parentTask FROM tasks WHERE title = project_name) IS NULL)
    THEN
        RETURN 'true';
    ELSE
        RETURN (SELECT COUNT(*)
                FROM p2p
                         JOIN checks ON p2p."Check" = checks.id
                WHERE checks.peer = nickname_checked
                  AND p2p.State = 'Success'
                  AND checks.Task = (SELECT parentTask FROM tasks WHERE title = project_name));
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_verter_parentTask(project_name VARCHAR, nickname_checked VARCHAR,
                                                   nickname_checking VARCHAR)
    RETURNS BOOLEAN AS
$$
BEGIN
    IF ((SELECT COUNT(*)
         FROM verter
                  JOIN checks ON verter."Check" = checks.id
         WHERE checks.peer = nickname_checked
           AND verter.State = 'Start'
           AND checks.Task = (SELECT parentTask FROM tasks WHERE title = project_name)) = 0)
    THEN
        RETURN 'true';
    ELSE
        RETURN (SELECT COUNT(*)
                FROM verter
                         JOIN checks ON verter."Check" = checks.id
                WHERE checks.peer = nickname_checked
                  AND verter.state = 'Success'
                  AND checks.task = (SELECT parentTask FROM tasks WHERE title = project_name));
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_input(project_name VARCHAR, project_state check_state, nickname_checked VARCHAR,
                                       nickname_checking VARCHAR)
    RETURNS BOOLEAN AS
$$
BEGIN
    IF (nickname_checking = nickname_checked)
    THEN
        RAISE EXCEPTION 'Проверяющий не может проверять сам себя';
    ELSEIF (project_state != 'Start')
    THEN
        RAISE EXCEPTION 'Статус проекта мб только старт';
    ELSEIF (count_incomplete_check(project_name, nickname_checked, nickname_checking) = 1)
    THEN
        RAISE EXCEPTION 'Добавление проверки невозможно. У пиров есть незавершенная проверка';
    ELSEIF (project_name NOT IN (SELECT Title FROM Tasks))
    THEN
        RAISE EXCEPTION 'Косяк в названии задания';
    ELSEIF (check_p2p_parentTask(project_name, nickname_checked, nickname_checking) = 'false')
    THEN
        RAISE EXCEPTION 'У проверяемого пира родительский проект не прошел пир-ревью';
    ELSEIF (check_verter_parentTask(project_name, nickname_checked, nickname_checking) = 'false')
    THEN
        RAISE EXCEPTION 'Пир не может проверить этот проект. У него родительский проект не прошел вертера';
    ELSE
        RETURN 'true';
    END IF;
END
$$ LANGUAGE plpgsql;

-- Проверка функции:

-- Старт при фейле родительского проекта
-- CALL add_P2P('achanel', 'ikael', 'DO2_Linux Network', 'Start'::check_state, '18:22:00');
-- старт, когда родительский проект - null
-- CALL add_P2P('mmonarch', 'ikael', 'C2_SimpleBashUtils', 'Start'::check_state, '18:22:00');
-- SELECT * FROM p2p JOIN Checks ON p2p."Check" = Checks.id;
-- Старт, когда нет или зафейлен пир-ревью родительского проекта
-- CALL add_P2P('mmonarch', 'ikael', 'A3_Parallels', 'Start'::check_state, '18:22:00');
-- старт, когда все ок
-- CALL add_P2P('bgenia', 'ikael', 'SQL2_Info21 v1.0', 'Start'::check_state, '18:22:00');
-- SELECT * FROM p2p JOIN Checks ON p2p."Check" = Checks.id;
-- Добавление проверки проекта для пиров или проверяющего незавершенной проверки
-- CALL add_P2P('mmonarch', 'wsei', 'CPP2_s21_containers', 'Start'::check_state, '19:21:00');
-- Добавление проверки проекта для пиров, когда статус не старт
-- CALL add_P2P('ikathrin', 'wsei', 'CPP2_s21_containers', 'Failure'::check_state, '19:45:56');
-- Если пир собрался проверять самого себя
-- CALL add_P2P('wsei', 'wsei', 'CPP2_s21_containers', 'Start'::check_state, '19:21:00');

-- 2.2) процедура добавления проверки Verter'ом

CREATE OR REPLACE PROCEDURE add_verter(nickname_checked VARCHAR, project_name VARCHAR,
                                       project_state check_state, check_time time)
AS
$$
BEGIN
    IF (check_verter_input(project_name, project_state, nickname_checked, check_time))
    THEN
        INSERT INTO verter
        VALUES ((SELECT MAX(id) + 1 FROM verter),
                get_checkId_lastP2P(project_name, nickname_checked),
                project_state, check_time);
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION check_verter_input(project_name VARCHAR, project_state check_state, nickname_checked VARCHAR,
                                              check_time time)
    RETURNS BOOLEAN AS
$$
BEGIN
    IF (project_state != 'Start')
    THEN
        RAISE EXCEPTION 'Статус проекта мб только старт';
    ELSEIF (project_name NOT IN (SELECT Title FROM Tasks))
    THEN
        RAISE EXCEPTION 'Косяк в названии задания';
    ELSEIF (get_checkId_lastP2P(project_name, nickname_checked) IS NULL)
    THEN
        RAISE EXCEPTION 'Нет такого проекта в последних успешных P2P проверках';
    ELSEIF ((SELECT COUNT(*)
             FROM verter
             WHERE project_state = 'Start'
               AND "Check" = get_checkId_lastP2P(project_name, nickname_checked)) >
            (SELECT COUNT(*)
             FROM verter
             WHERE project_state != 'Start'
               AND "Check" = get_checkId_lastP2P(project_name, nickname_checked)))
    THEN
        RAISE EXCEPTION 'Вертер уже проверяет этот проект';
    ELSE
        RETURN 'true';
    END IF;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_checkId_lastP2P(project_name VARCHAR, nickname_checked VARCHAR)
    RETURNS INT AS
$$
BEGIN
    RETURN (SELECT Checks.id
            FROM p2p
                     INNER JOIN checks ON p2p."Check" = Checks.id
            WHERE task = project_name
              AND p2p.state = 'Success'
              AND checks.peer = nickname_checked
            ORDER BY date DESC, time DESC
            LIMIT 1);
END
$$ LANGUAGE plpgsql;

-- 1. когда все ок
-- CALL add_verter('achanel', 'SQL1_Bootcamp', 'Start'::check_state, '18:22:00');
-- select * from verter join checks on verter."Check" = Checks.id
-- delete from verter where id >12;
-- 2. вертер уже проверяет проект
-- CALL add_verter('achanel', 'SQL1_Bootcamp', 'Start'::check_state, '18:22:00');
-- CALL add_verter('achanel', 'SQL1_Bootcamp', 'Start'::check_state, '18:22:00');
-- 3. Нет такого проекта в последних успешных P2P проверках
-- CALL add_verter('wsei', 'A3_Parallels', 'Start'::check_state, '18:22:00');

-- 2.3) Триггер: после добавления записи со статутом "начало" в таблицу P2P, изменить соответствующую запись в таблице TransferredPoints

CREATE OR REPLACE FUNCTION fnc_trg_TransferredPoints()
    RETURNS TRIGGER AS
$TransferredPoints$
BEGIN
    IF (NEW.State = 'Start')
    THEN
        IF ((SELECT COUNT(*)
             FROM TransferredPoints AS tp
             WHERE NEW.CheckingPeer = tp.CheckingPeer
               AND (SELECT checks.peer
                    FROM p2p
                             INNER JOIN Checks ON p2p."Check" = Checks.id
                    WHERE p2p."Check" = NEW."Check"
                      AND STATE = 'Start'
                      AND p2p.CheckingPeer = NEW.CheckingPeer) = tp.CheckedPeer) = 0)
        THEN
            INSERT INTO TransferredPoints
            VALUES ((SELECT MAX(id) + 1 FROM TransferredPoints),
                    NEW.CheckingPeer,
                    (SELECT checks.peer
                     FROM p2p
                              INNER JOIN Checks ON p2p."Check" = Checks.id
                     WHERE p2p."Check" = NEW."Check"),
                    1);
        ELSE
            WITH checked AS (SELECT Checks.Peer AS peer
                             FROM P2P
                                      INNER JOIN Checks ON P2P."Check" = Checks.id
                             WHERE State = 'Start'
                               AND NEW."Check" = Checks.id)
            UPDATE TransferredPoints
            SET PointsAmount = PointsAmount + 1
            FROM checked
            WHERE checked.peer = TransferredPoints.CheckedPeer
              AND NEW.CheckingPeer = TransferredPoints.CheckingPeer;
        END IF;
    END IF;
    RETURN NULL;
END;
$TransferredPoints$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_TransferredPoints ON P2P;
CREATE TRIGGER trg_TransferredPoints
    AFTER INSERT
    ON P2P
    FOR EACH ROW
EXECUTE FUNCTION Fnc_trg_TransferredPoints();

-- 1. добавление новой пары проверяющий - проверяемый в TPounts
-- CALL add_P2P('bgenia', 'mmonarch', 'SQL2_Info21 v1.0', 'Start'::check_state, '18:22:00');
-- SELECT * FROM TransferredPoints;
-- SELECT * FROM p2p JOIN Checks ON p2p."Check" = Checks.id;
-- 2. апдейт старой пары (+1хр)

/*insert into p2p
values ((select max(id)+1 from p2p),
	    (select p2p."Check" from p2p join checks on p2p."Check" = checks.id
		  where checkingPeer = 'ikael' AND checks.peer = 'bgenia' AND state = 'Start' AND checks.task = 'SQL2_Info21 v1.0'),
		'ikael', 'Success'::check_state, '18:55:00'); */

-- CALL add_P2P('bgenia', 'ikael', 'SQL3_RetailAnalitycs v1.0', 'Start'::check_state, '20:22:00');
-- SELECT * FROM p2p JOIN Checks ON p2p."Check" = Checks.id;
-- SELECT * FROM TransferredPoints;

-- 2.4) триггер: перед добавлением записи в таблицу XP, проверить корректность добавляемой записи

CREATE OR REPLACE FUNCTION fnc_trg_XP()
    RETURNS TRIGGER AS
$XP$
BEGIN
    IF (NEW."Check" NOT IN (SELECT id FROM Checks))
    THEN
        RAISE EXCEPTION 'Ошибка, такого id проверки не существует';
    ELSEIF ((SELECT COUNT(*)
             FROM XP
                      INNER JOIN checks ON NEW."Check" = Checks.id
                      INNER JOIN p2p ON NEW."Check" = p2p."Check"
             WHERE checks.id = NEW."Check"
               AND P2P.state = 'Success') = 0)
    THEN
        RAISE EXCEPTION 'Пир либо зафейлил P2P проверку, либо не начинал ее проверку вообще';
    ELSEIF ((SELECT COUNT(*)
             FROM xp
                      INNER JOIN checks ON NEW."Check" = Checks.id
                      INNER JOIN verter ON Checks.id = verter."Check"
             WHERE state = 'Start'
               AND checks.id = NEW."Check")) > 0 AND
           ((SELECT COUNT(*)
             FROM xp
                      INNER JOIN checks ON NEW."Check" = Checks.id
                      INNER JOIN verter ON Checks.id = verter."Check"
             WHERE state = 'Success'
               AND checks.id = NEW."Check") = 0)
    THEN
        RAISE EXCEPTION 'Проект зафейлен вертером';
    ELSEIF (NEW.XPAmount < 0)
    THEN
        RAISE EXCEPTION 'XP не мб меньше 0';
    ELSEIF (NEW.XPAmount > (SELECT maxXP
                            FROM xp
                                     INNER JOIN checks ON NEW."Check" = Checks.id
                                     INNER JOIN tasks ON Checks.task = tasks.title
                            WHERE checks.id = XP."Check"
                            GROUP BY 1))
    THEN
        RAISE EXCEPTION 'Количество зачисляемой XP не мб больше максимальной XP за проект';
    END IF;
    RETURN NULL;
END
$XP$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_XP ON XP;
CREATE TRIGGER trg_XP
    BEFORE INSERT
    ON XP
    FOR EACH ROW
EXECUTE FUNCTION Fnc_trg_XP();


-- 1. проверка maxXP
-- INSERT INTO XP VALUES ((select max(id)+1 from XP), 5, 5000);
-- проверка на ckecks.id
-- 2. INSERT INTO XP VALUES ((select max(id)+1 from XP), 1000, 5);
-- проверка на фейл п2п
-- INSERT INTO XP VALUES ((select max(id)+1 from XP), 3, 100);
-- 3. проверка на id
-- INSERT INTO XP VALUES ((select max(id)+1 from XP), 100, 100);
