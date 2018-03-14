﻿// <auto-generated />
using googleSheets.Infrastructure;
using googleSheets.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.EntityFrameworkCore.Storage.Internal;
using System;

namespace googleSheets.Migrations
{
    [DbContext(typeof(EFDbContext))]
    partial class EFDbContextModelSnapshot : ModelSnapshot
    {
        protected override void BuildModel(ModelBuilder modelBuilder)
        {
#pragma warning disable 612, 618
            modelBuilder
                .HasAnnotation("ProductVersion", "2.0.2-rtm-10011")
                .HasAnnotation("SqlServer:ValueGenerationStrategy", SqlServerValueGenerationStrategy.IdentityColumn);

            modelBuilder.Entity("googleSheets.Models.Contrato", b =>
                {
                    b.Property<long?>("Id")
                        .ValueGeneratedOnAdd();

                    b.Property<DateTime?>("DataEntrada");

                    b.Property<string>("Escritorio");

                    b.Property<string>("Resumido");

                    b.Property<int>("Status");

                    b.HasKey("Id");

                    b.ToTable("Contratos");
                });

            modelBuilder.Entity("googleSheets.Models.Evolucao", b =>
                {
                    b.Property<long?>("Id")
                        .ValueGeneratedOnAdd();

                    b.Property<long>("ContratoId");

                    b.Property<DateTime>("DataReferencia");

                    b.Property<int>("Quantidade");

                    b.HasKey("Id");

                    b.HasIndex("ContratoId");

                    b.ToTable("Evolucoes");
                });

            modelBuilder.Entity("googleSheets.Models.Evolucao", b =>
                {
                    b.HasOne("googleSheets.Models.Contrato", "Contrato")
                        .WithMany("Evolucoes")
                        .HasForeignKey("ContratoId")
                        .OnDelete(DeleteBehavior.Cascade);
                });
#pragma warning restore 612, 618
        }
    }
}
