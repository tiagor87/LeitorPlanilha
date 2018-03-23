WITH ContadoresPagantes AS
(
    SELECT
        AD.AccountantId,
        FORMAT(AD.CreateDate, 'yyyy/MM') AS Cohort,
        AD.CreateDate,
        AD.Name
    FROM
        AccountantDetails AD (NOLOCK)
            LEFT JOIN AccountantBillingDetails ABD (NOLOCK) ON AD.AccountantId = ABD.AccountantId
    WHERE
--        AD.AccountantId = '3004cba3-474b-4e96-8283-46a54197acaf' AND
        AD.DeleteDate IS NULL AND
        ABD.BillingStatus = 1 AND -- PAGANTE
        FORMAT(AD.CreateDate, 'yyyy/MM') = '2015/11'
),
Organizacoes AS
(
    SELECT
        AD.AccountantId,
        AD.CreateDate AS AccountantCreateDate,
        AO.OrganizationId,
        AO.SubscriptionType,
        O.TrialEndDate,
        S.SubscriptionId,
        O.CreateDate,
        O.SubscriptionStartDate,
        O.SubscriptionEndDate,
        CONVERT
        (
            BIT, 
            CASE
                WHEN CHARINDEX('importtype=1', AO.Configuration) > 0 THEN 1 
                WHEN CHARINDEX('importtype=2', AO.Configuration) > 0 THEN 1
                ELSE 0 
            END
        ) AS ImportEnabled,
        CONVERT
        (
            BIT, 
            CASE
                WHEN CHARINDEX('isinvoicedownload=true', AO.Configuration) > 0 THEN 1 
                ELSE 0 
            END
        ) AS IsInvoiceDownload
    FROM
        ContadoresPagantes AD
            LEFT JOIN AccountantOrganizations AO (NOLOCK) ON AD.AccountantId = AO.AccountantId
            LEFT JOIN Organizations O (NOLOCK) ON AO.OrganizationId = O.OrganizationId
            LEFT JOIN Subscriptions S (NOLOCK) ON S.OrganizationId = O.OrganizationId
    WHERE
        S.CancelDate IS NULL AND
        AO.DeleteDate IS NULL AND
        O.DeleteDate IS NULL
),
TotalEmpresasAssinadas AS
(
    SELECT
        FORMAT(O.AccountantCreateDate, 'yyyy/MM') AS Cohort,
        FORMAT(O.CreateDate, 'yyyy/MM') AS Month,
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
        FORMAT(O.AccountantCreateDate, 'yyyy/MM'),
        FORMAT(O.CreateDate, 'yyyy/MM')
),
TotalEmpresasCentralCobranca AS
(
    SELECT
        FORMAT(O.AccountantCreateDate, 'yyyy/MM') AS Cohort,
        FORMAT(O.CreateDate, 'yyyy/MM') AS Month,
        COUNT(*) AS Count
    FROM
        Organizacoes O
            INNER JOIN Configurations C (NOLOCK) ON O.OrganizationId = C.ReferenceId
    WHERE
        O.SubscriptionType = 1 AND -- Pago pelo contador
        C.[Key] = 'BillingCentralEnabled' AND
        NOT EXISTS (
            SELECT
                1
            FROM
                [Configurations] Co (NOLOCK)
            WHERE
                Co.ReferenceId = O.OrganizationId AND 
                Co.[Key] = 'BillingCentralEnabledExpDt' AND
                Co.Value >= CONVERT(CHAR(10), GETDATE(), 120)
        ) 
    GROUP BY
        FORMAT(O.AccountantCreateDate, 'yyyy/MM'),
        FORMAT(O.CreateDate, 'yyyy/MM')
),
TotalEmpresasGratuitas AS
(
    SELECT 
        FORMAT(O.AccountantCreateDate, 'yyyy/MM') AS Cohort,
        FORMAT(O.CreateDate, 'yyyy/MM') AS Month,
		SUM
        (
            CASE WHEN ACS.Gratuities IS NULL
                THEN 0
                ELSE ACS.Gratuities
            END
        ) AS Count
	FROM
        AccountantSubscriptions ACS (NOLOCK)
            INNER JOIN Organizacoes O ON ACS.AccountantId = O.AccountantId
	WHERE
        ACS.DeletedDate is null
    GROUP BY
        FORMAT(O.AccountantCreateDate, 'yyyy/MM'),
        FORMAT(O.CreateDate, 'yyyy/MM')
),
TotalEmpresasCCX AS
(
    SELECT
        FORMAT(AO.AccountantCreateDate, 'yyyy/MM') AS Cohort,
        FORMAT(O.CreateDate, 'yyyy/MM') AS Month,
        COUNT(*) AS Count
    FROM
        Organizacoes AO
            INNER JOIN Organizations O (NOLOCK) ON AO.OrganizationId = O.OrganizationId
            INNER JOIN Configurations C (NOLOCK) ON AO.OrganizationId = C.ReferenceId
    WHERE
        ISNULL(O.NiboDocsEnabled, 0) = 0 AND
        C.[Key] = 'AccountAndStatementEnabled' AND
        C.Value = 'true'
    GROUP BY
        FORMAT(AO.AccountantCreateDate, 'yyyy/MM'),
        FORMAT(O.CreateDate, 'yyyy/MM')
),
TotalEmpresasNiboDocs AS
(
    SELECT
        FORMAT(AO.AccountantCreateDate, 'yyyy/MM') AS Cohort,
        FORMAT(O.NiboDocsDateEnabled, 'yyyy/MM') AS Month,
        COUNT(*) AS Count
    FROM
        Organizacoes AO
            INNER JOIN Organizations O (NOLOCK) ON AO.OrganizationId = O.OrganizationId
            INNER JOIN Configurations C (NOLOCK) ON AO.OrganizationId = C.ReferenceId
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
        FORMAT(AO.AccountantCreateDate, 'yyyy/MM'),
        FORMAT(O.NiboDocsDateEnabled, 'yyyy/MM')
),
TotalEmpresasCobrarContador AS
(
    SELECT
        FORMAT(O.AccountantCreateDate, 'yyyy/MM') AS Cohort,
        FORMAT(O.CreateDate, 'yyyy/MM') AS Month,
        COUNT(*) - 
        (SELECT TECCX.Count FROM TotalEmpresasCCX TECCX WHERE TECCX.Cohort = FORMAT(O.AccountantCreateDate, 'yyyy/MM') AND TECCX.Month = FORMAT(O.CreateDate, 'yyyy/MM')) -
        (SELECT TEND.Count FROM TotalEmpresasNiboDocs TEND WHERE TEND.Cohort = FORMAT(O.AccountantCreateDate, 'yyyy/MM') AND TEND.Month = FORMAT(O.CreateDate, 'yyyy/MM')) AS Count
    FROM
        Organizacoes O
            LEFT JOIN Configurations C (NOLOCK) ON O.OrganizationId = C.ReferenceId
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
        FORMAT(O.AccountantCreateDate, 'yyyy/MM'),
        FORMAT(O.CreateDate, 'yyyy/MM')
),
Cohort AS (
    SELECT
        FORMAT(RangeStartDate, 'yyyy/MM') AS Cohort,
        FORMAT(IntervalStartDate, 'yyyy/MM') AS Month,
        Progress
    FROM
        GetCohortsPeriods('2015-11-01', GETUTCDATE())
        --GetCohortsPeriods((SELECT MIN(CreateDate) FROM ContadoresPagantes), GETUTCDATE())
    WHERE
        FORMAT(RangeStartDate, 'yyyy/MM') = '2015/11'
)
SELECT
    C.Cohort,
    C.Month,
    C.Progress,
    ISNULL(TECC.Count, 0) AS 'Empresas para cobrar o contador',
    ISNULL(TEA.Count, 0) AS 'Empresas assinadas',
    ISNULL(TECeCo.Count, 0) AS 'Empresas na central de cobranças',
    ISNULL(TECCX.Count, 0) AS 'Empresas CCX',
    ISNULL(TEND.Count, 0) AS 'Empresas NiboDocs',
    ISNULL(TECC.Count, 0) + ISNULL(TEA.Count, 0) + ISNULL(TECeCo.Count, 0) + ISNULL(TECCX.Count, 0) + ISNULL(TEND.Count, 0) AS 'Total de empresas'
FROM
    Cohort C
        LEFT JOIN TotalEmpresasCobrarContador TECC ON C.Cohort = TECC.Cohort AND C.Month = TECC.Month
        LEFT JOIN TotalEmpresasAssinadas TEA ON C.Cohort = TEA.Cohort AND C.Month = TEA.Month
        LEFT JOIN TotalEmpresasCentralCobranca TECeCo ON C.Cohort = TECeCo.Cohort AND C.Month = TECeCo.Month
        LEFT JOIN TotalEmpresasCCX TECCX ON C.Cohort = TECCX.Cohort AND C.Month = TECCX.Month
        LEFT JOIN TotalEmpresasNiboDocs TEND ON C.Cohort = TEND.Cohort AND C.Month = TEND.Month