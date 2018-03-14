using googleSheets.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace googleSheets.Infrastructure.Maps
{
    public class EvolucaoConfiguration : IEntityTypeConfiguration<Evolucao>
    {
        public void Configure(EntityTypeBuilder<Evolucao> builder)
        {
            builder.HasKey(e => e.Id);
        }
    }
}