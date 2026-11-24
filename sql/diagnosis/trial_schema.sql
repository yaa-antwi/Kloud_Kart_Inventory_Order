CREATE TEMP TABLE practice_orders (
    order_id INT,
    customer_id INT,
    status VARCHAR(20),
    total_amount NUMERIC(10,2)
);

INSERT INTO practice_orders VALUES
(101, 1, 'completed', 100),
(102, 1, 'completed', 150),
(103, 1, 'pending', 50),
(104, 2, 'completed', 200),
(105, 2, 'pending', 100),
(106, 3, 'completed', 300);