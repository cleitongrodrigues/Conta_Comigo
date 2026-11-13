using System.ComponentModel.DataAnnotations;

namespace ContaComigo.Application.DTOs.Usuario;

public class AtualizarUsuarioRequest
{
    [Required, StringLength(100, MinimumLength = 2)]
    public string Nome { get; set; } = string.Empty;

    [Required, EmailAddress, StringLength(254)]
    public string Email { get; set; } = string.Empty;

    [Required, StringLength(128, MinimumLength = 8)]
    public string? Senha { get; set; }

    [StringLength(11)]
    public string? Telefone { get; set; }

    [Required, StringLength(1)]
    public string? SN_Ativo { get; set; }

    [Url, StringLength(2048)]
    public string? Foto_url { get; set; }
}