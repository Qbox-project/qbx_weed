ALTER TABLE `house_plants` RENAME TO `weed_plants`;

DROP INDEX `building` ON `weed_plants`;

ALTER TABLE `weed_plants` CHANGE COLUMN `building` `property` varchar(30) NULL;
ALTER TABLE `weed_plants` CHANGE COLUMN `stage` `stage` tinyint NOT NULL DEFAULT 1;
ALTER TABLE `weed_plants` CHANGE COLUMN `progress` `stageProgress` tinyint NOT NULL DEFAULT 0;
