-- IF OBJECT_ID('tempdb..#Contratos') IS NOT NULL DROP TABLE #Contratos
-- SELECT
--     C.Id,
--     C.Escritorio,
--     C.Data AS DataEntrada
-- INTO
--     #Contratos
-- FROM
--     Temp_Contracts C
-- WHERE
--     LOWER(C.Status) = 'ativo' and FORMAT(C.Data, 'yyyy/MM') = '2016/03'

-- DECLARE @DataEntrada DATETIME, @DataAtual DATETIME;

-- SELECT @DataEntrada = MIN(DataEntrada)
-- FROM #Contratos
-- SELECT @DataAtual = GETUTCDATE()

-- IF OBJECT_ID('tempdb..#Progresso') IS NOT NULL DROP TABLE #Progresso
-- SELECT
--     FORMAT(DATEFROMPARTS(Year, Month, 1), 'yyyy/MM') AS Cohort,
--     DATEFROMPARTS(Year, Month, 1) AS DataReferencia,
--     Progress
-- INTO
--     #Progresso
-- FROM
--     GetCohortsPeriods(@DataEntrada, @DataAtual)

WITH ContadoresPagantes AS
(
    SELECT
        AD.AccountantId AS AccountantId
    FROM
        AccountantDetails AD LEFT JOIN AccountantBillingDetails ABD ON AD.AccountantId = ABD.AccountantId
    WHERE
        AD.AccountantId = '5DF7C9D2-EA19-4C08-A48A-24810829E33E' AND
        AD.DeleteDate IS NULL AND
        ABD.BillingStatus = 1 -- PAGANTE
),
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
),
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
),
TotalEmpresasAssinadas AS
(
    SELECT
        O.AccountantId,
        COUNT(*) AS Count
    FROM
        Organizacoes O
    WHERE
        O.SubscriptionType = 0 AND
        O.SubscriptionId IS NOT NULL AND
        (
            O.SubscriptionEndDate >= GETUTCDATE() OR
            O.SubscriptionEndDate >= DATEADD(DAY, 1, DATEADD(MONTH, -3, GETUTCDATE()))
        )
    GROUP BY
        O.AccountantId
),
TotalEmpresasCentralCobranca AS
(
    SELECT
        O.AccountantId,
        COUNT(*) AS Count
    FROM
        Organizacoes O
            INNER JOIN Configurations C ON O.OrganizationId = C.ReferenceId
    WHERE
        O.SubscriptionType = 1 AND -- Pago pelo contador
        C.[Key] = 'BillingCentralEnabled' AND
        NOT EXISTS (
            SELECT
                1
            FROM
                [Configurations] Co
            WHERE
                Co.ReferenceId = O.OrganizationId AND 
                Co.[Key] = 'BillingCentralEnabledExpDt' AND
                Co.Value >= CONVERT(CHAR(10), GETDATE(), 120)
        ) 
    GROUP BY
        O.AccountantId
),
TotalEmpresasGratuitas AS
(
    SELECT 
        ACS.AccountantId,
		SUM(CASE WHEN ACS.Gratuities IS NULL THEN 0 ELSE ACS.Gratuities END) AS Count
	FROM
        AccountantSubscriptions ACS (NOLOCK) 
	WHERE
        ACS.DeletedDate is null
    GROUP BY
        ACS.AccountantId
),
TotalEmpresasCCX AS
(
    SELECT
        AO.AccountantId,
        COUNT(*) AS Count
    FROM
        Organizacoes AO
            LEFT JOIN Organizations O ON AO.OrganizationId = O.OrganizationId
            INNER JOIN Configurations C ON AO.OrganizationId = C.ReferenceId
    WHERE
        ISNULL(O.NiboDocsEnabled, 0) = 0 AND
        C.[Key] = 'AccountAndStatementEnabled' AND
        C.Value = 'true'
    GROUP BY
        AO.AccountantId
),
TotalEmpresasNiboDocs AS
(
    SELECT
        AO.AccountantId,
        COUNT(*) AS Count
    FROM
        Organizacoes AO
            INNER JOIN Organizations O ON AO.OrganizationId = O.OrganizationId
            INNER JOIN Configurations C ON AO.OrganizationId = C.ReferenceId
    WHERE
        O.NiboDocsEnabled = 1 AND
        (
            (
                C.[Key] = 'AccountAndStatementEnabled' AND
                C.Value = 'true'
            ) OR
            (
                AO.ImportEnabled = 1
            )
        )
    GROUP BY
        AO.AccountantId
),
TotalEmpresasCobrarContador AS
(
    SELECT
        O.AccountantId,
        COUNT(*) - 
        (SELECT TECCX.Count FROM TotalEmpresasCCX TECCX WHERE TECCX.AccountantId = O.AccountantId) -
        (SELECT TEND.Count FROM TotalEmpresasNiboDocs TEND WHERE TEND.AccountantId = O.AccountantId) AS Count
    FROM
        Organizacoes O
            LEFT JOIN Configurations C ON O.OrganizationId = C.ReferenceId
    WHERE
        C.[Key] IN ('AccountAndStatementEnabled', 'IuBillingTypeValue', 'IuBillingType') AND
        O.IsInvoiceDownload = 0 AND
        (
            (
                O.ImportEnabled = 0 AND
                O.SubscriptionType = 1 AND
                O.TrialEndDate < GETUTCDATE()
            ) OR
            (
                C.[Key] = 'AccountAndStatementEnabled' AND
                C.Value = 'true'
            )
        )
    GROUP BY
        O.AccountantId
)
SELECT
    CP.AccountantId,
    ISNULL(TEC.Count, 0) AS 'Total de empresas conectadas',
    ISNULL(TECC.Count, 0) AS 'Total de empresas para cobrar o contador',
    ISNULL(TEA.Count, 0) AS 'Total de empresas assinadas',
    ISNULL(TECeCo.Count, 0) AS 'Total de empresas na central de cobranças',
    ISNULL(TECCX.Count, 0) AS 'Total de empresas CCX',
    ISNULL(TEND.Count, 0) AS 'Total de empresas NiboDocs',
    ISNULL(TECC.Count, 0) + ISNULL(TEA.Count, 0) + ISNULL(TECeCo.Count, 0) + ISNULL(TECCX.Count, 0) + ISNULL(TEND.Count, 0) AS 'Total de empresas'
FROM
    ContadoresPagantes CP
        LEFT JOIN TotalEmpresasConectadas TEC ON CP.AccountantId = TEC.AccountantId
        LEFT JOIN TotalEmpresasCobrarContador TECC ON CP.AccountantId = TECC.AccountantId 
        LEFT JOIN TotalEmpresasAssinadas TEA ON CP.AccountantId = TEA.AccountantId
        LEFT JOIN TotalEmpresasCentralCobranca TECeCo ON CP.AccountantId = TECeCo.AccountantId
        LEFT JOIN TotalEmpresasCCX TECCX ON CP.AccountantId = TECCX.AccountantId
        LEFT JOIN TotalEmpresasNiboDocs TEND ON CP.AccountantId = TEND.AccountantId