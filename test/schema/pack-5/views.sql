DROP VIEW IF EXISTS weird_thing;
CREATE VIEW weird_thing AS
SELECT id, name FROM thing WHERE is_weird;

CREATE VIEW reasonable_thing AS
SELECT id, name FROM thing WHERE NOT is_weird;
