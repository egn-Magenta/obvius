CREATE TABLE `monthly_path_statisics` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `subsite` int(11) DEFAULT NULL,
        `yearmonth` tinyint(4) NOT NULL,
        `uri` varchar(512) DEFAULT NULL,
        `visit_count` int(11) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `uri` (`uri`),
        KEY `yearmonth` (`yearmonth`),
        KEY `subsite` (`subsite`)
) DEFAULT CHARSET=utf8;
