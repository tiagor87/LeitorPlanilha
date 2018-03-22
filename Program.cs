using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using Google.Apis.Auth.OAuth2;
using Google.Apis.Services;
using Google.Apis.Sheets.v4;
using Google.Apis.Sheets.v4.Data;
using Google.Apis.Util.Store;
using googleSheets.Infrastructure;
using googleSheets.Models;
using Microsoft.EntityFrameworkCore;
using static Google.Apis.Sheets.v4.SpreadsheetsResource.ValuesResource.GetRequest;

namespace googleSheets
{
    class Program
    {
        static string[] Scopes = { SheetsService.Scope.SpreadsheetsReadonly };
        static string ApplicationName = "NiboPlayground";

        static void Main(string[] args)
        {
            var planilha = ObterPlanilha();
            var dadosAgrupadosPorColuna = ExtrairDadosDaPlanilhaAgrupadosPorColuna(planilha);
            var contratos = CriarContratosAPartirDosDadosExtraidos(dadosAgrupadosPorColuna);

            GravarContratos(contratos);
        }

        private static IList<Contrato> ObterContratos()
        {
            using (var contexto = new EFDbContext())
            {
                return contexto.Contratos.Include(c => c.Evolucoes).ToList();
            }
        }

        private static void GravarContratos(IList<Contrato> contratos)
        {
            using (var contexto = new EFDbContext())
            {
                contexto.Contratos.AddRange(contratos);
                contexto.SaveChanges();
            }
        }

        private static ValueRange ObterPlanilha()
        {
            var credential = GoogleCredential.FromFile("credential.json")
                .CreateScoped(Scopes)
                .CreateWithUser("niboplayground@niboplayground.iam.gserviceaccount.com");

            var service = new SheetsService(new BaseClientService.Initializer()
            {
                HttpClientInitializer = credential,
                ApplicationName = ApplicationName,
                ApiKey = "AIzaSyBxIm7pJoMISavNfbAvYNclX6Mn6Esh0hI"
            });

            String spreadsheetId = "1UMHhZiMOkBrOO8Vw0ash7JFay2_rbOhLATvdwXtijL4";
            String range = "Evolução de empresas contratadas CCX";
            SpreadsheetsResource.ValuesResource.GetRequest request = service.Spreadsheets.Values.Get(spreadsheetId, range);
            request.MajorDimension = MajorDimensionEnum.COLUMNS;

            ValueRange response = request.Execute();
            return response;
        }

        private static IList<Contrato> CriarContratosAPartirDosDadosExtraidos(IDictionary<string, IList<string>> dadosAgrupadosPorColuna)
        {
            var valores = dadosAgrupadosPorColuna["Resumido"];
            var contratos = new List<Contrato>(valores.Count);
            for (int i = 0; i < valores.Count; i++)
            {
                var contrato = new Contrato(dadosAgrupadosPorColuna["Resumido"][i], dadosAgrupadosPorColuna["Status"][i], dadosAgrupadosPorColuna["Data"][i], dadosAgrupadosPorColuna["Escritório"][i]);
                for (int j = 4; j < dadosAgrupadosPorColuna.Keys.Count; j++)
                {
                    var mesAno = dadosAgrupadosPorColuna.Keys.ElementAt(j);
                    var coluna = dadosAgrupadosPorColuna[mesAno];
                    if (coluna.Count > i)
                    {
                        contrato.Evolucoes.Add(new Evolucao(contrato, mesAno, coluna[i]));
                    }
                    else
                    {
                        continue;
                    }
                }
                contratos.Add(contrato);
            }
            return contratos;
        }

        private static IDictionary<string, IList<string>> ExtrairDadosDaPlanilhaAgrupadosPorColuna(ValueRange response)
        {
            IDictionary<string, IList<string>> table = new Dictionary<string, IList<string>>();
            var colunas = response.Values;
            if (colunas != null && colunas.Count > 0)
            {
                string ano = string.Empty;
                foreach (var valoresColuna in colunas)
                {
                    var lista = new List<string>();
                    string chave;
                    if (string.IsNullOrWhiteSpace(valoresColuna[0] as string))
                    {
                        chave = $"{ano}/{valoresColuna[1]}";
                    }
                    else if (Regex.IsMatch(valoresColuna[0] as string, @"\d{4}"))
                    {
                        ano = valoresColuna[0] as string;
                        chave = $"{ano}/{valoresColuna[1]}";
                    }
                    else
                    {
                        chave = valoresColuna[0] as string;
                    }
                    for (var i = 4; i < valoresColuna.Count; i++)
                    {
                        lista.Add(valoresColuna[i] as string);
                    }
                    table.Add(chave, lista);
                }
            }
            return table;
        }
    }
}
