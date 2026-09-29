-- Classic 1.60: characters can have a surname (up to 48 characters, shown after the name: "Name Surname")
ALTER TABLE `characters` ADD COLUMN `surname` varchar(48) NOT NULL DEFAULT '' AFTER `name`;
