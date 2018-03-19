DECLARE
    @cols AS NVARCHAR(MAX),
    @query  AS NVARCHAR(MAX);

SELECT
    FORMAT(C.DataEntrada, 'yyyy/MM', 'pt-BR') as Cohort,
    FORMAT(E.DataReferencia, 'yyyy/MM', 'pt-BR') as Month,
    DATEDIFF(MONTH, C.DataEntrada, E.DataReferencia) AS Progress,
    COUNT(*) AS Count,
    SUM(ISNULL(E.Quantidade, 0)) AS Value
INTO
    #CohortData
FROM
    Contratos C INNER JOIN Evolucoes E ON (C.Id = E.ContratoId AND FORMAT(E.DataReferencia, 'yyyy/MM', 'pt-BR') >= FORMAT(C.DataEntrada, 'yyyy/MM', 'pt-BR'))
WHERE
    C.[Status] = 1
GROUP BY
    FORMAT(C.DataEntrada, 'yyyy/MM', 'pt-BR'),
    FORMAT(E.DataReferencia, 'yyyy/MM', 'pt-BR'),
    DATEDIFF(MONTH, C.DataEntrada, E.DataReferencia)

SELECT @cols = STUFF (
    (
        SELECT
            ',' + QUOTENAME(C.Progress) 
        FROM
            #CohortData C
        GROUP BY
            C.Progress
        ORDER BY
            C.Progress
        FOR XML PATH(''), TYPE
    ).value('.', 'NVARCHAR(MAX)'),
    1,
    1,
    ''
)
SELECT
    @query = 
        N'
        SELECT
            *
        FROM
            (
                SELECT
                    D.Cohort,
                    D.Count,
                    D.Progress,
                    D.Value
                FROM
                    #CohortData D
            ) C
            PIVOT (
                SUM([Value]) FOR Progress IN (
                    ' + @cols + '
                )
            ) PC
        ORDER BY
            Cohort
        '

EXECUTE(@query)

DROP TABLE #CohortData