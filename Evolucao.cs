using System;

namespace googleSheets
{
    public class Evolucao
    {
        private readonly string mes;
        public Evolucao(string mesAno, string quantidade)
        {
            var vetorData = mesAno.Split("/");
            this.Ano = int.Parse(vetorData[0]);
            this.mes = vetorData[1];
            int quant;
            this.Quantidade = int.TryParse(quantidade, out quant) ? quant : 0;
        }
        public int Ano { get; private set; }
        public int Mes
        {
            get
            {
                switch (mes.ToUpper())
                {
                    case "JAN": return 1;
                    case "FEV": return 2;
                    case "MAR": return 3;
                    case "ABR": return 4;
                    case "MAI": return 5;
                    case "JUN": return 6;
                    case "JUL": return 7;
                    case "AGO": return 8;
                    case "SET": return 9;
                    case "OUT": return 10;
                    case "NOV": return 11;
                    case "DEZ": return 12;
                    default: throw new Exception("Mês inválido");
                }
            }
        }
        public DateTime DataInicial
        {
            get
            {
                return new DateTime(this.Ano, this.Mes, 1, 0, 0, 0, DateTimeKind.Utc);
            }
        }
        public DateTime DataFinal
        {
            get
            {
                return this.DataInicial.AddMonths(1);
            }
        }
        public int Quantidade { get; private set; }
    }
}
