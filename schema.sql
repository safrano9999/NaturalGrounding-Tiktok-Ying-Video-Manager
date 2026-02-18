/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-11.8.5-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: 127.0.0.1    Database: ngdb
-- ------------------------------------------------------
-- Server version	12.2.2-MariaDB-ubu2404

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Table structure for table `accounts`
--

DROP TABLE IF EXISTS `accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `accounts` (
  `account_id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(255) NOT NULL,
  `is_valid` tinyint(1) DEFAULT 1,
  `current_run_finished` tinyint(1) DEFAULT 0,
  `video_count` int(11) DEFAULT 0,
  `unsorted_count` int(11) DEFAULT 0,
  `very_good_unused` int(11) DEFAULT 0,
  `good_unused` int(11) DEFAULT 0,
  `last_used_at` datetime DEFAULT NULL,
  PRIMARY KEY (`account_id`),
  UNIQUE KEY `username` (`username`),
  KEY `username_2` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=482 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_uca1400_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`ngdb`@`%`*/ /*!50003 TRIGGER after_account_blacklist
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
  IF NEW.is_valid = 0 AND OLD.is_valid = 1 THEN
    DELETE FROM presort_queue
    WHERE video_id IN (SELECT id FROM videos WHERE account = NEW.username);

    DELETE FROM playlist_queue
    WHERE video_id IN (SELECT id FROM videos WHERE account = NEW.username);
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `playlist_config`
--

DROP TABLE IF EXISTS `playlist_config`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlist_config` (
  `id` int(11) NOT NULL DEFAULT 1,
  `use_sehr_gut` tinyint(1) DEFAULT 1,
  `use_gut` tinyint(1) DEFAULT 1,
  `use_pending` tinyint(1) DEFAULT 0,
  `use_e3_status` tinyint(1) DEFAULT 0,
  `use_mode1` tinyint(1) DEFAULT NULL,
  `use_mode2` tinyint(1) DEFAULT NULL,
  `time_gt` int(11) DEFAULT NULL,
  `time_lt` int(11) DEFAULT NULL,
  `min_width` int(11) DEFAULT NULL,
  `only_rot` tinyint(1) DEFAULT NULL,
  `max_used` int(11) DEFAULT 0,
  `max_per_acc` int(11) DEFAULT 2,
  `worklist_mode` enum('all','select') DEFAULT 'select',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `playlist_queue`
--

DROP TABLE IF EXISTS `playlist_queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `playlist_queue` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `video_id` int(11) DEFAULT NULL,
  `account_id` int(11) DEFAULT NULL,
  `rel_path` varchar(512) DEFAULT NULL,
  `sort_order` int(11) DEFAULT 0,
  `is_processed` tinyint(1) DEFAULT 0,
  `created_at` timestamp NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `presort_queue`
--

DROP TABLE IF EXISTS `presort_queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `presort_queue` (
  `queue_pos` int(11) NOT NULL AUTO_INCREMENT,
  `video_id` int(11) NOT NULL,
  PRIMARY KEY (`queue_pos`),
  KEY `video_id` (`video_id`)
) ENGINE=InnoDB AUTO_INCREMENT=8192 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `presort_state`
--

DROP TABLE IF EXISTS `presort_state`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `presort_state` (
  `id` int(11) NOT NULL DEFAULT 1,
  `current_pos` int(11) DEFAULT 1,
  PRIMARY KEY (`id`),
  CONSTRAINT `single_row` CHECK (`id` = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary table structure for view `video_stats`
--

DROP TABLE IF EXISTS `video_stats`;
/*!50001 DROP VIEW IF EXISTS `video_stats`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `video_stats` AS SELECT
 1 AS `username`,
  1 AS `is_valid`,
  1 AS `total_videos`,
  1 AS `sehr_gut_count`,
  1 AS `gut_count`,
  1 AS `e3_count`,
  1 AS `pending_count`,
  1 AS `unbrauchbar_count`,
  1 AS `avg_usage`,
  1 AS `last_activity`,
  1 AS `transformed_count` */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `videos`
