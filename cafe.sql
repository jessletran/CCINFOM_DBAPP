DROP DATABASE IF EXISTS pc_gaming_cafe;
CREATE DATABASE pc_gaming_cafe;
USE pc_gaming_cafe;

CREATE TABLE customer (
    customer_id           INT AUTO_INCREMENT PRIMARY KEY,
    username              VARCHAR(30)  NOT NULL UNIQUE,
    last_name             VARCHAR(50)  NOT NULL,
    first_name            VARCHAR(50)  NOT NULL,
    email                 VARCHAR(100) NOT NULL UNIQUE,
    contact_number        VARCHAR(20)  NOT NULL,
    membership_start_date DATE         NOT NULL,
    active                TINYINT      NOT NULL DEFAULT 1
);

CREATE TABLE pc_station (
    station_id INT AUTO_INCREMENT PRIMARY KEY,
    pc_tier    ENUM('Entry', 'VIP', 'Esports') NOT NULL,
    status     ENUM('Available', 'In Use', 'Under Maintenance', 'Retired') NOT NULL DEFAULT 'Available'
);

CREATE TABLE gaming_session (
    session_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT           NOT NULL,
    station_id     INT           NOT NULL,
    start_time     DATETIME      NOT NULL,
    end_time       DATETIME      NULL,
    hours_played   INT           NULL,
    hourly_rate    DECIMAL(8,2)  NOT NULL,
    session_fee    DECIMAL(10,2) NULL,
    payment_status ENUM('Unpaid', 'Paid') NOT NULL DEFAULT 'Unpaid',
    FOREIGN KEY (customer_id) REFERENCES customer (customer_id),
    FOREIGN KEY (station_id)  REFERENCES pc_station (station_id)
);

CREATE TABLE menu_item (
    item_id           INT AUTO_INCREMENT PRIMARY KEY,
    item_name         VARCHAR(60)  NOT NULL,
    category          ENUM('Drinks', 'Snacks', 'Meals') NOT NULL,
    unit_price        DECIMAL(8,2) NOT NULL,
    quantity_in_stock INT          NOT NULL DEFAULT 0,
    discontinued      TINYINT      NOT NULL DEFAULT 0
);

CREATE TABLE item_order (
    order_id   INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT          NOT NULL,
    item_id    INT          NOT NULL,
    quantity   INT          NOT NULL,
    unit_price DECIMAL(8,2) NOT NULL,
    order_time DATETIME     NOT NULL,
    FOREIGN KEY (session_id) REFERENCES gaming_session (session_id),
    FOREIGN KEY (item_id)    REFERENCES menu_item (item_id)
);

DELIMITER //

CREATE PROCEDURE sp_add_customer (
    IN p_username VARCHAR(30),
    IN p_last_name VARCHAR(50),
    IN p_first_name VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_contact_number VARCHAR(20),
    IN p_membership_start_date DATE
)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    SELECT COUNT(*) INTO v_count
    FROM customer
    WHERE username = p_username OR email = p_email;

    IF v_count > 0 THEN
        SELECT 'Username or email already exists.' AS result;
    ELSE
        INSERT INTO customer (username, last_name, first_name, email, contact_number, membership_start_date, active)
        VALUES (p_username, p_last_name, p_first_name, p_email, p_contact_number, p_membership_start_date, 1);
        SELECT 'Customer added.' AS result, LAST_INSERT_ID() AS customer_id;
    END IF;
END //

