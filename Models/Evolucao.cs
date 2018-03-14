using System;
using System.Globalization;

namespace googleSheets.Models
{
    public class Evolucao
    {
        public Evolucao() {}
        public Evolucao(Contrato contrato, string mesAno, string quantidade)
        {
            var vetorData = mesAno.Split("/");
            var ano = int.Parse(vetorData[0]);
            var mes = this.ObterMes(vetorData[1]);
            this.DataReferencia = new DateTime(ano, mes, 1, 0, 0, 0, DateTimeKind.Utc);
            int quant;
            this.Quantidade = int.TryParse(quantidade, out quant) ? quant : 0;
        }
        public long? Id { get; set; }
        public long ContratoId { get; set; }
        public Contrato Contrato { get; set; }
        public DateTime DataReferencia { get; private set; }
        public int Quantidade { get; private set; }
        
        
        private int ObterMes(string mes)
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
}
