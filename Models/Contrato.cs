using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;

namespace googleSheets.Models
{
    public class Contrato
    {
        public Contrato() {}
        public Contrato(string resumido, string status, string dataEntrada, string escritorio)
        {
            this.Resumido = resumido;
            switch (status.ToUpperInvariant())
            {
                case "DESISTENCIA":
                case "DESISTÊNCIA":
                    this.Status = EnumStatusContrato.Desistencia;
                    break;
                case "CANCELADO":
                    this.Status = EnumStatusContrato.Cancelado;
                    break;
                default:
                    this.Status = EnumStatusContrato.Ativo;
                    break;
            }
            if (!string.IsNullOrWhiteSpace(dataEntrada))
            {
                this.DataEntrada = DateTime.Parse(dataEntrada, CultureInfo.GetCultureInfo("pt-BR"));
            }
            this.Escritorio = escritorio;
            this.Evolucoes = new List<Evolucao>();
        }
        public long? Id { get; set; }
        public string Resumido { get; private set; }
        public EnumStatusContrato Status { get; private set; }
        public DateTime? DataEntrada { get; private set; }
        public string Escritorio { get; private set; }
        public IList<Evolucao> Evolucoes { get; private set; }
    }
}