CREATE PROCEDURE sp_update_customer (
    IN p_customer_id INT,
    IN p_username VARCHAR(30),
    IN p_last_name VARCHAR(50),
    IN p_first_name VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_contact_number VARCHAR(20),
    IN p_membership_start_date DATE,
    IN p_active TINYINT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_duplicate INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists FROM customer WHERE customer_id = p_customer_id;
    SELECT COUNT(*) INTO v_duplicate
    FROM customer
    WHERE (username = p_username OR email = p_email) AND customer_id <> p_customer_id;

    IF v_exists = 0 THEN
        SELECT 'Customer not found.' AS result;
    ELSEIF v_duplicate > 0 THEN
        SELECT 'Username or email already exists.' AS result;
    ELSE
        UPDATE customer
        SET username = p_username,
            last_name = p_last_name,
            first_name = p_first_name,
            email = p_email,
            contact_number = p_contact_number,
            membership_start_date = p_membership_start_date,
            active = p_active
        WHERE customer_id = p_customer_id;
        SELECT 'Customer updated.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_delete_customer (IN p_customer_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_sessions INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists FROM customer WHERE customer_id = p_customer_id;
    SELECT COUNT(*) INTO v_sessions FROM gaming_session WHERE customer_id = p_customer_id;

    IF v_exists = 0 THEN
        SELECT 'Customer not found.' AS result;
    ELSEIF v_sessions = 0 THEN
        DELETE FROM customer WHERE customer_id = p_customer_id;
        SELECT 'Customer deleted.' AS result;
    ELSE
        UPDATE customer SET active = 0 WHERE customer_id = p_customer_id;
        SELECT 'Customer has sessions. Set to inactive instead.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_view_customer (IN p_customer_id INT)
BEGIN
    SELECT * FROM customer WHERE customer_id = p_customer_id;

    SELECT * FROM gaming_session WHERE customer_id = p_customer_id;

    SELECT io.order_id, io.session_id, mi.item_name, io.quantity, io.unit_price,
           io.quantity * io.unit_price AS line_total, io.order_time
    FROM item_order io
    JOIN gaming_session gs ON gs.session_id = io.session_id
    JOIN menu_item mi ON mi.item_id = io.item_id
    WHERE gs.customer_id = p_customer_id;
END //

CREATE PROCEDURE sp_list_customers ()
BEGIN
    SELECT * FROM customer;
END //

CREATE PROCEDURE sp_list_customers_by_active (IN p_active TINYINT)
BEGIN
    SELECT * FROM customer WHERE active = p_active;
END //

CREATE PROCEDURE sp_list_customers_by_membership (IN p_month INT, IN p_year INT)
BEGIN
    SELECT * FROM customer
    WHERE MONTH(membership_start_date) = p_month
      AND YEAR(membership_start_date) = p_year;
END //

CREATE PROCEDURE sp_list_customers_by_session_date (IN p_date DATE)
BEGIN
    SELECT DISTINCT c.*
    FROM customer c
    JOIN gaming_session gs ON gs.customer_id = c.customer_id
    WHERE DATE(gs.start_time) = p_date;
END //


CREATE PROCEDURE sp_add_station (IN p_pc_tier VARCHAR(10))
BEGIN
    IF p_pc_tier IN ('Entry', 'VIP', 'Esports') THEN
        INSERT INTO pc_station (pc_tier, status) VALUES (p_pc_tier, 'Available');
        SELECT 'Station added.' AS result, LAST_INSERT_ID() AS station_id;
    ELSE
        SELECT 'Invalid PC tier.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_update_station (
    IN p_station_id INT,
    IN p_pc_tier VARCHAR(10),
    IN p_status VARCHAR(20)
)
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;

    START TRANSACTION;

    SELECT status INTO v_status
    FROM pc_station
    WHERE station_id = p_station_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SELECT 'Station not found.' AS result;
    ELSEIF v_status = 'In Use' THEN
        ROLLBACK;
        SELECT 'Station is In Use and cannot be edited.' AS result;
    ELSEIF p_status NOT IN ('Available', 'Under Maintenance', 'Retired') THEN
        ROLLBACK;
        SELECT 'Status must be Available, Under Maintenance, or Retired.' AS result;
    ELSEIF p_pc_tier NOT IN ('Entry', 'VIP', 'Esports') THEN
        ROLLBACK;
        SELECT 'Invalid PC tier.' AS result;
    ELSE
        UPDATE pc_station
        SET pc_tier = p_pc_tier, status = p_status
        WHERE station_id = p_station_id;
        COMMIT;
        SELECT 'Station updated.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_delete_station (IN p_station_id INT)
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_sessions INT DEFAULT 0;

    START TRANSACTION;

    SELECT status INTO v_status
    FROM pc_station
    WHERE station_id = p_station_id
    FOR UPDATE;

    SELECT COUNT(*) INTO v_sessions FROM gaming_session WHERE station_id = p_station_id;

    IF v_status IS NULL THEN
        ROLLBACK;
        SELECT 'Station not found.' AS result;
    ELSEIF v_status = 'In Use' THEN
        ROLLBACK;
        SELECT 'Station is In Use and cannot be edited.' AS result;
    ELSEIF v_sessions = 0 THEN
        DELETE FROM pc_station WHERE station_id = p_station_id;
        COMMIT;
        SELECT 'Station deleted.' AS result;
    ELSE
        UPDATE pc_station SET status = 'Retired' WHERE station_id = p_station_id;
        COMMIT;
        SELECT 'Station has sessions. Set to Retired instead.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_view_station (IN p_station_id INT)
BEGIN
    SELECT * FROM pc_station WHERE station_id = p_station_id;

    SELECT gs.session_id, gs.customer_id, c.last_name, c.first_name,
           gs.start_time, gs.end_time, gs.hours_played, gs.hourly_rate,
           gs.session_fee, gs.payment_status
    FROM gaming_session gs
    JOIN customer c ON c.customer_id = gs.customer_id
    WHERE gs.station_id = p_station_id;
END //

CREATE PROCEDURE sp_list_stations ()
BEGIN
    SELECT * FROM pc_station;
END //

