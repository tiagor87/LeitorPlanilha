IF OBJECT_ID('tempdb..#Contratos') IS NOT NULL DROP TABLE #Contratos
SELECT
    C.Id,
    C.Escritorio,
    C.Data AS DataEntrada
INTO
    #Contratos
FROM
    Temp_Contracts C
WHERE
    LOWER(C.Status) = 'ativo' and FORMAT(C.Data, 'yyyy/MM') = '2016/03'

DECLARE @DataEntrada DATETIME, @DataAtual DATETIME;

SELECT @DataEntrada = MIN(DataEntrada)
FROM #Contratos
SELECT @DataAtual = GETUTCDATE()

IF OBJECT_ID('tempdb..#Progresso') IS NOT NULL DROP TABLE #Progresso
SELECT
    FORMAT(DATEFROMPARTS(Year, Month, 1), 'yyyy/MM') AS Cohort,
    DATEFROMPARTS(Year, Month, 1) AS DataReferencia,
    Progress
INTO
    #Progresso
FROM
    GetCohortsPeriods(@DataEntrada, @DataAtual)

WITH ContadoresPagantes AS
(
SELECT
    AD.AccountantId AS AccountantId
FROM
    AccountantDetails AD LEFT JOIN AccountantBillingDetails ABD ON AD.AccountantId = ABD.AccountantId
WHERE
        AD.AccountantId = 'ff483a96-86b7-4ba3-8a5d-47b1951f4ab9' AND
    AD.DeleteDate IS NULL AND
    ABD.BillingStatus = 1 -- PAGANTE
)
,
Organizacoes AS
(
    SELECT
    AD.AccountantId,
    AO.OrganizationId,
    AO.SubscriptionType,
    O.TrialEndDate,
    S.SubscriptionId,
    O.SubscriptionEndDate,
    CONVERT(BIT, 
            CASE
                WHEN CHARINDEX('importtype=1', AO.Configuration) > 0 THEN 1 
                WHEN CHARINDEX('importtype=2', AO.Configuration) > 0 THEN 1
                ELSE 0 
            END
        ) AS ImportEnabled,
    CONVERT(BIT, 
            CASE
                WHEN CHARINDEX('isinvoicedownload=true', AO.Configuration) > 0 THEN 1 
                ELSE 0 
            END
        ) AS IsInvoiceDownload
FROM
    ContadoresPagantes AD
    LEFT JOIN AccountantOrganizations AO (NOLOCK) ON AD.AccountantId = AO.AccountantId
    LEFT JOIN Organizations O (NOLOCK) ON AO.OrganizationId = O.OrganizationId
    LEFT JOIN Subscriptions S (NOLOCK) ON S.OrganizationId = O.OrganizationId and S.CancelDate is null
WHERE
    AO.DeleteDate IS NULL AND
    O.DeleteDate IS NULL
)
,
TotalEmpresasConectadas AS
(
    SELECT
    O.AccountantId,
    COUNT(*) AS Count
FROM
    Organizacoes O
WHERE
        O.OrganizationId IS NOT NULL
GROUP BY
        O.AccountantId
)
,
TotalEmpresasCobrarContador AS
(
    SELECT
    O.AccountantId,
    COUNT(*) AS Count
FROM
    Organizacoes O
    LEFT JOIN Configurations C ON O.OrganizationId = C.ReferenceId
WHERE
        C.[Key] IN ('AccountAndStatementEnabled', 'IuBillingTypeValue', 'IuBillingType') AND
    O.IsInvoiceDownload = 0 AND
    (
    		(
    			O.ImportEnabled = 0 AND O.SubscriptionType = 1 AND O.TrialEndDate < GETUTCDATE()
    		) OR
    (
    			C.[Key] = 'AccountAndStatementEnabled' AND
    C.Value = 'true'
    		)
        )
GROUP BY
        O.AccountantId
)
,
TotalEmpresasAssinadas AS
(
        SELECT
    COUNT(*)
FROM
    OrganizationDetails AO
WHERE
            AO.AccountantId = AD.AccountantId AND
    AO.SubscriptionType = 0 AND
    AO.SubscriptionId IS NOT NULL AND
    (
                AO.SubscriptionEndDate >= GETUTCDATE() OR
    AO.SubscriptionEndDate >= DATEADD(DAY, 1, DATEADD(MONTH, -3, GETUTCDATE()))
            )
    )
SELECT
    CP.AccountantId,
    TEC.Count AS 'Total de empresas conectadas',
    TECC.Count AS 'Total de empresas para cobrar o contador'
FROM
    ContadoresPagantes CP
    JOIN TotalEmpresasConectadas TEC ON CP.AccountantId = TEC.AccountantId
    JOIN TotalEmpresasCobrarContador TECC ON CP.AccountantId = TECC.AccountantId 
    (
SELECT
    COUNT(*)
FROM
    OrganizationDetails AO
WHERE
            AO.AccountantId = AD.AccountantId AND
    AO.SubscriptionType = 0 AND
    AO.SubscriptionId IS NOT NULL AND
    (
                AO.SubscriptionEndDate >= GETUTCDATE() OR
    AO.SubscriptionEndDate >= DATEADD(DAY, 1, DATEADD(MONTH, -3, GETUTCDATE()))
            )
) AS 'Emp Ass',
    -- (
	--     SELECT count(*)
    -- FROM
    --     OrganizationDetails ao
    --     JOIN configurations AS config ON ao.OrganizationId = config.ReferenceId
    -- WHERE
    --         ao.accountantid = ad.AccountantId
    --     AND ao.SubscriptionType = 1 -- pg pelo contador
    --     AND config.[Key] = 'BillingCentralEnabled'
    --     AND NOT EXISTS (SELECT 1
    --     FROM [Configurations] c
    --     WHERE c.ReferenceId = ao.OrganizationId AND c.[Key] = 'BillingCentralEnabledExpDt' AND c.Value >= CONVERT(CHAR(10), GETDATE(), 120)) 
    -- ) AS 'Cob Conectadas',
    -- ( SELECT COUNT(*)
    -- FROM OrganizationDetails AS ao
    --     JOIN configurations AS config ON ao.OrganizationId = config.ReferenceId
    -- WHERE	ao.accountantid = ad.AccountantId
    --     AND config.[Key] = 'AccountAndStatementEnabled'
    --     AND config.Value = 'true'
	-- ) AS 'CCX Conectada',
    -- (
	-- SELECT COUNT(*)
    -- FROM OrganizationDetails AS ao
    --     JOIN Organizations o ON ao.OrganizationId = o.OrganizationId
    -- WHERE  ao.accountantid = ad.AccountantId
    --     AND o.NiboDocsEnabled = 1
	-- ) AS 'ND conectadas'