--

DROP TABLE IF EXISTS `videos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `videos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `init_ytdlp` tinyint(1) DEFAULT 0,
  `id_zeitpunkt_ytdlp` timestamp NULL DEFAULT NULL,
  `video_id` varchar(64) DEFAULT NULL,
  `duration` int(11) DEFAULT 0,
  `width` int(11) DEFAULT 0,
  `height` int(11) DEFAULT 0,
  `view_count` bigint(20) DEFAULT 0,
  `upload_date` date DEFAULT NULL,
  `description` text DEFAULT NULL,
  `rel_path` text DEFAULT NULL,
  `account` varchar(128) DEFAULT NULL,
  `added_at` timestamp NULL DEFAULT current_timestamp(),
  `status` enum('pending','sehr_gut','gut','mute','unbrauchbar','e3') DEFAULT 'pending',
  `mode1` tinyint(1) DEFAULT 0,
  `mode2` tinyint(1) DEFAULT 0,
  `is_transformed` tinyint(1) DEFAULT 0,
  `used_count` int(11) DEFAULT 0,
  `last_used` timestamp NULL DEFAULT NULL,
  `is_valid` tinyint(1) DEFAULT 0,
  `is_physical` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `video_id` (`video_id`),
  KEY `idx_videos_is_valid` (`is_valid`)
) ENGINE=InnoDB AUTO_INCREMENT=29860 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_uca1400_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`ngdb`@`%`*/ /*!50003 TRIGGER trg_videos_count_inc
AFTER INSERT ON videos
FOR EACH ROW
BEGIN
    UPDATE accounts
    SET video_count = video_count + 1,
        unsorted_count = unsorted_count + 1
    WHERE username = NEW.account;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_uca1400_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`ngdb`@`%`*/ /*!50003 TRIGGER trigger_video_finished
AFTER UPDATE ON videos
FOR EACH ROW
BEGIN

    IF OLD.status = 'pending' AND NEW.status != 'pending' THEN


        UPDATE accounts
        SET unsorted_count = unsorted_count - 1
        WHERE username = NEW.account;


        IF NEW.status = 'very_good' THEN
            UPDATE accounts SET very_good_count = very_good_count + 1 WHERE username = NEW.account;
        ELSEIF NEW.status = 'good' THEN
            UPDATE accounts SET good_count = good_count + 1 WHERE username = NEW.account;
        ELSEIF NEW.status = 'discarded' THEN
            UPDATE accounts SET discarded_count = discarded_count + 1 WHERE username = NEW.account;
        END IF;

    END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Final view structure for view `video_stats`
--

/*!50001 DROP VIEW IF EXISTS `video_stats`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_uca1400_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`ngdb`@`%` SQL SECURITY DEFINER */
/*!50001 VIEW `video_stats` AS select `a`.`username` AS `username`,`a`.`is_valid` AS `is_valid`,count(`v`.`id`) AS `total_videos`,sum(case when `v`.`status` = 'sehr_gut' then 1 else 0 end) AS `sehr_gut_count`,sum(case when `v`.`status` = 'gut' then 1 else 0 end) AS `gut_count`,sum(case when `v`.`status` = 'e3' then 1 else 0 end) AS `e3_count`,sum(case when `v`.`status` = 'pending' then 1 else 0 end) AS `pending_count`,sum(case when `v`.`status` = 'unbrauchbar' then 1 else 0 end) AS `unbrauchbar_count`,avg(`v`.`used_count`) AS `avg_usage`,max(`v`.`last_used`) AS `last_activity`,sum(`v`.`is_transformed`) AS `transformed_count` from (`accounts` `a` left join `videos` `v` on(`a`.`username` = `v`.`account`)) group by `a`.`username`,`a`.`is_valid` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2026-02-18  4:08:28
