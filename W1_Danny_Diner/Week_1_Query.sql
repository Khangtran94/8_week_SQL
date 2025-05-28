-- 1. What is the total amount each customer spent at the restaurant?
DROP TABLE IF EXISTS RECORD;

CREATE TEMP TABLE RECORD AS
SELECT
	*
FROM
	SALES
	INNER JOIN MENU USING (PRODUCT_ID);

SELECT
	CUSTOMER_ID,
	SUM(PRICE) AS TOTAL_SPENT
FROM
	RECORD
GROUP BY
	CUSTOMER_ID
ORDER BY
	CUSTOMER_ID;

-- 2. How many days has each customer visited the restaurant?
SELECT
	CUSTOMER_ID AS CUSTOMER,
	COUNT(DISTINCT (ORDER_DATE)) AS NUMBER_DAYS_VISIT
FROM
	SALES
GROUP BY
	CUSTOMER
ORDER BY
	CUSTOMER;

-- 3. What was the first item from the menu purchased by each customer?
WITH
	FIRST_ITEM AS (
		SELECT
			CUSTOMER_ID,
			PRODUCT_ID,
			DENSE_RANK() OVER (
				PARTITION BY
					CUSTOMER_ID
				ORDER BY
					ORDER_DATE
			) AS FIRST_DATE
		FROM
			SALES
	)
SELECT
	DISTINCT CUSTOMER_ID,
	PRODUCT_NAME
FROM
	FIRST_ITEM
	INNER JOIN MENU USING (PRODUCT_ID)
WHERE
	FIRST_DATE = 1
	ORDER BY CUSTOMER_ID;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH
	TOTAL AS (
		SELECT
			PRODUCT_ID,
			COUNT(*) AS TOTAL_PURCHASE
		FROM
			SALES
		GROUP BY
			PRODUCT_ID
		ORDER BY
			TOTAL_PURCHASE DESC
		LIMIT
			1
	)
SELECT
	PRODUCT_NAME,
	TOTAL_PURCHASE
FROM
	TOTAL
	INNER JOIN MENU USING (PRODUCT_ID);

-- 5. Which item was the most popular for each customer?
WITH
	POPULAR_ITEM AS (
		SELECT
			CUSTOMER_ID,
			PRODUCT_ID,
			COUNT(*) AS TOTAL_PURCHASED
		FROM
			SALES
		GROUP BY
			CUSTOMER_ID,
			PRODUCT_ID
	),
	COMBINE AS (
		SELECT
			*,
			DENSE_RANK() OVER (
				PARTITION BY
					CUSTOMER_ID
				ORDER BY
					TOTAL_PURCHASED DESC
			) AS POPULAR
		FROM
			POPULAR_ITEM
	)
SELECT
	CUSTOMER_ID,
	PRODUCT_NAME,
	TOTAL_PURCHASED
FROM
	COMBINE
	INNER JOIN MENU USING (PRODUCT_ID)
WHERE
	POPULAR = 1
ORDER BY customer_id;

-- 6. Which item was purchased first by the customer after they became a member?
WITH
	RANKEDSALES AS (
		SELECT
			CUSTOMER_ID,
			ORDER_DATE,
			PRODUCT_ID,
			DENSE_RANK() OVER (
				PARTITION BY
					CUSTOMER_ID
				ORDER BY
					ORDER_DATE
			) AS RN
		FROM
			SALES
			INNER JOIN MEMBERS USING (CUSTOMER_ID)
		WHERE
			JOIN_DATE < ORDER_DATE
	)
SELECT customer_id, product_name
FROM rankedsales INNER JOIN menu USING (product_id)
WHERE rn = 1
ORDER BY customer_id ;

-- 7. Which item was purchased just before the customer became a member?
DROP TABLE IF EXISTS BEFORE_MEMBER;

CREATE TEMP TABLE BEFORE_MEMBER AS
SELECT
	*
FROM
	SALES
	LEFT JOIN MEMBERS USING (CUSTOMER_ID)
WHERE
	ORDER_DATE < JOIN_DATE;

SELECT DISTINCT
	CUSTOMER_ID,
	PRODUCT_NAME
FROM
	BEFORE_MEMBER
	INNER JOIN MENU ON BEFORE_MEMBER.PRODUCT_ID = MENU.PRODUCT_ID
ORDER BY
	CUSTOMER_ID;

-- 8. What is the total items and amount spent for each member before they became a member?
WITH
	COMBINE AS (
		SELECT
			*
		FROM
			BEFORE_MEMBER
			INNER JOIN MENU USING (PRODUCT_ID)
		ORDER BY
			CUSTOMER_ID
	)
SELECT
	CUSTOMER_ID,
	COUNT(*) AS TOTAL_ITEMS,
	SUM(PRICE) AS TOTAL_SPEND
FROM
	COMBINE
GROUP BY
	CUSTOMER_ID;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
DROP TABLE IF EXISTS POINTS;

CREATE TEMP TABLE POINTS AS
SELECT
	*,
	CASE
		WHEN PRODUCT_NAME != 'sushi' THEN PRICE * 10
		ELSE PRICE * 20
	END AS POINTS
FROM
	RECORD
ORDER BY
	CUSTOMER_ID;

SELECT
	CUSTOMER_ID,
	SUM(POINTS) AS TOTAL_POINTS
FROM
	POINTS
GROUP BY
	CUSTOMER_ID
ORDER BY
	CUSTOMER_ID;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH
	JANUARY AS (
		SELECT
			*
		FROM
			POINTS
			INNER JOIN MEMBERS USING (CUSTOMER_ID)
		WHERE
			EXTRACT(
				MONTH
				FROM
					ORDER_DATE
			) = 1
		ORDER BY
			CUSTOMER_ID,
			ORDER_DATE
	),
	AFTER_JOIN AS (
		SELECT
			*,
			CASE
				WHEN ORDER_DATE BETWEEN JOIN_DATE AND JOIN_DATE  + INTERVAL '7 days' THEN POINTS * 2
				ELSE POINTS
			END AS NEW_POINTS
		FROM
			JANUARY
	)
SELECT
	CUSTOMER_ID,
	SUM(NEW_POINTS) AS JANUARY_POINTS
FROM
	AFTER_JOIN
GROUP BY
	CUSTOMER_ID
ORDER BY
	CUSTOMER_ID;

-- Join All The Things vs rank all the things
WITH
	FINAL_JOIN AS (
		SELECT
			*
		FROM
			RECORD
			LEFT JOIN MEMBERS USING (CUSTOMER_ID)
	),
	MEMBERS_RANKED AS (
		SELECT
			CUSTOMER_ID,
			ORDER_DATE,
			PRODUCT_NAME,
			PRICE,
			CASE
				WHEN ORDER_DATE >= JOIN_DATE THEN 'Y'
				ELSE 'N'
			END AS MEMBER
		FROM
			FINAL_JOIN
		ORDER BY
			CUSTOMER_ID,
			ORDER_DATE
	)
SELECT *,
		CASE WHEN member = 'N' THEN NULL 
		ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date) END AS ranking
FROM members_ranked