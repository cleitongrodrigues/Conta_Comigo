using System.ComponentModel.DataAnnotations;

namespace ContaComigo.Application.DTOs.Usuario;

public class CriarUsuarioRequest
{
    [Required, StringLength(100, MinimumLength = 3)]
    public string? Nome { get; set; }

    [Required, EmailAddress, StringLength(254)]
    public string? Email { get; set; }

    [Required, StringLength(128, MinimumLength = 8)]
    public string? Senha { get; set; }

    [StringLength(11)]
    public string? Telefone { get; set; }

    [Url, StringLength(2048)]
    public string? Foto_url { get; set; }
    public DateTime Data_Cadastro { get; set; } = DateTime.UtcNow;
}