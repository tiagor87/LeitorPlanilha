using googleSheets.Infrastructure.Maps;
using googleSheets.Models;
using Microsoft.EntityFrameworkCore;

namespace googleSheets.Infrastructure
{
    public class EFDbContext : DbContext {
        public DbSet<Contrato> Contratos { get; set; }
        public DbSet<Evolucao> Evolucoes { get; set; }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder) {
            optionsBuilder.UseSqlServer("data source=localhost,1433;User Id=sa;Password=EntraLogoAiFilhao@12345;Initial Catalog=leituraplanilhadb;");
            //.UseSqlite("Data Source=leitorplanilha.db")
              //  .;
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder) {
            modelBuilder.ApplyConfiguration(new ContratoConfiguration());
            modelBuilder.ApplyConfiguration(new EvolucaoConfiguration());
        }
    }    
}