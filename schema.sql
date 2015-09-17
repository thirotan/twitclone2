CREATE TABLE IF NOT EXISTS `users` (
  `id` int NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `username` varchar(255) NOT NULL UNIQUE,
  `password_hash` varchar(255) NOT NULL,
  `salt` varchar(255) NOT NULL,
  `created_at`  DATETIME NOT NULL
) DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `followers` (
  `user_id` int NOT NULL,
  `follower_id` varchar(255) NOT NULL UNIQUE
) DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `followees` (
  `user_id` int NOT NULL,
  `followees_id` varchar(255) NOT NULL UNIQUE
) DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `posts` (
  `id` int NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` int NOT NULL,
  `message` varchar(255) NOT NULL UNIQUE,
  `created_at`  DATETIME NOT NULL
) DEFAULT CHARSET=utf8;
