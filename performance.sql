-- =============================================
-- Версия BI:               7
-- Автор:                   Рогов А.Д.
-- Дата создания:           2025.04.11
-- Карточка параметра:      К19528/00-24, РАСП16402/00-24 (Notes://DB23/C3256416005D5671/0/3558F5B176C717A6C325789A0030CD16)
-- Параметр:                Производительность труда Специалиста по допуску
-- =============================================
DECLARE
	@datefrom DATETIME,
	@dateto DATETIME

SET @datefrom = dbo.svf_get_first_day_month_before(GETDATE())
SET @dateto = dbo.svf_get_last_day_month_before(GETDATE());
-----------------------------------Выборка 1----------------------------------
WITH cte AS (
SELECT	
	server_name 
	, dbreplicaid
	 ,universalid
	, shortpath as [link] -- 1.4.1. Поле "Полный иерархический путь (аббревиатуры):"+ссылка ( выгружается наименование частной должности и ссылка на нее)
	, acl_staffln -- 1.4.1. Поле "Полный иерархический путь (аббревиатуры):"+ссылка ( выгружается наименование частной должности и ссылка на нее)
	, personfio -- 1.4.3. Поле "Назначен" (выгружается ФИО сотрудника, занимающего частную должность (поле "personfio"))
from [(Структура)_(1)] WITH (NOLOCK)
WHERE
	shortpath in ('ПСПП|ИБ|C6|Начальник подгруппы - специалист C6',
					'ПСПП|ИБ|C6|Специалист C6') -- 1.3.1. Поле "Полный иерархический путь (аббревиатуры):" принимает одно из значени
)------------------------------------------------------------------------------
-----------------------------------Выборка 2----------------------------------
, cte2 AS (
SELECT
	 dbo.svf_make_LN_link_desc(sog.server_name, sog.dbreplicaid, sog.universalid, sog.type_project) as [link1] -- 2.4.1. Поле "Вид документа"+ссылка ( выгружается наименование вида документа и ссылка на него)
	 , sog.registration_number -- 2.4.2. Регномер (Поле "Регистрационный №")
	 , sog.statconfirmdate -- 2.4.3. Дата подтверждения (Поле "Подтвержден:")
	 , sog.unid -- 2.4.3. Дата подтверждения (Поле "Подтвержден:")
FROM dbo.V_СогласованиеV3_Project vsog WITH (NOLOCK, NOEXPAND)
	JOIN dbo.[(Согласование V3)_(Project)] sog WITH (NOLOCK)
		ON vsog.id = sog.id
WHERE sog.type_project IN ('Руководство / инструкция администратора IT системы' -- 2.3.1. Поле "Вид документа" принимает одно из значений: 
						,'Паспорт объектового доступа'
						,'Заявление о переводе сотрудника'
						,'Заявление о приеме на работу'
						,'Приказ / Распоряжение о создании / изменении структуры'
						,'Приказ / Распоряжение об изменении структуры на основании решения Совета'
						,'Заявление о назначении временно исполняющего обязанности'
						,'Карточка IT работы'
						,'Разрешение о прохождении практики на должности'
						)
						and sog.statconfirmdate BETWEEN @datefrom and @dateto -- 2.3.2. Поле "Дата подтверждения" включается в отчетный период
 ------------------------------------------------------------------------------
)-----------------------------------Выборка 3----------------------------------
, cte3 AS (
SELECT 
	visa.author_fio as fio
	,dbo.svf_make_LN_link_desc(c.server_name, c.dbreplicaid, c.universalid, visa.author_fio + ' ' + c.link ) as link_plus_fio-- 1.2. Должность (п. 1.4.1 Выборки 1)
	,CASE
		WHEN 
			ROW_NUMBER() OVER (PARTITION BY visa.mostparentdocunid ORDER BY (SELECT NULL)) = 1 -- 3.5.1. Количество уникальных проектов попавших в выборку 3 (считаем по полю MostParentDocUNID ).
		THEN 1
		ELSE 0
	END AS cnt
	, CASE 
		WHEN 
			ROW_NUMBER() OVER (PARTITION BY visa.author_fio ORDER BY (SELECT NULL)) = 1 -- Колличество уникальных ФИО
		THEN 1
		ELSE 0 
	END AS cnt2
	, c2.link1 -- 1-я колонка.  Вид документа (+ ссылка) (п. 1.1. Перечня данных)
	, c2.registration_number -- 2-я колонка.  Регистрационный номер (п. 1.2. Перечня данных)
	, c2.statconfirmdate -- 3-я колонка.  Дата подтверждения (п. 1.3. Перечня данных)
	
FROM [dbo].[(Комментарии)_(Visa)] visa  with(NOLOCK)  
	JOIN
		cte c 
		ON visa.author_ln_edit = c.acl_staffln -- 3.3.4. Поле author_LN_edit равно значению в п.1.4.2. Выборки 1
	JOIN 
		cte2 c2
		ON visa.mostparentdocunid = c2.unid -- 3.3.2. Виза принадлежит проекту из выборки 2 (поле MostParentDocUNID = UNID проекта из выборки 2)
WHERE
	visa.currentlevel = 1
)
SELECT *
	, SUM(cnt) OVER(PARTITION BY fio),
	SUM(cnt) OVER()  FROM cte3

UNION ALL

SELECT
	'Докусменты не найдены'
	, NULL
		, 0
		, 0
		, NULL
		, NULL
		, NULL
		, 0
		, 0
WHERE NOT EXISTS(SELECT NULL FROM cte3)

