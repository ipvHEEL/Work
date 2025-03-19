-- ==============================================
-- Версия BI:               3
-- Автор:                   Рогов А.Д.
-- Дата создания:           19.03.2025
-- Карточка параметра:      К01911/00-25, РАСП01473/00-25 (Notes://DB23/C3256416005D5671/0/15211A1B00969A5A43257FD80057B377)
-- Параметр:                Полнота и достоверность сведений, заявленных в Уведомлении об участии в иностранных компаниях
-- ==============================================

DECLARE
    @datefrom DATETIME,
    @dateto DATETIME

SET @datefrom = dbo.svf_get_first_day_month_before(GETDATE())
SET @dateto = dbo.svf_get_last_day_month_before(GETDATE())

-- Выборка 1: Уникальные идентификаторы документов из таблицы "Акты"
SELECT 
    act.unid AS [ActUnid] -- 1.4.1. Уникальный  код документа (Unid)
	, act.[name] as [ActName]
INTO #TempActs
FROM 
    [(Акты)_(Документ)] act WITH (NOLOCK)
WHERE
    act.[name] = 'Проверка полноты и достоверности сведений, заявленных в Уведомлении об участии в иностранных компаниях' -- 1.3.1. Вид нормативного акта (поле ViewActName) - Чек-лист технологического надзора
    AND act.viewactname = 'Чек-лист технологического надзора' -- 1.3.2.. Тематика акта (поле name) - Проверка полноты и достоверности сведений, заявленных в Уведомлении об участии в иностранных компаниях

-- Выборка 2: Данные из таблицы "Сводки ТН"
SELECT 
  dbo.svf_make_LN_link_desc(tn.server_name, tn.dbreplicaid, tn.universalid,  tn.xnode_number) AS [JournalNumber], -- 2.4.1. Номер Журнала технадзора с гиперссылкой (поле "xNode_Number")
    tn.xnode_creator AS [Initiator], -- 2.4.2. Инициатор (поле "xNode_Creator")Инициатор (поле "xNode_Creator")
    tn.xnode_closed AS [ConfirmationDate], -- 2.4.3. Дата подтверждения ("xNode_Closed")
    tn.xnode_object AS [CheckedObjects], -- 2.4.4. Проверенные объекты (поле "xNode_Object")
	tn.xnode_actrootunid AS [tnunid],
    COUNT(*) OVER () AS [TotalDocumentsCount], -- 2.5.1. Количество документов, определенных Выборкой 2.
    SUM(CAST(tn.xnode_object AS INT)) OVER () AS [TotalCheckedObjects] -- 2.5.2. Сумма значений в поле Проверенные объекты (п.2.4.4.) всех документов, определенных Выборкой 2.
INTO #TempTN 
FROM 
    [(Сводки ТН)_(f.BookS)] tn WITH (NOLOCK)
JOIN 
    #TempActs act ON tn.xnode_actrootunid = act.ActUnid -- 2.3.3. Поле "Основной акт" (xNode_ActRoot) = документ из Выборки 1 (п.1.4.1.)
WHERE
    tn.xnode_closed BETWEEN @datefrom AND @dateto -- 2.3.2. Дата подтверждения попадает в отчетный период, определенный в соответствии с разделом Определения и обозначения Бизнес-логики (поле "xNode_Closed")

-- Выборка 3: 
SELECT 
    dbo.svf_make_LN_link_desc(tn.server_name, tn.dbreplicaid, tn.universalid,  tn.xnode_number) AS [JournalNumber], -- 3.4.1. Номер Журнала технадзора с гиперссылкой (поле "xNode_Number")
    tn.xnode_creator AS [Initiator], -- 3.4.2. Инициатор (поле "xNode_Creator")Инициатор (поле "xNode_Creator")
    tn.xnode_closed AS [ConfirmationDate], -- 3.4.3. Дата подтверждения ("xNode_Closed")
    tn.xnode_error AS [Violations], -- 3.4.4. Нарушения  (поле "xNode_Error")
    COUNT(*) AS [TotalViolationsCount], -- 3.5.1. Количество документов, определенных Выборкой 3.
    SUM(CAST(tn.xnode_object AS INT)) AS [TotalCheckedObjects] -- 3.5.2. Сумма значений в поле Количество событий (п. 3.4.4.) всех документов, определенных Выборкой 3.
INTO #TempViolations
FROM 
    [(Сводки ТН)_(f.BookS)] tn WITH (NOLOCK)
JOIN 
    #TempActs act ON tn.xnode_actrootunid = act.ActUnid -- 3.3.3. Поле "Основной акт" (xNode_ActRoot) = документ из Выборки 1 (п.1.4.1.)
WHERE
    tn.xnode_closed BETWEEN @datefrom AND @dateto -- 3.3.2. Дата подтверждения попадает в отчетный период, определенный в соответствии с разделом Определения и обозначения Бизнес-логики (поле "xNode_Closed"
    AND tn.xnode_error > 0 -- 3.3.4. В поле Нарушения  (поле "xNode_Error") указано значение больше 0.
GROUP BY 
    tn.xnode_number, 
    tn.xnode_creator, 
    tn.xnode_closed, 
    tn.xnode_error;

WITH cte AS (
SELECT 
    tn.JournalNumber, -- 1.1. Номер Журнала технадзора с гиперссылкой (п. 2.4.1. Выборки 2: "Технадзор").
    ActName AS ChecklistName, -- 1.2. Наименование чек-листа (п. 1.4.2. Выборки 1: "Акты").
    tn.Initiator, -- 1.3. Инициатор  (п. 2.4.2. Выборки 2: "Технадзор").
    tn.ConfirmationDate, -- 1.4. Дата подтверждения (п. 2.4.3 Выборки 2: "Технадзор").
    tn.TotalDocumentsCount, -- 1.5. Количество Журналов, подтвержденных в отчетном периоде (п.2.5.1. Выборки 2: "Технадзор").
    tn.TotalCheckedObjects, -- 1.6. Количество проверенных объектов в отчетном периоде (п. 2.5.2. Выборки 2: "Технадзор")
    v.TotalViolationsCount, -- 1.5. Количество Журналов, подтвержденных в отчетном периоде, с выявленными несоответствиями (п.3.5.1. Выборки 3: "Технадзор").
    v.TotalCheckedObjects AS [TotalViolationsSum] -- 1.6. Количество выявленных несоответствий в отчетном периоде (п. 3.5.2. Выборки 3: "Технадзор").
FROM 
    #TempTN tn
JOIN 
    #TempActs act ON tn.tnunid = act.ActUnid
LEFT JOIN 
    #TempViolations v ON tn.JournalNumber = v.JournalNumber

)
SELECT * FROM cte


UNION ALL
	
SELECT 'Документы не найдены'
	, NULL
	, NULL
	, NULL
	, 0
	, 0
	, 0
	, 0
WHERE NOT EXISTS (SELECT NULL FROM cte)

DROP TABLE #TempActs
DROP TABLE #TempTN
DROP TABLE #TempViolations
