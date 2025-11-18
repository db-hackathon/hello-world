--liquibase formatted sql

--changeset baby-names:2
--comment: Load baby names data from CSV

INSERT INTO baby_names (rank, name, count, year) VALUES (1, 'Noah', 4382, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (2, 'Muhammad', 4258, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (3, 'Oliver', 3781, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (4, 'George', 3723, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (5, 'Arthur', 3603, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (6, 'Leo', 3234, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (7, 'Harry', 3125, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (8, 'Oscar', 3082, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (9, 'Archie', 2966, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (10, 'Jack', 2952, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (11, 'Teddy', 2942, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (12, 'Theo', 2932, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (13, 'Freddie', 2785, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (14, 'Henry', 2752, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (15, 'Charlie', 2749, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (16, 'Thomas', 2595, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (17, 'Alfie', 2573, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (18, 'Theodore', 2509, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (19, 'Luca', 2444, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (20, 'Jacob', 2373, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (21, 'William', 2305, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (22, 'Albie', 2246, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (23, 'Arlo', 2146, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (24, 'James', 2141, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (25, 'Finley', 2120, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (26, 'Alexander', 2049, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (27, 'Elijah', 2023, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (28, 'Max', 2007, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (29, 'Albert', 1983, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (30, 'Hudson', 1955, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (31, 'Reggie', 1928, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (32, 'Ezra', 1915, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (33, 'Louie', 1897, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (34, 'Louis', 1869, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (35, 'Isaac', 1862, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (36, 'Sebastian', 1846, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (37, 'Lucas', 1842, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (38, 'Mason', 1816, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (39, 'Edward', 1781, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (40, 'Roman', 1779, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (41, 'Tommy', 1728, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (42, 'Adam', 1713, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (43, 'Rory', 1681, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (44, 'Jude', 1679, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (45, 'Joshua', 1655, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (46, 'Toby', 1648, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (47, 'Oakley', 1646, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (48, 'Ronnie', 1642, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (49, 'Logan', 1641, 2024);
INSERT INTO baby_names (rank, name, count, year) VALUES (50, 'Harrison', 1626, 2024);

--rollback TRUNCATE TABLE baby_names;
