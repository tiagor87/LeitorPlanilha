
WITH CohortEscritorioCount AS (
    SELECT
        FORMAT(C.DataEntrada, 'MM/yyyy', 'pt-BR') as Data,
        Count(*) AS Count
    FROM
        Contratos C
    WHERE
        C.DataEntrada IS NOT NULL
    GROUP BY
        FORMAT(C.DataEntrada, 'MM/yyyy', 'pt-BR')
)

WITH A AS
(SELECT
    FORMAT(C.DataEntrada, 'yyyy/MM') AS Cohort,
    FORMAT(E.DataReferencia, 'yyyy/MM') AS Month,
    ABS(DATEDIFF(MONTH, C.DataEntrada, E.DataReferencia)) AS Progress,
    E.Quantidade AS Count
FROM
    Contratos C
        JOIN Evolucoes E ON E.ContratoId = C.Id
WHERE
    C.DataEntrada IS NOT NULL)

select
    Cohort,
    Month,
    Progress,
    Sum(Count) as Count
from A
GROUP BY
    Cohort,
    Month,
    Progress


SELECT
    ROUND(DATEDIFF(MONTH, C.DataEntrada, E.DataReferencia)/30.4, 1) AS months,
    FORMAT(E.DataReferencia, 'yyyy/MM') AS MONTH,
    FORMAT(C.DataEntrada, 'yyyy/MM') AS cohort,
    COUNT(DISTINCT C.Id) AS actives
FROM Contratos C
    JOIN Evolucoes E ON E.ContratoId = C.Id
GROUP BY
    FORMAT(C.DataEntrada, 'yyyy/MM'),
    FORMAT(E.DataReferencia, 'yyyy/MM'),
    ROUND(DATEDIFF(MONTH, C.DataEntrada, E.DataReferencia)/30.4, 0)

SELECT
    results.months,
    results.cohort,
    results.actives AS active_users,
    user_totals.total AS total_users,
    results.actives/user_totals.total*100 AS percent_active
FROM
  (
    SELECT
        ROUND(DATEDIFF(MONTH, C.DataEntrada, E.DataReferencia)/30.4, 0) AS months,
        FORMAT(E.DataReferencia, '%Y/%m') AS MONTH,
        FORMAT(C.DataEntrada, '%Y/%m') AS cohort,
        COUNT(DISTINCT C.Id) AS actives
    FROM Contratos C
        JOIN Evolucoes E ON E.ContratoId = C.Id
    GROUP BY
        FORMAT(C.DataEntrada, '%Y/%m'),
        FORMAT(E.DataReferencia, '%Y/%m'),
        ROUND(DATEDIFF(MONTH, C.DataEntrada, E.DataReferencia)/30.4, 0) ) AS results
JOIN
  ( SELECT DATE_FORMAT(date, "%Y/%m") AS cohort,
           count(id) AS total
   FROM users
   GROUP BY cohort ) AS user_totals ON user_totals.cohort = results.cohort
WHERE results.MONTH < DATE_FORMAT(NOW(), '%Y/%m');


SELECT
    C.Escritorio,
    E.Ano,
    E.Mes,
    SUM(E.Quantidade)
FROM
    Contratos C
        INNER JOIN Evolucoes E ON C.Id = E.ContratoId
GROUP BY
    C.Escritorio,
    E.Ano,
    E.Mes
    