CREATE PROCEDURE sp_list_stations_by_tier (IN p_pc_tier VARCHAR(10))
BEGIN
    SELECT * FROM pc_station WHERE pc_tier = p_pc_tier;
END //

CREATE PROCEDURE sp_list_stations_by_status (IN p_status VARCHAR(20))
BEGIN
    SELECT * FROM pc_station WHERE status = p_status;
END //


CREATE PROCEDURE sp_check_in (IN p_customer_id INT, IN p_station_id INT)
BEGIN
    DECLARE v_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_tier VARCHAR(10) DEFAULT NULL;
    DECLARE v_active TINYINT DEFAULT NULL;
    DECLARE v_rate DECIMAL(8,2) DEFAULT 0;
    DECLARE v_session_id INT DEFAULT NULL;

    START TRANSACTION;

    SELECT status, pc_tier INTO v_status, v_tier
    FROM pc_station
    WHERE station_id = p_station_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        ROLLBACK;
        SELECT 'Station not found.' AS result;
    ELSEIF v_status <> 'Available' THEN
        ROLLBACK;
        SELECT 'Station not available.' AS result;
    ELSE
        SELECT active INTO v_active
        FROM customer
        WHERE customer_id = p_customer_id;

        IF v_active IS NULL THEN
            ROLLBACK;
            SELECT 'Customer not found.' AS result;
        ELSEIF v_active = 0 THEN
            ROLLBACK;
            SELECT 'Customer is inactive.' AS result;
        ELSE
            IF v_tier = 'Entry' THEN
                SET v_rate = 40;
            ELSEIF v_tier = 'VIP' THEN
                SET v_rate = 60;
            ELSE
                SET v_rate = 80;
            END IF;

            INSERT INTO gaming_session (customer_id, station_id, start_time, hourly_rate, payment_status)
            VALUES (p_customer_id, p_station_id, NOW(), v_rate, 'Unpaid');
            SET v_session_id = LAST_INSERT_ID();

            UPDATE pc_station
            SET status = 'In Use'
            WHERE station_id = p_station_id AND status = 'Available';

            IF ROW_COUNT() = 0 THEN
                ROLLBACK;
                SELECT 'Station not available.' AS result;
            ELSE
                COMMIT;
                SELECT 'Check-in successful.' AS result, v_session_id AS session_id;
            END IF;
        END IF;
    END IF;
END //

CREATE PROCEDURE sp_check_out (IN p_session_id INT)
BEGIN
    DECLARE v_station_id INT DEFAULT NULL;
    DECLARE v_start_time DATETIME DEFAULT NULL;
    DECLARE v_end_time DATETIME DEFAULT NULL;
    DECLARE v_rate DECIMAL(8,2) DEFAULT 0;
    DECLARE v_hours INT DEFAULT 0;
    DECLARE v_fee DECIMAL(10,2) DEFAULT 0;

    START TRANSACTION;

    SELECT station_id, start_time, end_time, hourly_rate
    INTO v_station_id, v_start_time, v_end_time, v_rate
    FROM gaming_session
    WHERE session_id = p_session_id
    FOR UPDATE;

    IF v_station_id IS NULL THEN
        ROLLBACK;
        SELECT 'Session not found.' AS result;
    ELSEIF v_end_time IS NOT NULL THEN
        ROLLBACK;
        SELECT 'Session already checked out.' AS result;
    ELSE
        SET v_end_time = NOW();
        SET v_hours = CEIL(TIMESTAMPDIFF(SECOND, v_start_time, v_end_time) / 3600);
        IF v_hours < 1 THEN
            SET v_hours = 1;
        END IF;
        SET v_fee = v_hours * v_rate;

        UPDATE gaming_session
        SET end_time = v_end_time,
            hours_played = v_hours,
            session_fee = v_fee,
            payment_status = 'Paid'
        WHERE session_id = p_session_id;

        UPDATE pc_station SET status = 'Available' WHERE station_id = v_station_id;

        COMMIT;
        SELECT 'Check-out successful.' AS result, v_hours AS hours_played, v_fee AS session_fee;
    END IF;
END //

CREATE PROCEDURE sp_update_payment_status (IN p_session_id INT, IN p_payment_status VARCHAR(10))
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_open INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists FROM gaming_session WHERE session_id = p_session_id;
    SELECT COUNT(*) INTO v_open FROM gaming_session WHERE session_id = p_session_id AND end_time IS NULL;

    IF v_exists = 0 THEN
        SELECT 'Session not found.' AS result;
    ELSEIF v_open = 1 THEN
        SELECT 'Session is still open. Use check-out.' AS result;
    ELSEIF p_payment_status NOT IN ('Unpaid', 'Paid') THEN
        SELECT 'Payment status must be Unpaid or Paid.' AS result;
    ELSE
        UPDATE gaming_session SET payment_status = p_payment_status WHERE session_id = p_session_id;
        SELECT 'Payment status updated.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_delete_session (IN p_session_id INT)
