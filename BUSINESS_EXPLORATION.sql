-- 1. What is the delivery performance for tech vs non-tech categories?

-- Delivery performance: Tech vs Non-Tech
WITH tech_categories AS (
  SELECT 'computers_accessories' AS cat UNION ALL
  SELECT 'telephony' UNION ALL
  SELECT 'electronics' UNION ALL
  SELECT 'home_appliances' UNION ALL
  SELECT 'consoles_games' UNION ALL
  SELECT 'small_appliances' UNION ALL
  SELECT 'air_conditioning' UNION ALL
  SELECT 'fixed_telephony' UNION ALL
  SELECT 'home_appliances_2' UNION ALL
  SELECT 'audio' UNION ALL
  SELECT 'small_appliances_home_oven_and_coffee' UNION ALL
  SELECT 'computers' UNION ALL
  SELECT 'cine_photo' UNION ALL
  SELECT 'portable_kitchen_food_processors' UNION ALL
  SELECT 'tablets_printing_image' UNION ALL
  SELECT 'pc_gamer'
),
order_classified AS (
  SELECT 
    o.order_id,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    CASE WHEN tc.cat IS NOT NULL THEN 'tech' ELSE 'non-tech' END AS product_type,
    DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days,
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delay_vs_estimated,
    DATEDIFF(o.order_delivered_carrier_date, o.order_approved_at) AS seller_handling_days,
    DATEDIFF(o.order_delivered_customer_date, o.order_delivered_carrier_date) AS shipping_days
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  JOIN products p ON oi.product_id = p.product_id
  LEFT JOIN tech_categories tc ON p.product_category_name = tc.cat
  WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
)
SELECT 
  product_type,
  COUNT(*) AS total_delivered_orders,
  ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
  ROUND(AVG(seller_handling_days), 2) AS avg_seller_handling_days,
  ROUND(AVG(shipping_days), 2) AS avg_shipping_days,
  -- % que llega tarde
  ROUND(100.0 * SUM(CASE WHEN delay_vs_estimated > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_late_delivery,
  -- % que llega a tiempo o antes
  ROUND(100.0 * SUM(CASE WHEN delay_vs_estimated <= 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_on_time,
  -- cuando llega tarde, cuántos días tarde en promedio
  ROUND(AVG(CASE WHEN delay_vs_estimated > 0 THEN delay_vs_estimated END), 2) AS avg_days_late_when_late
FROM order_classified
GROUP BY product_type;


-- 2. What is the freight cost vs product price ratio for tech categories?

SELECT 
  p.product_category_name,
  COUNT(*) AS items_sold,
  ROUND(AVG(oi.price), 2) AS avg_product_price,
  ROUND(AVG(oi.freight_value), 2) AS avg_freight,
  ROUND(100.0 * AVG(oi.freight_value) / NULLIF(AVG(oi.price),0), 2) AS freight_price_ratio_pct,
  ROUND(AVG(oi.price) - AVG(oi.freight_value), 2) AS gross_after_freight
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE p.product_category_name IN (
  'informatica_acessorios',
  'telefonia',
  'eletronicos',
  'eletrodomesticos',
  'consoles_games',
  'eletroportateis',
  'ar_e_ventilacao',
  'telefonia_fixa',
  'eletrodomesticos_2',
  'audio',
  'eletroportateis_ar_e_ventilacao',
  'pcs',
  'cine_foto',
  'portateis_cozinha_e_preparadores_de_alimentos',
  'tablets_impressao_imagem',
  'pc_gamer'
)
GROUP BY p.product_category_name
ORDER BY avg_product_price DESc;

-- la misma consulta pero solo con los valores precio promedio brutos luego de envio 


-- 3. What is the review score correlation with delivery time for tech products?

SELECT 
  p.product_category_name,
  COUNT(r.review_score) AS total_reviews_valid, -- solo cuenta no nulos
  ROUND(AVG(r.review_score), 2) AS avg_review_score,
  MIN(r.review_score) AS lowest_review,
  MAX(r.review_score) AS highest_review,
  ROUND(AVG(CASE WHEN r.review_score IS NOT NULL THEN r.review_score END), 2) AS avg_review_safe
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND r.review_score IS NOT NULL -- filtra nulos que tumban el AVG
  AND p.product_category_name IN (
    'pcs',
    'eletrodomesticos_2',
    'eletroportateis',
    'portateis_cozinha_e_preparadores_de_alimentos',
    'telefonia_fixa',
    'pc_gamer',
    'audio',
    'consoles_games',
    'informatica_acessorios',
    'eletrodomesticos',
    'cine_foto',
    'tablets_impressao_imagem',
    'telefonia',
    'eletronicos'
  )
GROUP BY p.product_category_name
ORDER BY avg_review_score DESC;



-- 4. What is the monthly seasonality for tech sales?

-- Estacionalidad REAL - compara meses del mismo año
SELECT 
  YEAR(o.order_purchase_timestamp) as year,
  MONTH(o.order_purchase_timestamp) as month,
  COUNT(DISTINCT o.order_id) as orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE p.product_category_name IN ('pcs','informatica_acessorios','telefonia','eletronicos','eletroportateis','consoles_games')
  AND YEAR(o.order_purchase_timestamp) = 2016
GROUP BY year, month
ORDER BY month;

-- Y luego lo mismo para 2018
-- 5. What is the cancellation and unavailable rate by tech category?
SELECT 
  p.product_category_name,
  COUNT(DISTINCT o.order_id) AS total_orders,
  SUM(CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
  SUM(CASE WHEN o.order_status = 'unavailable' THEN 1 ELSE 0 END) AS unavailable_orders,
  ROUND(SUM(CASE WHEN o.order_status = 'canceled' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT o.order_id), 2) AS cancel_rate_pct,
  ROUND(SUM(CASE WHEN o.order_status = 'unavailable' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT o.order_id), 2) AS unavailable_rate_pct,
  ROUND((SUM(CASE WHEN o.order_status IN ('canceled','unavailable') THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT o.order_id)), 2) AS total_failure_rate_pct
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE p.product_category_name IN (
  'pcs','eletrodomesticos_2','eletroportateis','portateis_cozinha_e_preparadores_de_alimentos',
  'telefonia_fixa','pc_gamer','audio','consoles_games','informatica_acessorios',
  'eletrodomesticos','cine_foto','tablets_impressao_imagem','telefonia','eletronicos'
)
GROUP BY p.product_category_name
ORDER BY total_failure_rate_pct DESC;

-- Magist Stable Customer Service Satisfation

WITH tech_categories AS (
  SELECT 'computers_accessories' AS cat UNION ALL
  SELECT 'telephony' UNION ALL
  SELECT 'electronics' UNION ALL
  SELECT 'home_appliances' UNION ALL
  SELECT 'consoles_games' UNION ALL
  SELECT 'small_appliances' UNION ALL
  SELECT 'air_conditioning' UNION ALL
  SELECT 'fixed_telephony' UNION ALL
  SELECT 'home_appliances_2' UNION ALL
  SELECT 'audio' UNION ALL
  SELECT 'small_appliances_home_oven_and_coffee' UNION ALL
  SELECT 'computers' UNION ALL
  SELECT 'cine_photo' UNION ALL
  SELECT 'portable_kitchen_food_processors' UNION ALL
  SELECT 'tablets_printing_image' UNION ALL
  SELECT 'pc_gamer'
),
orders_classified AS (
  SELECT DISTINCT
    o.order_id,
    o.order_purchase_timestamp,
    r.review_score,
    CASE WHEN t.cat IS NOT NULL THEN 'tech' ELSE 'non-tech' END AS tech_flag
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  JOIN products p ON oi.product_id = p.product_id
  -- AQUÍ ESTÁ LA CLAVE SEGÚN TU SCHEMA:
  JOIN product_category_name_translation tr ON p.product_category_name = tr.product_category_name
  LEFT JOIN tech_categories t ON tr.product_category_name_english = t.cat
  LEFT JOIN order_reviews r ON o.order_id = r.order_id
  WHERE o.order_status NOT IN ('canceled', 'unavailable')
)
SELECT
  DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS month,
  tech_flag,
  COUNT(DISTINCT order_id) AS count_of_orders,
  AVG(review_score) AS avg_review_score_customer_service
FROM orders_classified
GROUP BY 1, 2
ORDER BY 1, 2;

-- ingresos anuales de Magist solo ano 2017

SELECT
  SUM(p.payment_value) AS ingresos_2017
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
  AND EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017;
  
  -- para nuestras categorias
  
  SELECT
  SUM(i.price + i.freight_value) AS ingresos_totales_2017_categorias_filtradas
FROM orders o
JOIN order_items i ON o.order_id = i.order_id
JOIN products pr ON i.product_id = pr.product_id
WHERE o.order_status = 'delivered'
  AND EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
  AND pr.product_category_name IN (
    'home_appliances_2',
    'consoles_games',
    'computers',
    'audio',
    'computers_accessories',
    'tablets_printing_image',
    'electronics',
    'telephony',
    'fixed_telephony',
    'air_conditioning',
    'home_appliances',
    'small_appliances',
    'cine_photo',
    'small_appliances_home_oven_and_coffee',
    'pc_gamer',
    'portable_kitchen_food_processors'
  );