using System.Data;
using ContaComigo.Application.Repositories;
using ContaComigo.Infraestrutura.Repositories;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException(
        "Configure a connection string 'DefaultConnection' before starting the application.");
}

builder.Services.AddScoped<IDbConnection>(_ => new SqlConnection(connectionString));
builder.Services.AddScoped<IUsuarioRepository, UsuarioRepository>();
builder.Services.AddScoped<IPasswordHasher<object>, PasswordHasher<object>>();

// Add services to the container.

builder.Services.AddControllers();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