BEGIN
    DECLARE v_station_id INT DEFAULT NULL;
    DECLARE v_end_time DATETIME DEFAULT NULL;
    DECLARE v_payment VARCHAR(10) DEFAULT NULL;
    DECLARE v_orders INT DEFAULT 0;

    START TRANSACTION;

    SELECT station_id, end_time, payment_status
    INTO v_station_id, v_end_time, v_payment
    FROM gaming_session
    WHERE session_id = p_session_id
    FOR UPDATE;

    SELECT COUNT(*) INTO v_orders FROM item_order WHERE session_id = p_session_id;

    IF v_station_id IS NULL THEN
        ROLLBACK;
        SELECT 'Session not found.' AS result;
    ELSEIF v_payment = 'Paid' THEN
        ROLLBACK;
        SELECT 'Paid sessions cannot be deleted.' AS result;
    ELSEIF v_end_time IS NOT NULL THEN
        ROLLBACK;
        SELECT 'Only a mistaken open session can be deleted.' AS result;
    ELSEIF v_orders > 0 THEN
        ROLLBACK;
        SELECT 'Session has orders and cannot be deleted.' AS result;
    ELSE
        DELETE FROM gaming_session WHERE session_id = p_session_id;
        UPDATE pc_station SET status = 'Available' WHERE station_id = v_station_id;
        COMMIT;
        SELECT 'Session deleted.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_view_session (IN p_session_id INT)
BEGIN
    SELECT gs.session_id, gs.customer_id, c.last_name, c.first_name,
           gs.station_id, ps.pc_tier, ps.status AS station_status,
           gs.start_time, gs.end_time, gs.hours_played, gs.hourly_rate,
           gs.session_fee, gs.payment_status
    FROM gaming_session gs
    JOIN customer c ON c.customer_id = gs.customer_id
    JOIN pc_station ps ON ps.station_id = gs.station_id
    WHERE gs.session_id = p_session_id;

    SELECT io.order_id, mi.item_name, mi.category, io.quantity, io.unit_price,
           io.quantity * io.unit_price AS line_total, io.order_time
    FROM item_order io
    JOIN menu_item mi ON mi.item_id = io.item_id
    WHERE io.session_id = p_session_id;
END //

CREATE PROCEDURE sp_list_sessions ()
BEGIN
    SELECT * FROM gaming_session;
END //

CREATE PROCEDURE sp_list_sessions_by_date (IN p_date DATE)
BEGIN
    SELECT * FROM gaming_session WHERE DATE(start_time) = p_date;
END //

CREATE PROCEDURE sp_list_sessions_by_tier (IN p_pc_tier VARCHAR(10))
BEGIN
    SELECT gs.*
    FROM gaming_session gs
    JOIN pc_station ps ON ps.station_id = gs.station_id
    WHERE ps.pc_tier = p_pc_tier;
END //

CREATE PROCEDURE sp_list_sessions_by_payment (IN p_payment_status VARCHAR(10))
BEGIN
    SELECT * FROM gaming_session WHERE payment_status = p_payment_status;
END //

CREATE PROCEDURE sp_list_sessions_by_customer (IN p_customer_id INT)
BEGIN
    SELECT * FROM gaming_session WHERE customer_id = p_customer_id;
END //


CREATE PROCEDURE sp_add_menu_item (
    IN p_item_name VARCHAR(60),
    IN p_category VARCHAR(10),
    IN p_unit_price DECIMAL(8,2),
    IN p_quantity_in_stock INT
)
BEGIN
    IF p_category NOT IN ('Drinks', 'Snacks', 'Meals') THEN
        SELECT 'Invalid category.' AS result;
    ELSEIF p_unit_price < 0 OR p_quantity_in_stock < 0 THEN
        SELECT 'Price and stock cannot be negative.' AS result;
    ELSE
        INSERT INTO menu_item (item_name, category, unit_price, quantity_in_stock, discontinued)
        VALUES (p_item_name, p_category, p_unit_price, p_quantity_in_stock, 0);
        SELECT 'Menu item added.' AS result, LAST_INSERT_ID() AS item_id;
    END IF;
END //

