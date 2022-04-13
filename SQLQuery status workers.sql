SET DATEFIRST 1;

WITH employee_status AS

(
SELECT 
  wrk.worker_id
  , wrk.location_id
  , stat.worker_status_name
  , sp.trades_point_code_sap
  , sp.trades_point_name
  , sp.trades_point_id
  , wrk.kl_start_dt
  , wrk.kl_end_dt
  , CONVERT (NVARCHAR, wrk.kl_start_dt, 112)  AS id_status_start
  , CONVERT (NVARCHAR, wrk.kl_end_dt, 112)  AS id_status_end


FROM dti.employee_hdim AS wrk
LEFT JOIN dti.sales_point_sdim AS sp ON
  wrk.trades_point_id = sp.trades_point_id
LEFT JOIN dti.employee_status_ldim AS stat ON
  wrk.worker_status_code = stat.worker_status_code

WHERE worker_status_name = 'Активный' AND trades_point_name != '<...>'
),

calendar_id_table AS
(
SELECT DISTINCT calendar_id_operday 
FROM dti.transaction_tran 
),

staff_tabel AS
(
SELECT *
FROM
	(
	SELECT *,
	CASE WHEN (id_status_start < calendar_id_operday) AND (calendar_id_operday < id_status_end)  THEN 1 ELSE 0 END staff
	FROM employee_status
	CROSS JOIN  calendar_id_table
	) staff_tabel
	WHERE staff != 0
),

staff_total AS
(
SELECT trades_point_code_sap, trades_point_name, trades_point_id, calendar_id_operday, SUM(staff) staff
FROM staff_tabel
GROUP BY trades_point_code_sap, trades_point_name, trades_point_id, calendar_id_operday
),

table_sales_day AS

(

SELECT calendar_id_operday, trades_point_id, SUM(line_fact_amt) sales_day, day_week
FROM(
	SELECT calendar_id_operday, trades_point_id, line_fact_amt, DATEPART(weekday, cheque_dttm) AS day_week
	FROM dti.transaction_tran 
	WHERE individual_id_seller != 0
	) AS table_sales
GROUP BY calendar_id_operday, trades_point_id, day_week 
)


SELECT TOP 100 *
FROM table_sales_day AS tsale
LEFT JOIN staff_total AS stafft ON (tsale.trades_point_id = stafft.trades_point_id AND tsale.calendar_id_operday = stafft.calendar_id_operday)
WHERE trades_point_code_sap IS NOT NULL