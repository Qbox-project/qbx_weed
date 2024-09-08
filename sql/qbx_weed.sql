CREATE TABLE IF NOT EXISTS `weed_plants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `property` varchar(30) NULL,
  `stage` tinyint NOT NULL DEFAULT 1,
  `sort` varchar(30) NOT NULL,
  `gender` enum('male', 'female') NOT NULL,
  `food` tinyint NOT NULL DEFAULT 100,
  `health` tinyint NOT NULL DEFAULT 100,
  `stageProgress` tinyint NOT NULL DEFAULT 0,
  `coords` tinytext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;