CREATE PROCEDURE sp_update_menu_item (
    IN p_item_id INT,
    IN p_item_name VARCHAR(60),
    IN p_category VARCHAR(10),
    IN p_unit_price DECIMAL(8,2),
    IN p_quantity_in_stock INT,
    IN p_discontinued TINYINT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists FROM menu_item WHERE item_id = p_item_id;

    IF v_exists = 0 THEN
        SELECT 'Menu item not found.' AS result;
    ELSEIF p_category NOT IN ('Drinks', 'Snacks', 'Meals') THEN
        SELECT 'Invalid category.' AS result;
    ELSEIF p_unit_price < 0 OR p_quantity_in_stock < 0 THEN
        SELECT 'Price and stock cannot be negative.' AS result;
    ELSE
        UPDATE menu_item
        SET item_name = p_item_name,
            category = p_category,
            unit_price = p_unit_price,
            quantity_in_stock = p_quantity_in_stock,
            discontinued = p_discontinued
        WHERE item_id = p_item_id;
        SELECT 'Menu item updated.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_delete_menu_item (IN p_item_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_orders INT DEFAULT 0;

    SELECT COUNT(*) INTO v_exists FROM menu_item WHERE item_id = p_item_id;
    SELECT COUNT(*) INTO v_orders FROM item_order WHERE item_id = p_item_id;

    IF v_exists = 0 THEN
        SELECT 'Menu item not found.' AS result;
    ELSEIF v_orders = 0 THEN
        DELETE FROM menu_item WHERE item_id = p_item_id;
        SELECT 'Menu item deleted.' AS result;
    ELSE
        UPDATE menu_item SET discontinued = 1 WHERE item_id = p_item_id;
        SELECT 'Item was ordered before. Marked as discontinued instead.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_view_menu_item (IN p_item_id INT)
BEGIN
    SELECT * FROM menu_item WHERE item_id = p_item_id;

    SELECT order_id, session_id, quantity, unit_price,
           quantity * unit_price AS line_total, order_time
    FROM item_order
    WHERE item_id = p_item_id;
END //

CREATE PROCEDURE sp_list_menu_items ()
BEGIN
    SELECT * FROM menu_item;
END //

CREATE PROCEDURE sp_list_menu_items_by_category (IN p_category VARCHAR(10))
BEGIN
    SELECT * FROM menu_item WHERE category = p_category;
END //

CREATE PROCEDURE sp_list_discontinued_menu_items ()
BEGIN
    SELECT * FROM menu_item WHERE discontinued = 1;
END //

CREATE PROCEDURE sp_list_menu_items_low_stock (IN p_quantity INT)
BEGIN
    SELECT * FROM menu_item WHERE quantity_in_stock < p_quantity;
END //


CREATE PROCEDURE sp_add_order (IN p_session_id INT, IN p_item_id INT, IN p_quantity INT)
BEGIN
    DECLARE v_open INT DEFAULT 0;
    DECLARE v_price DECIMAL(8,2) DEFAULT NULL;
    DECLARE v_stock INT DEFAULT 0;
    DECLARE v_discontinued TINYINT DEFAULT 0;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_open
    FROM gaming_session
    WHERE session_id = p_session_id AND end_time IS NULL;

    SELECT unit_price, quantity_in_stock, discontinued
    INTO v_price, v_stock, v_discontinued
    FROM menu_item
    WHERE item_id = p_item_id
    FOR UPDATE;

    IF p_quantity <= 0 THEN
        ROLLBACK;
        SELECT 'Quantity must be greater than zero.' AS result;
    ELSEIF v_open = 0 THEN
        ROLLBACK;
        SELECT 'Session not found or not open.' AS result;
    ELSEIF v_price IS NULL THEN
        ROLLBACK;
        SELECT 'Menu item not found.' AS result;
    ELSEIF v_discontinued = 1 THEN
        ROLLBACK;
        SELECT 'Item is discontinued.' AS result;
    ELSEIF v_stock < p_quantity THEN
        ROLLBACK;
        SELECT 'Not enough stock.' AS result;
    ELSE
        INSERT INTO item_order (session_id, item_id, quantity, unit_price, order_time)
        VALUES (p_session_id, p_item_id, p_quantity, v_price, NOW());

        UPDATE menu_item
        SET quantity_in_stock = quantity_in_stock - p_quantity
        WHERE item_id = p_item_id;

        COMMIT;
        SELECT 'Order added.' AS result, LAST_INSERT_ID() AS order_id;
    END IF;
END //

CREATE PROCEDURE sp_update_order_quantity (IN p_order_id INT, IN p_new_quantity INT)
BEGIN
    DECLARE v_item_id INT DEFAULT NULL;
    DECLARE v_old_quantity INT DEFAULT 0;
    DECLARE v_stock INT DEFAULT 0;
    DECLARE v_discontinued TINYINT DEFAULT 0;
    DECLARE v_difference INT DEFAULT 0;

    START TRANSACTION;

    SELECT item_id, quantity INTO v_item_id, v_old_quantity
    FROM item_order
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF p_new_quantity <= 0 THEN
        ROLLBACK;
        SELECT 'Quantity must be greater than zero.' AS result;
    ELSEIF v_item_id IS NULL THEN
        ROLLBACK;
        SELECT 'Order not found.' AS result;
    ELSE
        SELECT quantity_in_stock, discontinued INTO v_stock, v_discontinued
        FROM menu_item
        WHERE item_id = v_item_id
        FOR UPDATE;

        SET v_difference = p_new_quantity - v_old_quantity;

        IF v_difference > 0 AND v_discontinued = 1 THEN
            ROLLBACK;
            SELECT 'Item is discontinued.' AS result;
        ELSEIF v_difference > v_stock THEN
            ROLLBACK;
            SELECT 'Not enough stock.' AS result;
        ELSE
            UPDATE item_order SET quantity = p_new_quantity WHERE order_id = p_order_id;
            UPDATE menu_item
            SET quantity_in_stock = quantity_in_stock - v_difference
            WHERE item_id = v_item_id;
            COMMIT;
            SELECT 'Order updated.' AS result;
        END IF;
    END IF;
END //

CREATE PROCEDURE sp_delete_order (IN p_order_id INT)
BEGIN
    DECLARE v_item_id INT DEFAULT NULL;
    DECLARE v_quantity INT DEFAULT 0;

    START TRANSACTION;

    SELECT item_id, quantity INTO v_item_id, v_quantity
    FROM item_order
    WHERE order_id = p_order_id
    FOR UPDATE;

    IF v_item_id IS NULL THEN
        ROLLBACK;
        SELECT 'Order not found.' AS result;
    ELSE
        UPDATE menu_item
        SET quantity_in_stock = quantity_in_stock + v_quantity
        WHERE item_id = v_item_id;

        DELETE FROM item_order WHERE order_id = p_order_id;

        COMMIT;
        SELECT 'Order cancelled. Quantity returned to stock.' AS result;
    END IF;
END //

CREATE PROCEDURE sp_view_order (IN p_order_id INT)
BEGIN
    SELECT io.order_id, io.quantity, io.unit_price, io.order_time,
           io.quantity * io.unit_price AS line_total,
           gs.session_id, gs.customer_id, c.last_name, c.first_name,
           gs.station_id, ps.pc_tier, gs.start_time, gs.end_time, gs.payment_status,
           mi.item_id, mi.item_name, mi.category,
           mi.unit_price AS current_unit_price, mi.quantity_in_stock, mi.discontinued
    FROM item_order io
    JOIN gaming_session gs ON gs.session_id = io.session_id
    JOIN customer c ON c.customer_id = gs.customer_id
    JOIN pc_station ps ON ps.station_id = gs.station_id
    JOIN menu_item mi ON mi.item_id = io.item_id
    WHERE io.order_id = p_order_id;
END //

CREATE PROCEDURE sp_list_orders ()
BEGIN
    SELECT * FROM item_order;
END //

CREATE PROCEDURE sp_list_orders_by_session (IN p_session_id INT)
BEGIN
    SELECT * FROM item_order WHERE session_id = p_session_id;
END //

CREATE PROCEDURE sp_list_orders_by_item (IN p_item_id INT)
BEGIN
    SELECT * FROM item_order WHERE item_id = p_item_id;
END //

CREATE PROCEDURE sp_list_orders_by_date (IN p_date DATE)
BEGIN
    SELECT * FROM item_order WHERE DATE(order_time) = p_date;
END //


CREATE PROCEDURE sp_monthly_revenue_report (IN p_year INT, IN p_month INT)
BEGIN
    DECLARE v_session_total DECIMAL(12,2) DEFAULT 0;
    DECLARE v_food_total DECIMAL(12,2) DEFAULT 0;

    SELECT ps.pc_tier,
           COUNT(gs.session_id) AS number_of_sessions,
           IFNULL(SUM(gs.hours_played), 0) AS total_hours_played,
           IFNULL(SUM(gs.session_fee), 0) AS session_revenue
    FROM pc_station ps
    LEFT JOIN gaming_session gs
           ON gs.station_id = ps.station_id
          AND gs.payment_status = 'Paid'
          AND YEAR(gs.start_time) = p_year
          AND MONTH(gs.start_time) = p_month
    GROUP BY ps.pc_tier
    ORDER BY ps.pc_tier;

    SELECT mi.category,
           IFNULL(SUM(io.quantity), 0) AS units_sold,
           IFNULL(SUM(io.quantity * io.unit_price), 0) AS food_drink_sales
    FROM menu_item mi
    LEFT JOIN item_order io
           ON io.item_id = mi.item_id
          AND YEAR(io.order_time) = p_year
          AND MONTH(io.order_time) = p_month
    GROUP BY mi.category
    ORDER BY mi.category;

    SELECT IFNULL(SUM(session_fee), 0) INTO v_session_total
    FROM gaming_session
    WHERE payment_status = 'Paid'
      AND YEAR(start_time) = p_year
      AND MONTH(start_time) = p_month;

    SELECT IFNULL(SUM(quantity * unit_price), 0) INTO v_food_total
    FROM item_order
    WHERE YEAR(order_time) = p_year
      AND MONTH(order_time) = p_month;

    SELECT v_session_total AS session_revenue,
           v_food_total AS food_drink_sales,
           v_session_total + v_food_total AS grand_total;
END //

CREATE PROCEDURE sp_pc_usage_report (IN p_year INT, IN p_month INT)
BEGIN
    SELECT ps.station_id,
           ps.pc_tier,
           COUNT(gs.session_id) AS number_of_sessions,
           IFNULL(SUM(gs.hours_played), 0) AS total_hours_used,
           IFNULL(ROUND(AVG(gs.hours_played), 2), 0) AS average_hours_per_session,
           IFNULL(SUM(gs.session_fee), 0) AS session_revenue,
           IF(COUNT(gs.session_id) = 0, 'NO SESSIONS', '') AS flag
    FROM pc_station ps
    LEFT JOIN gaming_session gs
           ON gs.station_id = ps.station_id
          AND gs.end_time IS NOT NULL
          AND YEAR(gs.start_time) = p_year
          AND MONTH(gs.start_time) = p_month
    GROUP BY ps.station_id, ps.pc_tier
    ORDER BY total_hours_used DESC, number_of_sessions DESC, ps.station_id;

    SELECT ps.pc_tier,
           COUNT(DISTINCT ps.station_id) AS number_of_stations,
           COUNT(gs.session_id) AS number_of_sessions,
           IFNULL(SUM(gs.hours_played), 0) AS total_hours_used,
           IFNULL(ROUND(AVG(gs.hours_played), 2), 0) AS average_hours_per_session,
           IFNULL(SUM(gs.session_fee), 0) AS session_revenue
    FROM pc_station ps
    LEFT JOIN gaming_session gs
           ON gs.station_id = ps.station_id
          AND gs.end_time IS NOT NULL
          AND YEAR(gs.start_time) = p_year
          AND MONTH(gs.start_time) = p_month
    GROUP BY ps.pc_tier
    ORDER BY total_hours_used DESC, ps.pc_tier;
END //

DELIMITER ;


INSERT INTO customer (customer_id, username, last_name, first_name, email, contact_number, membership_start_date, active) VALUES
(1,  'jdelacruz',   'Dela Cruz',  'Juan',    'juan.delacruz@email.com',     '0917-111-0001', '2026-01-15', 1),
(2,  'msantos',     'Santos',     'Maria',   'maria.santos@email.com',      '0917-111-0002', '2026-02-03', 1),
(3,  'preyes',      'Reyes',      'Paolo',   'paolo.reyes@email.com',       '0917-111-0003', '2026-02-20', 1),
(4,  'aramos',      'Ramos',      'Angela',  'angela.ramos@email.com',      '0917-111-0004', '2026-03-11', 1),
(5,  'kgarcia',     'Garcia',     'Kyle',    'kyle.garcia@email.com',       '0917-111-0005', '2026-03-28', 1),
(6,  'mbautista',   'Bautista',   'Miguel',  'miguel.bautista@email.com',   '0917-111-0006', '2026-05-09', 1),
(7,  'cmendoza',    'Mendoza',    'Carla',   'carla.mendoza@email.com',     '0917-111-0007', '2026-06-14', 1),
(8,  'rtorres',     'Torres',     'Rafael',  'rafael.torres@email.com',     '0917-111-0008', '2026-07-01', 1),
(9,  'ivillanueva', 'Villanueva', 'Isabel',  'isabel.villanueva@email.com', '0917-111-0009', '2026-07-19', 0),
(10, 'dnavarro',    'Navarro',    'Daniel',  'daniel.navarro@email.com',    '0917-111-0010', '2026-08-05', 1),
(11, 'lcastillo',   'Castillo',   'Lea',     'lea.castillo@email.com',      '0917-111-0011', '2026-09-10', 1),
(12, 'gaquino',     'Aquino',     'Gabriel', 'gabriel.aquino@email.com',    '0917-111-0012', '2026-10-02', 1);

INSERT INTO pc_station (station_id, pc_tier, status) VALUES
(1,  'Entry',   'Available'),
(2,  'Entry',   'Available'),
(3,  'Entry',   'In Use'),
(4,  'Entry',   'Under Maintenance'),
(5,  'VIP',     'Available'),
(6,  'VIP',     'In Use'),
(7,  'VIP',     'Available'),
(8,  'VIP',     'Available'),
(9,  'Esports', 'Available'),
(10, 'Esports', 'Available'),
(11, 'Esports', 'Available'),
(12, 'Esports', 'Retired');

INSERT INTO gaming_session (session_id, customer_id, station_id, start_time, end_time, hours_played, hourly_rate, session_fee, payment_status) VALUES
(1,  1,  1,  '2026-09-05 14:00:00', '2026-09-05 16:10:00', 3, 40.00, 120.00, 'Paid'),
(2,  2,  5,  '2026-09-06 18:00:00', '2026-09-06 19:30:00', 2, 60.00, 120.00, 'Paid'),
(3,  3,  9,  '2026-09-12 19:00:00', '2026-09-12 22:00:00', 3, 80.00, 240.00, 'Paid'),
(4,  4,  2,  '2026-09-20 10:15:00', '2026-09-20 11:00:00', 1, 40.00,  40.00, 'Paid'),
(5,  5,  6,  '2026-09-27 20:00:00', '2026-09-27 23:45:00', 4, 60.00, 240.00, 'Paid'),
(6,  1,  10, '2026-10-01 13:00:00', '2026-10-01 15:00:00', 2, 80.00, 160.00, 'Paid'),
(7,  2,  1,  '2026-10-03 16:00:00', '2026-10-03 17:20:00', 2, 40.00,  80.00, 'Paid'),
(8,  6,  7,  '2026-10-04 21:00:00', '2026-10-05 00:30:00', 4, 60.00, 240.00, 'Paid'),
(9,  7,  9,  '2026-10-08 18:30:00', '2026-10-08 20:00:00', 2, 80.00, 160.00, 'Paid'),
(10, 3,  5,  '2026-10-10 15:00:00', '2026-10-10 18:00:00', 3, 60.00, 180.00, 'Paid'),
(11, 8,  2,  '2026-10-11 12:00:00', '2026-10-11 12:45:00', 1, 40.00,  40.00, 'Paid'),
(12, 9,  8,  '2026-10-12 19:00:00', '2026-10-12 21:15:00', 3, 60.00, 180.00, 'Paid'),
(13, 10, 10, '2026-10-13 17:00:00', '2026-10-13 19:00:00', 2, 80.00, 160.00, 'Paid'),
(14, 5,  9,  '2026-10-14 14:00:00', '2026-10-14 17:30:00', 4, 80.00, 320.00, 'Paid');

INSERT INTO gaming_session (session_id, customer_id, station_id, start_time, end_time, hours_played, hourly_rate, session_fee, payment_status) VALUES
(15, 4,  3, NOW() - INTERVAL 90 MINUTE, NULL, NULL, 40.00, NULL, 'Unpaid'),
(16, 11, 6, NOW() - INTERVAL 30 MINUTE, NULL, NULL, 60.00, NULL, 'Unpaid');

INSERT INTO menu_item (item_id, item_name, category, unit_price, quantity_in_stock, discontinued) VALUES
(1,  'Bottled Water', 'Drinks',  20.00, 100, 0),
(2,  'Iced Tea',      'Drinks',  35.00,  60, 0),
(3,  'Cola',          'Drinks',  40.00,  48, 0),
(4,  'Brewed Coffee', 'Drinks',  60.00,  30, 0),
(5,  'Energy Drink',  'Drinks',  70.00,   8, 0),
(6,  'Potato Chips',  'Snacks',  35.00,  25, 0),
(7,  'French Fries',  'Snacks',  80.00,  20, 0),
(8,  'Nachos',        'Snacks',  95.00,   4, 0),
(9,  'Chicken Rice',  'Meals',  120.00,  15, 0),
(10, 'Burger Meal',   'Meals',  150.00,  12, 0),
(11, 'Silog Meal',    'Meals',  110.00,   0, 1),
(12, 'Creamy Pasta',  'Meals',  130.00,  10, 0);

INSERT INTO item_order (order_id, session_id, item_id, quantity, unit_price, order_time) VALUES
(1,  1,  2,  2,  35.00, '2026-09-05 14:30:00'),
(2,  1,  6,  1,  35.00, '2026-09-05 14:45:00'),
(3,  2,  5,  2,  70.00, '2026-09-06 18:20:00'),
(4,  3,  10, 1, 150.00, '2026-09-12 19:30:00'),
(5,  3,  3,  2,  40.00, '2026-09-12 20:00:00'),
(6,  5,  7,  1,  80.00, '2026-09-27 21:00:00'),
(7,  6,  4,  1,  60.00, '2026-10-01 13:30:00'),
(8,  8,  9,  1, 120.00, '2026-10-04 22:00:00'),
(9,  9,  8,  1,  95.00, '2026-10-08 19:00:00'),
(10, 10, 2,  3,  35.00, '2026-10-10 16:00:00'),
(11, 12, 12, 1, 130.00, '2026-10-12 20:00:00'),
(12, 14, 5,  2,  70.00, '2026-10-14 15:00:00');

INSERT INTO item_order (order_id, session_id, item_id, quantity, unit_price, order_time) VALUES
(13, 15, 1, 2, 20.00, NOW() - INTERVAL 60 MINUTE),
(14, 16, 6, 1, 35.00, NOW() - INTERVAL 15 MINUTE);
