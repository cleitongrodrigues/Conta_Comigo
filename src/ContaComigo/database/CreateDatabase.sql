IF DB_ID(N'ContaComigo') IS NULL
BEGIN
	CREATE DATABASE [ContaComigo];
END;
GO

USE [ContaComigo];
GO

IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
BEGIN
	CREATE TABLE [dbo].[Usuarios]
	(
		[ID] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_Usuarios] PRIMARY KEY,
		[Nome] NVARCHAR(120) NOT NULL,
		[Email] NVARCHAR(254) NOT NULL,
		[Senha_Acesso] NVARCHAR(500) NOT NULL,
		[Telefone] NVARCHAR(20) NULL,
		[Foto_url] NVARCHAR(2048) NULL,
		[SN_Email_Verificado] CHAR(1) NOT NULL CONSTRAINT [DF_Usuarios_EmailVerificado] DEFAULT ('N'),
		[SN_Telefone_Verificado] CHAR(1) NOT NULL CONSTRAINT [DF_Usuarios_TelefoneVerificado] DEFAULT ('N'),
		[SN_Ativo] CHAR(1) NOT NULL CONSTRAINT [DF_Usuarios_Ativo] DEFAULT ('S'),
		[SN_Acesso_Bloqueado] CHAR(1) NOT NULL CONSTRAINT [DF_Usuarios_AcessoBloqueado] DEFAULT ('N'),
		[Tentativas_login_falhas] INT NOT NULL CONSTRAINT [DF_Usuarios_TentativasLogin] DEFAULT (0),
		[Bloqueado_ate] DATETIME2 NULL,
		[Ultimo_acesso_em] DATETIME2 NULL,
		[Data_Alteracao] DATETIME2 NOT NULL CONSTRAINT [DF_Usuarios_DataAlteracao] DEFAULT (SYSUTCDATETIME()),
		[Data_Ultimo_Acesso] DATETIME2 NULL,
		[Data_Expiracao] DATETIME2 NULL,
		[Data_Cadastro] DATETIME2 NOT NULL CONSTRAINT [DF_Usuarios_DataCadastro] DEFAULT (SYSUTCDATETIME()),
		CONSTRAINT [UQ_Usuarios_Email] UNIQUE ([Email])
	);
END;
GO
