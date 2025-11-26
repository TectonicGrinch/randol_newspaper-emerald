CREATE TABLE IF NOT EXISTS `paperboy_data` (
  `identifier` VARCHAR(50) PRIMARY KEY,
  `character_name` VARCHAR(100) DEFAULT 'Unknown',
  `level` INT DEFAULT 1,
  `exp` INT DEFAULT 0,
  `total_money` INT DEFAULT 0,
  `routes_completed` INT DEFAULT 0,
  `papers_missed` INT DEFAULT 0,
  `papers_delivered` INT DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;