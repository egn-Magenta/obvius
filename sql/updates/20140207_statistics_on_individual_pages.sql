CREATE TABLE monthly_path_statisics (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        subsite INT NULL,
        month TINYINT NOT NULL,
        uri VARCHAR(255),
        visit_count int
);
