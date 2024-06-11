-- part 3.1

DROP FUNCTION IF EXISTS fnc_transferred_points();
CREATE OR REPLACE FUNCTION fnc_transferred_points()
    RETURNS TABLE
            (
                Peer1        varchar,
                Peer2        varchar,
                PointsAmount bigint
            )
AS
$$
SELECT t1.checkingpeer AS Peer1, t1.checkedpeer AS Peer2, (t1.pointsamount - t2.pointsamount) AS PointsAmount
FROM transferredpoints AS t1
         JOIN transferredpoints AS t2
              ON t1.checkedpeer = t2.checkingpeer AND t1.checkingpeer = t2.checkedpeer AND t1.id < t2.id
$$ LANGUAGE SQL;

-- SELECT *
-- FROM fnc_transferred_points();

-- part 3.2

DROP FUNCTION IF EXISTS fnc_xp_check();
CREATE OR REPLACE FUNCTION fnc_xp_check()
    RETURNS TABLE
            (
                Peer varchar,
                Task varchar,
                XP   integer
            )
AS
$$
SELECT peer AS Peer, task AS Task, xpamount AS XP
FROM checks
         JOIN xp x ON checks.id = x."Check"
$$ LANGUAGE SQL;

-- SELECT *
-- FROM fnc_xp_check();

-- part 3.3

DROP FUNCTION IF EXISTS fnc_time_tracking(d date);
CREATE OR REPLACE FUNCTION fnc_time_tracking(d date)
    RETURNS TABLE
            (
                Peer varchar
            )
AS
$$
SELECT peer AS Peer
FROM (SELECT peer, SUM(state) AS num
      FROM timetracking
      WHERE "Date" = d
      GROUP BY 1) t1
WHERE num = 3
$$ LANGUAGE SQL;

-- SELECT *
-- FROM fnc_time_tracking('2022-09-03');

-- part 3.4

