WITH cte AS 
(
    SELECT 
        category,
        dbo.svf_make_LN_link_desc(server_name, dbreplicaid, universalid, unit) AS 'link',
        Status_unit_name,
        location_unit,
        1 AS cnt,
        CASE 
            WHEN category = 'Оборудование АПС/Терминал въезда-выезда' AND function_unit IN ('Контроль въезда', 'Въездной парковочный терминал') THEN 'Терминал въезда'
            WHEN category = 'Оборудование АПС/Терминал въезда-выезда' AND function_unit IN ('Контроль выезда', 'Выездной парковочный терминал') THEN 'Терминал выезда'
            WHEN category = 'Оборудование АПС/Кассовый автомат' THEN 'Кассовый терминал'
            WHEN category = 'Оборудование АПС/Шлагбаум' THEN 'Шлагбаум'
            WHEN category = 'Оборудование АПС/Видеокамера (распознавание номерных знаков автомобилей)' THEN 'Видеокамера СРНЗ'
            WHEN category = 'Оборудование АПС/Мультикон' THEN 'Мультикон'
            WHEN category = 'Оборудование АПС/Банкнотоприемник' THEN 'Банкнотоприемник'
            WHEN category = 'Оборудование АПС/Оборудование Uniteller' THEN 'Оборудование Uniteller'
            ELSE 'Не указано'
        END AS 'Тип КЕ'
    FROM 
        [TotalReportDB].[dbo].[(Проведение IT-работ)_(unit)] WITH (NOLOCK)
    WHERE 
        enterprise_owner_unit = 'DOMODEDOVO ASSET MANAGEMENT'
        AND Last_version = 1
        AND ([delete] IS NULL OR [delete] = '')
        AND (
            -- Выборка 1 и 2 (Терминалы въезда-выезда с разными функциями)
            (
                category = 'Оборудование АПС/Терминал въезда-выезда' 
                AND 
                (
                    function_unit IN ('Контроль въезда', 'Въездной парковочный терминал')    -- Выборка 1
                    OR 
                    function_unit IN ('Контроль выезда', 'Выездной парковочный терминал')    -- Выборка 2
                )
            )
            -- Выборки 3-8 (остальные категории без условий на function_unit)
            OR category = 'Оборудование АПС/Кассовый автомат'            -- Выборка 3
            OR category = 'Оборудование АПС/Шлагбаум'                   -- Выборка 4
            OR category = 'Оборудование АПС/Видеокамера (распознавание номерных знаков автомобилей)' -- Выборка 5
            OR category = 'Оборудование АПС/Мультикон'                  -- Выборка 6
            OR category = 'Оборудование АПС/Банкнотоприемник'           -- Выборка 7
            OR category = 'Оборудование АПС/Оборудование Uniteller'     -- Выборка 8
        )
)
SELECT [Тип КЕ],
    category,
    link,
    Status_unit_name,
    location_unit,
    cnt

FROM 
    cte

UNION ALL

SELECT 
    'Документы не найдены',
    NULL,
    NULL,
    NULL,
    NULL,
    0
WHERE 
    NOT EXISTS (SELECT NULL FROM cte);

[Этапы вычисления Аналитического процессора:
	1.  Вычислить подытог: <New Custom Subtotal> 
	2.  Выполнить перекрестное табулирование
]
