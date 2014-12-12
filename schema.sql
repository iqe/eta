CREATE TABLE `variables` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255),
  `unit` VARCHAR(10),
  `uri` VARCHAR(255),
  `interval` INT,
  PRIMARY KEY  (`id`)
);

CREATE TABLE `values` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `variable_id` INT,
  `str_value` VARCHAR(20),
  `dec_value` FLOAT,
  `created_at` TIMESTAMP,
  PRIMARY KEY  (`id`)
);


ALTER TABLE `values` ADD CONSTRAINT `values_variable_id` FOREIGN KEY (`variable_id`) REFERENCES variables(`id`);

