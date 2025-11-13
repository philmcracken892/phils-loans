CREATE TABLE IF NOT EXISTS `player_loans` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `loan_amount` int(11) NOT NULL,
    `remaining_balance` int(11) NOT NULL,
    `weekly_payment` int(11) NOT NULL,
    `interest_rate` float NOT NULL,
    `payments_made` int(11) DEFAULT 0,
    `total_payments` int(11) NOT NULL,
    `next_payment_due` DATETIME NOT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `status` varchar(20) DEFAULT 'active' COMMENT 'active, paid, collections',
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`),
    KEY `status` (`status`),
    KEY `next_payment_due` (`next_payment_due`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
