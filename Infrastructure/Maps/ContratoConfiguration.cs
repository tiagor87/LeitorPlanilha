using googleSheets.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace googleSheets.Infrastructure.Maps
{
    public class ContratoConfiguration : IEntityTypeConfiguration<Contrato>
    {
        public void Configure(EntityTypeBuilder<Contrato> builder)
        {
            builder.HasKey(c => c.Id);
            builder.HasMany(c => c.Evolucoes)
                .WithOne(e => e.Contrato)
                .HasForeignKey(e => e.ContratoId);
                
        }
    }
}