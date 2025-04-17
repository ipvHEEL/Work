-- =============================================
-- Версия BI:               6
-- Автор:                   Рогов А.Д.
-- Дата создания:           2025.17.04
-- Карточка параметра:      К02730/00-25, РАСП02137/00-25 (Notes://DB23/C3256416005D5671/0/73E79443B01025E4442579220023EECD)
-- Параметр:                Количество объектов информационного и объектового доступа, актуализированных в отчетном периоде
-- =============================================
DECLARE
    @datefrom DATETIME,
    @dateto DATETIME 

SET @datefrom = '2024-01-01'
SET @dateto = DATEADD(MS, -3, '2024-02-02');

WITH cte AS ( --документы, у которых >1 записи со статусом 20 в периоде
    SELECT 
        ParentDocUNIDs
    FROM vStatistics_all WITH (NOLOCK)
    WHERE 
        statusCode = 20
        AND server_time_at_create BETWEEN @datefrom AND @dateto
    GROUP BY ParentDocUNIDs
    HAVING COUNT(*) > 1  
)
, cte2 AS (
SELECT
   CASE 
		WHEN rc.resourcetypecode = '1' THEN 'Информационный доступ'
		WHEN rc.resourcetypecode = '2' THEN 'Объектовый доступ'
		WHEN rc.resourcetypecode = '3' THEN ' Удаленный доступ'
	ELSE	
		'Вкладка тип ресурса отсутсвует'
  END as 'Тип ресурса' 
, resourcetypename ------ Вид объекта
, dbo.svf_make_LN_link_desc(rc.server_name, rc.dbreplicaid, rc.universalid ,rc.resourcename) as [link] -- Наименование ресурсв
, stat.user_name_creator_FIO
, 1 cnt
FROM dbo.[(Управление доступом)_(ResourceCard)] rc WITH (NOLOCK)
	INNER JOIN vStatistics_all stat WITH (NOLOCK) ON rc.unid = stat.ParentDocUNIDs
		
WHERE  
    (stat.statusCode = 20  -- Активен
	AND 
	stat.server_time_at_create BETWEEN @datefrom AND @dateto) -- Дата перевода на статус "Активен" попадает в отчётный месяц.
    -- если для документа есть >1 записей со статусом 20
	OR ( -- Если карточка ресурса/объектового доступа в течение отчетного периода актуализировалась несколько раз, то в выгрузку попадают все значения "В действующие"
    stat.statusCode = 190 --В действующие
    AND stat.server_time_at_create BETWEEN @datefrom AND @dateto
    AND EXISTS (
         SELECT 1 
         FROM cte c
         WHERE c.ParentDocUNIDs = stat.ParentDocUNIDs
      )
   )
AND
rc.resourcetypecode IN ('1', '2')
) -- 1.3.3. Поле "Тип ресурса" принимает значение "информационный доступ" или "объектовый доступ". 
SELECT * FROM cte2

UNION ALL 

SELECT 
	'Документы не найдены'
	, NULL
	, NULL
	, NULL
	, 0
WHERE NOT EXISTS (SELECT NULL FROM cte2)

