CREATE TABLE IF NOT EXISTS `house_plants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `building` varchar(30) NOT NULL,
  `stage` varchar(11) NOT NULL DEFAULT 'stage1',
  `sort` varchar(30) NOT NULL,
  `gender` enum('male', 'female') NOT NULL,
  `food` tinyint NOT NULL DEFAULT 100,
  `health` tinyint NOT NULL DEFAULT 100,
  `progress` tinyint NOT NULL DEFAULT 0,
  `coords` tinytext NOT NULL,
  PRIMARY KEY (`id`),
  KEY `building` (`building`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4;