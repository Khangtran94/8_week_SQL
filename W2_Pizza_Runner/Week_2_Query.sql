SET search_path TO pizza_runner;

-- A. Pizza Metrics
-- 1. How many pizzas were ordered?
SELECT COUNT(*) AS number_pizza_orders
FROM customer_orders;

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT(customer_id)) AS unique_customer 
FROM customer_orders;

-- 3. How many successful orders were delivered by each runner?
SELECT DISTINCT cancellation
FROM customer_orders
INNER JOIN runner_orders
USING (order_id);

-- 4. How many of each type of pizza was delivered?