DROP PROCEDURE IF EXISTS get_peer_points_change(ref refcursor);
CREATE OR REPLACE PROCEDURE get_peer_points_change(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT Peer, SUM(PointChange) AS PointChange
        FROM ((SELECT checkingpeer AS Peer, SUM(pointsamount) AS PointChange
               FROM transferredpoints
               GROUP BY 1)
              UNION ALL
              (SELECT checkedpeer AS Peer, SUM(pointsamount) * (-1) AS PointChange
               FROM transferredpoints
               GROUP BY 1)) t1
        GROUP BY 1
        ORDER BY 2 DESC, 1;
END;
$$;

-- BEGIN;
-- CALL get_peer_points_change('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.5

DROP PROCEDURE IF EXISTS get_peer_points_change_from_prc(ref refcursor);
CREATE OR REPLACE PROCEDURE get_peer_points_change_from_prc(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        (SELECT peer1 AS Peer, SUM(pointsamount) AS PointChange
         FROM fnc_transferred_points()
         GROUP BY 1)
        UNION ALL
        (SELECT peer2 AS Peer, SUM(pointsamount) * (-1) AS PointChange
         FROM fnc_transferred_points()
         GROUP BY 1)
        ORDER BY 2 DESC, 1;
END;
$$;

-- BEGIN;
-- CALL get_peer_points_change_from_prc('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.6

DROP PROCEDURE IF EXISTS get_most_frequent_task(ref refcursor);
CREATE OR REPLACE PROCEDURE get_most_frequent_task(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT date AS Day, task AS Task
        FROM (SELECT date,
                     task,
                     RANK() OVER (PARTITION BY date ORDER BY COUNT(*) DESC) AS r
              FROM checks
              GROUP BY date, task) sub
        WHERE r = 1
        ORDER BY 1 DESC;
END;
$$;

-- BEGIN;
-- CALL get_most_frequent_task('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.7

DROP PROCEDURE IF EXISTS get_peers_with_completed_block(block varchar, ref refcursor);
CREATE OR REPLACE PROCEDURE get_peers_with_completed_block(block varchar, ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH t1 AS (SELECT MAX(title) AS task
                    FROM tasks
                    WHERE title SIMILAR TO CONCAT(block, '[0-9]%'))
        SELECT c.peer AS Peer, date AS Day
        FROM checks c
                 JOIN t1 ON t1.task = c.task
                 JOIN p2p p ON c.id = p."Check"
                 JOIN verter v ON c.id = v."Check"
        WHERE p.state = 'Success'
          AND (v.state = 'Success' OR v.state IS NULL);
END;
$$;

-- BEGIN;
-- CALL get_peers_with_completed_block('CPP', 'procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.8

DROP PROCEDURE IF EXISTS get_recommended_peer(ref refcursor);
CREATE OR REPLACE PROCEDURE get_recommended_peer(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH test AS (SELECT peer1, recommendedpeer, COUNT(*) AS c
                      FROM friends
                               JOIN peers p ON p.nickname = friends.peer1
                               JOIN recommendations r ON p.nickname = r.peer
                      GROUP BY 1, 2)
        SELECT peer1 AS Peer, MIN(recommendedpeer) AS RecommendedPeer
        FROM test
        WHERE c = (SELECT MAX(c)
                   FROM test AS test2
                   WHERE test.peer1 = test2.peer1)
        GROUP BY 1;
END;
$$;

-- BEGIN;
-- CALL get_recommended_peer('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.9

DROP PROCEDURE IF EXISTS get_percentage_of_peers_started_blocks(block1 varchar, block2 varchar, ref refcursor);
CREATE OR REPLACE PROCEDURE get_percentage_of_peers_started_blocks(block1 varchar, block2 varchar, ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH t1 AS
                 (SELECT DISTINCT peer
                  FROM checks
                  WHERE task SIMILAR TO CONCAT(block1, '[0-9]%')),
             t2 AS
                 (SELECT DISTINCT peer
                  FROM checks
                  WHERE task SIMILAR TO CONCAT(block2, '[0-9]%')),
             t3 AS
                 (SELECT t1.peer
                  FROM t1
                           JOIN t2 ON t1.peer = t2.peer),
             t4 AS
                 (SELECT DISTINCT peer
                  FROM checks
                  WHERE task NOT SIMILAR TO CONCAT(block1, '[0-9]%')
                    AND task NOT SIMILAR TO CONCAT(block2, '[0-9]%'))

        SELECT (SELECT COUNT(peer) FROM t1) * 100 / (SELECT COUNT(nickname) FROM peers) AS StartedBlock1,
               (SELECT COUNT(peer) FROM t2) * 100 / (SELECT COUNT(nickname) FROM peers) AS StartedBlock2,
               (SELECT COUNT(peer) FROM t3) * 100 / (SELECT COUNT(nickname) FROM peers) AS StartedBothBlocks,
               (SELECT COUNT(peer) FROM t4) * 100 / (SELECT COUNT(nickname) FROM peers) AS DidntStartAnyBlock;
END;
$$;

-- BEGIN;
-- CALL get_percentage_of_peers_started_blocks('A', 'CPP', 'procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.10

DROP PROCEDURE IF EXISTS get_percentage_peers_checks(ref refcursor);
CREATE OR REPLACE PROCEDURE get_percentage_peers_checks(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH success AS (SELECT p.nickname,
                                CONCAT(EXTRACT(DAY FROM p.birthday), '-', EXTRACT(MONTH FROM p.birthday)) AS bd
                         FROM peers p
                                  JOIN checks c ON p.nickname = c.peer
                             AND CONCAT(EXTRACT(DAY FROM p.birthday), '-', EXTRACT(MONTH FROM p.birthday)) =
                                 CONCAT(EXTRACT(DAY FROM c.date), '-', EXTRACT(MONTH FROM c.date))
                                  JOIN verter v ON c.id = v."Check"
                                  JOIN p2p ON c.id = p2p."Check"
                         WHERE v.state = 'Success'
                           AND p2p.state = 'Success'),
             fail AS (SELECT p.nickname, CONCAT(EXTRACT(DAY FROM p.birthday), '-', EXTRACT(MONTH FROM p.birthday)) AS bd
                      FROM peers p
                               JOIN checks c ON p.nickname = c.peer
                          AND CONCAT(EXTRACT(DAY FROM p.birthday), '-', EXTRACT(MONTH FROM p.birthday)) =
                              CONCAT(EXTRACT(DAY FROM c.date), '-', EXTRACT(MONTH FROM c.date))
                               JOIN p2p ON c.id = p2p."Check"
                               LEFT JOIN verter v ON c.id = v."Check"
                      WHERE (p2p.state = 'Success' AND v.state = 'Failure')
                         OR (p2p.state = 'Failure'))
        SELECT (SELECT COUNT(nickname) FROM success) * 100 / (SELECT COUNT(nickname) FROM peers) AS SuccessfulChecks,
               (SELECT COUNT(nickname) FROM fail) * 100 / (SELECT COUNT(nickname) FROM peers)    AS UnsuccessfulChecks;
END;
$$;

-- BEGIN;
-- CALL get_percentage_peers_checks('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.11

DROP PROCEDURE IF EXISTS get_peers_who_given_tasks(first_task varchar, second_task varchar, third_task varchar,
                                                   ref refcursor);
CREATE OR REPLACE PROCEDURE get_peers_who_given_tasks(first_task varchar, second_task varchar, third_task varchar,
                                                      ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH t1 AS (SELECT peer
                    FROM checks
                             JOIN p2p p ON checks.id = p."Check"
                             JOIN verter v ON checks.id = v."Check"
                    WHERE task = first_task
                      AND p.state = 'Success'
                      AND (v.state = 'Success' OR v.state IS NULL)),
             t2 AS (SELECT peer
                    FROM checks
                             JOIN p2p p ON checks.id = p."Check"
                             JOIN verter v ON checks.id = v."Check"
                    WHERE task = second_task
                      AND p.state = 'Success'
                      AND (v.state = 'Success' OR v.state IS NULL)),
             t3 AS (SELECT peer
                    FROM checks
                             JOIN p2p p ON checks.id = p."Check"
                             LEFT JOIN verter v ON checks.id = v."Check"
                    WHERE ((p.state = 'Success' AND v.state = 'Failure')
                        OR (p.state = 'Failure'))
                      AND task = third_task)
        SELECT peer
        FROM t3
                 NATURAL JOIN t1
                 NATURAL JOIN t2;
END;
$$;

-- BEGIN;
-- CALL get_peers_who_given_tasks('A6_Transactions', 'A7_DNA Analyzer', 'SQL1_Bootcamp', 'procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.12

DROP PROCEDURE IF EXISTS get_number_of_tasks(ref refcursor);
CREATE OR REPLACE PROCEDURE get_number_of_tasks(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH RECURSIVE recursive AS
                           (SELECT title, parenttask
                            FROM tasks
                            UNION ALL
                            SELECT t.title, t.parenttask
                            FROM tasks t
                                     JOIN recursive ON t.parenttask = recursive.title
                            WHERE recursive.parenttask IS NOT NULL)
        SELECT title AS Task, COUNT(parenttask) AS PrevCount
        FROM recursive
        GROUP BY 1
        ORDER BY 2, 1;

END;
$$;

-- BEGIN;
-- CALL get_number_of_tasks('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.13

DROP PROCEDURE IF EXISTS get_lucky_days(N integer, ref refcursor);
CREATE OR REPLACE PROCEDURE get_lucky_days(N integer, ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT date
        FROM (SELECT *
              FROM checks
                       JOIN p2p p ON checks.id = p."Check"
                       JOIN verter v ON checks.id = v."Check"
                       JOIN tasks t2 ON checks.task = t2.title
                       JOIN xp x ON checks.id = x."Check"
              WHERE p.state = 'Success'
                AND (v.state = 'Success' OR v.state IS NULL)) AS t1
        WHERE t1.xpamount >= t1.maxxp * 0.8
        GROUP BY date
        HAVING COUNT(*) >= N;
END;
$$;

-- BEGIN;
-- CALL get_lucky_days(2, 'procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.14

DROP PROCEDURE IF EXISTS get_max_xp(ref refcursor);
CREATE OR REPLACE PROCEDURE get_max_xp(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT nickname, SUM(xpamount)
        FROM peers
                 JOIN checks c ON peers.nickname = c.peer
                 JOIN xp x ON c.id = x."Check"
        GROUP BY 1
        ORDER BY 2 DESC
        LIMIT 1;
END;
$$;

-- BEGIN;
-- CALL get_max_xp('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.15

DROP PROCEDURE IF EXISTS get_peers_who_came_before(time_input time, N integer, ref refcursor);
CREATE OR REPLACE PROCEDURE get_peers_who_came_before(time_input time, N integer, ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT peer
        FROM timetracking
        WHERE "Time" < time_input
          AND state = 1
        GROUP BY 1
        HAVING COUNT(*) < N;
END;
$$;

-- BEGIN;
-- CALL get_peers_who_came_before('17:13:01', 2, 'procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.16

DROP PROCEDURE IF EXISTS get_peers_who_left(N integer, M integer, ref refcursor);
CREATE OR REPLACE PROCEDURE get_peers_who_left(N integer, M integer, ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        SELECT peer
        FROM timetracking
        WHERE state = 2
          AND "Date" >= CURRENT_DATE - N
        GROUP BY 1
        HAVING COUNT(*) > M;
END;
$$;

-- BEGIN;
-- CALL get_peers_who_left(10, 2, 'procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;

-- part 3.17

DROP PROCEDURE IF EXISTS get_early_entries(ref refcursor);
CREATE OR REPLACE PROCEDURE get_early_entries(ref refcursor)
    LANGUAGE plpgsql
AS
$$
BEGIN
    OPEN ref FOR
        WITH all_entries AS (SELECT EXTRACT(MONTH FROM "Date") AS birthday_month, COUNT(*) AS all_entry_count
                             FROM timetracking
                                      JOIN peers p ON timetracking.peer = p.nickname AND
                                                      EXTRACT(MONTH FROM birthday) = EXTRACT(MONTH FROM "Date")
                             WHERE state = 1
                             GROUP BY 1),
             early_entries AS (SELECT EXTRACT(MONTH FROM "Date") AS birthday_month, COUNT(*) AS early_entry_count
                               FROM timetracking
                                        JOIN peers p ON timetracking.peer = p.nickname AND
                                                        EXTRACT(MONTH FROM birthday) = EXTRACT(MONTH FROM "Date")
                               WHERE state = 1
                                 AND "Time" < '12:00:00'
                               GROUP BY 1)
        SELECT TO_CHAR(TO_DATE(a.birthday_month::varchar, 'MM'), 'Month') AS Month,
               (early_entry_count) * 100 / (all_entry_count)              AS EarlyEntries
        FROM all_entries a
                 JOIN early_entries e ON e.birthday_month = a.birthday_month;
END;
$$;

-- BEGIN;
-- CALL get_early_entries('procedureCursor');
-- FETCH ALL IN "procedureCursor";
-- COMMIT;
