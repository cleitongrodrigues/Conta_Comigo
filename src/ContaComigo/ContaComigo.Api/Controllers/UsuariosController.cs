using ContaComigo.Application.DTOs.Usuario;
using ContaComigo.Application.Repositories;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace ContaComigo.Api.Controllers;

[ApiController]
[Route("api/usuarios")]
public class UsuariosController : ControllerBase
{
    private readonly IUsuarioRepository _usuarios;
    private readonly IPasswordHasher<object> _passwordHasher;

    public UsuariosController(
        IUsuarioRepository usuarios,
        IPasswordHasher<object> passwordHasher)
    {
        _usuarios = usuarios;
        _passwordHasher = passwordHasher;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<UsuarioResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<UsuarioResponse>>> BuscarTodos()
    {
        return Ok(await _usuarios.BuscarUsuariosAsync());
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(UsuarioResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UsuarioResponse>> BuscarPorId(int id)
    {
        var usuario = await _usuarios.BuscarUsuarioPorIdAsync(id);
        return usuario is null ? NotFound() : Ok(usuario);
    }

    [HttpGet("email/{email}")]
    [ProducesResponseType(typeof(UsuarioResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UsuarioResponse>> BuscarPorEmail(string email)
    {
        var usuario = await _usuarios.BuscarUsuarioPorEmailAsync(email);
        return usuario is null ? NotFound() : Ok(usuario);

    }

    [HttpPost]
    [ProducesResponseType(typeof(UsuarioResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<UsuarioResponse>> Criar(CriarUsuarioRequest request)
    {
        var email = request.Email.Trim();
        if (await _usuarios.BuscarUsuarioPorEmailAsync(email) is not null)
        {
            return Conflict(new { mensagem = "Já existe um usuário com este e-mail." });
        }

        var senhaHash = _passwordHasher.HashPassword(new object(), request.Senha);

        int id;
        try
        {
            id = await _usuarios.CadastrarUsuarioAsync(request, senhaHash);
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            return Conflict(new { mensagem = "Já existe um usuário com este e-mail." });
        }

        var usuario = await _usuarios.BuscarUsuarioPorIdAsync(id);

        if (usuario is null)
        {
            throw new InvalidOperationException("O usuário foi criado, mas não pôde ser recuperado.");
        }

        return CreatedAtAction(nameof(BuscarPorId), new { id }, usuario);
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Atualizar(int id, AtualizarUsuarioRequest request)
    {
        if (await _usuarios.BuscarUsuarioPorIdAsync(id) is null)
        {
            return NotFound();
        }

        var email = request.Email.Trim();
        var usuarioComEmail = await _usuarios.BuscarUsuarioPorEmailAsync(email);
        if (usuarioComEmail is not null && usuarioComEmail.ID != id)
        {
            return Conflict(new { mensagem = "Já existe um usuário com este e-mail." });
        }

        try
        {
            var atualizado = await _usuarios.AtualizarUsuarioAsync(id, request);
            return atualizado ? NoContent() : NotFound();
        }
        catch (SqlException exception) when (exception.Number is 2601 or 2627)
        {
            return Conflict(new { mensagem = "Já existe um usuário com este e-mail." });
        }
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Remover(int id)
    {
        var removido = await _usuarios.RemoverUsuarioAsync(id);
        return removido ? NoContent() : NotFound();
    }
}
