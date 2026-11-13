using ContaComigo.Application.DTOs.Usuario;

namespace ContaComigo.Application.Repositories;

public interface IUsuarioRepository
{
    Task<IEnumerable<UsuarioResponse>> BuscarUsuariosAsync();
    Task<UsuarioResponse?> BuscarUsuarioPorIdAsync(int id);
    Task<UsuarioResponse?> BuscarUsuarioPorEmailAsync(string email);
    Task<int> CadastrarUsuarioAsync(CriarUsuarioRequest usuario, string senhaHash);
    Task<bool> AtualizarUsuarioAsync(int id, AtualizarUsuarioRequest usuario);
    Task<bool> RemoverUsuarioAsync(int id);
}
