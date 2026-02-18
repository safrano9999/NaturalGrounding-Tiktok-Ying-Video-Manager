source ./config/db_config.env
mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -e "
TRUNCATE TABLE playlist_queue;
TRUNCATE TABLE presort_queue;
UPDATE presort_state SET current_pos = 1 WHERE id = 1;
DELETE FROM videos;
DELETE FROM accounts;
SELECT 'CLEANUP COMPLETE' as status;"

# Then check counts:
mariadb -h "$DB_HOST" -u "$DB_USER" -p"$DB_PW" "$DB_NAME" -e "
SELECT COUNT(*) FROM presort_queue;
SELECT COUNT(*) FROM playlist_queue;
SELECT COUNT(*) FROM videos;
SELECT COUNT(*) FROM accounts;"
