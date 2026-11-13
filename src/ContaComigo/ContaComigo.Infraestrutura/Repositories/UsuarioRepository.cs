using System.Data;
using ContaComigo.Application.DTOs.Usuario;
using ContaComigo.Application.Repositories;
using Dapper;

namespace ContaComigo.Infraestrutura.Repositories;

public class UsuarioRepository : IUsuarioRepository
{
    private readonly IDbConnection _connection;

    public UsuarioRepository(IDbConnection connection)
    {
        _connection = connection;
    }

    public async Task<IEnumerable<UsuarioResponse>> BuscarUsuariosAsync()
    {
        var sql = @"SELECT ID, 
                           Nome, 
                           Email,
                           SN_Email_Verificado,
                           Telefone,
                           SN_Telefone_Verificado,
                           SN_Acesso_Bloqueado,
                           Foto_url,
                           Data_Cadastro,
                           Data_Alteracao,
                           Data_Expiracao
                    FROM dbo.USUARIOS
                    WHERE SN_Ativo = 'S';";

        return await _connection.QueryAsync<UsuarioResponse>(sql);
    }

    public async Task<bool> AtualizarUsuarioAsync(int id, AtualizarUsuarioRequest usuario)
    {
        var sql = @"UPDATE dbo.USUARIOS
                    SET Nome           = @Nome,
                        Email          = @Email,
                        Telefone       = @Telefone,
                        Foto_url       = @Foto_url,
                        Data_Alteracao = GETDATE()
                    WHERE ID = @ID;";

        var linhasAfetadas = await _connection.ExecuteAsync(sql, new
        {
            Nome = usuario.Nome.Trim(),
            Email = usuario.Email.Trim(),
            usuario.Telefone,
            usuario.Foto_url,
            ID = id
        });

        return linhasAfetadas > 0;
    }    

    public async Task<UsuarioResponse?> BuscarUsuarioPorEmailAsync(string email)
    {
        var sql = @"SELECT ID, 
                           Nome, 
                           Email,
                           SN_Email_Verificado,
                           Telefone,
                           SN_Telefone_Verificado,
                           SN_Acesso_Bloqueado,
                           Foto_url,
                           Data_Cadastro,
                           Data_Alteracao,
                           Data_Expiracao
                    FROM dbo.USUARIOS
                    WHERE Email = @Email
                      AND SN_Ativo = 'S';";

        return await _connection.QuerySingleOrDefaultAsync<UsuarioResponse>(sql, new { Email = email });
    }

    public async Task<UsuarioResponse?> BuscarUsuarioPorIdAsync(int id)
    {
        var sql = @"SELECT ID, 
                           Nome, 
                           Email,
                           SN_Email_Verificado,
                           Telefone,
                           SN_Telefone_Verificado,
                           SN_Acesso_Bloqueado,
                           Foto_url,
                           Data_Cadastro,
                           Data_Alteracao,
                           Data_Expiracao
                    FROM dbo.USUARIOS
                    WHERE ID = @ID
                      AND SN_Ativo = 'S';";

        return await _connection.QuerySingleOrDefaultAsync<UsuarioResponse>(sql, new { ID = id });
    }  

    public async Task<int> CadastrarUsuarioAsync(CriarUsuarioRequest usuario, string senhaHash)
    {
        const string sql = @"INSERT INTO dbo.USUARIOS (Nome, 
                                                       Email, 
                                                       Senha_Acesso, 
                                                       Telefone, 
                                                       Foto_url)
                             OUTPUT INSERTED.ID
            
                             VALUES (@Nome, 
                                     @Email, 
                                     @SenhaHash, 
                                     @Telefone, 
                                     @Foto_url);";

        return await _connection.QuerySingleAsync<int>(sql, new
        {
            Nome      = usuario.Nome.Trim(),
            Email     = usuario.Email.Trim(),
            SenhaHash = senhaHash,
            Telefone  = usuario.Telefone.Trim(),
            Foto_url  = usuario.Foto_url.Trim()
        });
    }

    public async Task<bool> RemoverUsuarioAsync(int id)
    {
        const string sql = @"DELETE FROM dbo.USUARIOS WHERE ID = @ID;";

        var linhasAfetadas = await _connection.ExecuteAsync(sql, new { ID = id });

        return linhasAfetadas > 0;
    }
}