namespace ContaComigo.Application.DTOs.Usuario;

public class UsuarioResponse
{
    public int ID { get; set; }
    public string? Nome { get; set; }
    public string? Email { get; set; }
    public string? SN_Email_Verificado { get; set; }
    public string? Telefone { get; set; }
    public string? SN_Telefone_Verificado { get; set; }
    public string? SN_Acesso_Bloqueado { get; set; }
    public string? Foto_url { get; set; }
    public DateTime Data_Cadastro { get; set; }
    public DateTime Data_Alteracao { get; set; }
    public DateTime Data_Expiracao { get; set; }
}