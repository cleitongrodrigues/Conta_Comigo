-- =============================================================================
-- PROJETO: CONTA COMIGO (v3)
-- SISTEMA DE GESTÃO FINANCEIRA COLABORATIVA - SAAS
-- SGBD: Microsoft SQL Server 2022+ (T-SQL para Docker / Dapper / .NET)
--
-- PADRÃO:
--   Tabelas ........ MAIUSCULAS_COM_UNDERLINE
--   Colunas ........ Pascal_Case_Com_Underline | PK: ID | FK: ID_<Entidade>
--   Flags .......... SN_<Nome> Char(1) 'S'/'N'
--   Datas .......... Data_<Nome> Datetime (no Docker o relógio do SQL Server é UTC)
--   Constraints .... PK inline | FK_ | CK_ | UK_ | Índices: IDX_
--   Exclusão ....... lógica (Data_Exclusao / SN_Ativo). FKs NO ACTION, exceto
--                    filhos puros (preferências, identidades, tokens, config. da sala)
-- Executar com GO funcionando (SSMS / sqlcmd). Testar antes em banco de dev.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- =============================================================================
-- 1. TABELA: USUARIOS
-- =============================================================================
IF OBJECT_ID('dbo.USUARIOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.USUARIOS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        Nome                    Varchar(100)  NOT NULL,
        Email                   Varchar(255)  NOT NULL,
        SN_Email_Verificado     Char(1)       NOT NULL DEFAULT 'N',
        Senha_Acesso            Varchar(255)  NULL,                       -- NULL = conta que entra só pelo Google
        Telefone                Varchar(11)   NOT NULL,
        SN_Telefone_Verificado  Char(1)       NOT NULL DEFAULT 'N',
        Foto_url                Varchar(2048) NULL,
        SN_Ativo                Char(1)       NOT NULL DEFAULT 'S',
        SN_Acesso_Bloqueado     Char(1)       NOT NULL DEFAULT 'N',
        Tentativas_login_falhas Integer       NOT NULL DEFAULT 0,
        Bloqueado_ate           Datetime,
        Ultimo_acesso_em        Datetime,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        CONSTRAINT UK_USUARIOS_Email UNIQUE (Email),
        CONSTRAINT CK_USUARIOS_SN_Email_Verificado    CHECK (SN_Email_Verificado IN ('S', 'N')),
        CONSTRAINT CK_USUARIOS_SN_Telefone_Verificado CHECK (SN_Telefone_Verificado IN ('S', 'N')),
        CONSTRAINT CK_USUARIOS_SN_Ativo               CHECK (SN_Ativo IN ('S', 'N')),             -- S = Ativo / N = Inativo
        CONSTRAINT CK_USUARIOS_SN_Acesso_Bloqueado    CHECK (SN_Acesso_Bloqueado IN ('S', 'N')),
        CONSTRAINT CK_USUARIOS_Tentativas_login_falhas CHECK (Tentativas_login_falhas >= 0)
    );
END;
GO

-- =============================================================================
-- 2. TABELA: USUARIO_IDENTIDADES (LOGIN COM GOOGLE E OUTROS PROVEDORES)
-- =============================================================================
IF OBJECT_ID('dbo.USUARIO_IDENTIDADES', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.USUARIO_IDENTIDADES (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Usuario              Integer       NOT NULL,
        Provedor                Varchar(20)   NOT NULL,
        ID_Externo              Varchar(255)  NOT NULL,                   -- "sub" do Google (nunca usar o e-mail para identificar)
        Email_Provedor          Varchar(255)  NULL,
        SN_Email_Verificado     Char(1)       NOT NULL DEFAULT 'N',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Ultimo_login_em         Datetime,
        CONSTRAINT FK_USUARIO_IDENTIDADES_USUARIOS FOREIGN KEY (ID_Usuario) REFERENCES dbo.USUARIOS(ID) ON DELETE CASCADE,
        CONSTRAINT CK_USUARIO_IDENTIDADES_Provedor CHECK (Provedor IN ('GOOGLE', 'APPLE', 'MICROSOFT')),
        CONSTRAINT CK_USUARIO_IDENTIDADES_SN_Email_Verificado CHECK (SN_Email_Verificado IN ('S', 'N')),
        CONSTRAINT UK_USUARIO_IDENTIDADES_Provedor_ID_Externo UNIQUE (Provedor, ID_Externo)
    );

    CREATE NONCLUSTERED INDEX IDX_USUARIO_IDENTIDADES_ID_Usuario ON dbo.USUARIO_IDENTIDADES(ID_Usuario);
END;
GO

-- =============================================================================
-- 3. TABELA: USUARIO_TOKENS (VERIFICAÇÃO DE E-MAIL, REDEFINIÇÃO DE SENHA, SESSÃO)
-- =============================================================================
IF OBJECT_ID('dbo.USUARIO_TOKENS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.USUARIO_TOKENS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Usuario              Integer       NOT NULL,
        Tipo                    Varchar(25)   NOT NULL,
        Token_Hash              Varchar(128)  NOT NULL,                   -- guardar SOMENTE o hash, nunca o token
        IP                      Varchar(45)   NULL,
        User_Agent              Varchar(255)  NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Expiracao          Datetime      NOT NULL,
        Data_Uso                Datetime,                                 -- preenchida quando o token de uso único é consumido
        Data_Revogacao          Datetime,                                 -- sessão derrubada
        CONSTRAINT FK_USUARIO_TOKENS_USUARIOS FOREIGN KEY (ID_Usuario) REFERENCES dbo.USUARIOS(ID) ON DELETE CASCADE,
        CONSTRAINT CK_USUARIO_TOKENS_Tipo CHECK (Tipo IN ('VERIFICACAO_EMAIL', 'REDEFINICAO_SENHA', 'REFRESH')),
        CONSTRAINT UK_USUARIO_TOKENS_Token_Hash UNIQUE (Token_Hash)
    );

    CREATE NONCLUSTERED INDEX IDX_USUARIO_TOKENS_ID_Usuario ON dbo.USUARIO_TOKENS(ID_Usuario, Tipo);
END;
GO

-- =============================================================================
-- 4. TABELA: PREFERENCIAS_NOTIFICACAO_USUARIO
-- =============================================================================
IF OBJECT_ID('dbo.PREFERENCIAS_NOTIFICACAO_USUARIO', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PREFERENCIAS_NOTIFICACAO_USUARIO (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Usuario              Integer       NOT NULL,
        SN_Receber_Email        Char(1)       NOT NULL DEFAULT 'S',
        SN_Receber_Whatsapp     Char(1)       NOT NULL DEFAULT 'S',
        SN_Silenciar_Tudo       Char(1)       NOT NULL DEFAULT 'N',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        CONSTRAINT FK_PREFERENCIAS_NOTIFICACAO_USUARIO_USUARIOS FOREIGN KEY (ID_Usuario) REFERENCES dbo.USUARIOS(ID) ON DELETE CASCADE,
        CONSTRAINT UK_PREFERENCIAS_NOTIFICACAO_USUARIO_ID_Usuario UNIQUE (ID_Usuario),
        CONSTRAINT CK_PREFERENCIAS_NOTIFICACAO_USUARIO_SN_Receber_Email    CHECK (SN_Receber_Email IN ('S', 'N')),
        CONSTRAINT CK_PREFERENCIAS_NOTIFICACAO_USUARIO_SN_Receber_Whatsapp CHECK (SN_Receber_Whatsapp IN ('S', 'N')),
        CONSTRAINT CK_PREFERENCIAS_NOTIFICACAO_USUARIO_SN_Silenciar_Tudo   CHECK (SN_Silenciar_Tudo IN ('S', 'N'))
    );
END;
GO

-- =============================================================================
-- 5. TABELA: CONSENTIMENTOS_USUARIO (LGPD: TERMOS, PRIVACIDADE, WHATSAPP)
-- =============================================================================
IF OBJECT_ID('dbo.CONSENTIMENTOS_USUARIO', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CONSENTIMENTOS_USUARIO (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Usuario              Integer       NOT NULL,
        Tipo                    Varchar(30)   NOT NULL,
        Versao                  Varchar(20)   NOT NULL,                   -- versão do documento aceito
        SN_Aceito               Char(1)       NOT NULL,                   -- permite registrar também a revogação
        IP                      Varchar(45)   NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_CONSENTIMENTOS_USUARIO_USUARIOS FOREIGN KEY (ID_Usuario) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_CONSENTIMENTOS_USUARIO_Tipo CHECK (Tipo IN ('TERMOS_USO', 'POLITICA_PRIVACIDADE', 'WHATSAPP')),
        CONSTRAINT CK_CONSENTIMENTOS_USUARIO_SN_Aceito CHECK (SN_Aceito IN ('S', 'N'))
    );

    CREATE NONCLUSTERED INDEX IDX_CONSENTIMENTOS_USUARIO_ID_Usuario ON dbo.CONSENTIMENTOS_USUARIO(ID_Usuario, Tipo, Data_Cadastro);
END;
GO

-- =============================================================================
-- 6. TABELA: PLANOS (LIMITES E RECURSOS DE CADA PLANO)
-- =============================================================================
IF OBJECT_ID('dbo.PLANOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PLANOS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        Codigo                  Varchar(30)   NOT NULL,
        Nome                    Varchar(80)   NOT NULL,
        Descricao               Varchar(255)  NULL,
        Qtd_Max_Salas           Integer       NULL,                       -- salas que o usuário pode CRIAR. NULL = ilimitado
        Qtd_Max_Membros_Sala    Integer       NULL,                       -- NULL = ilimitado
        SN_Permite_Convidar     Char(1)       NOT NULL DEFAULT 'N',
        SN_Permite_Caixinhas    Char(1)       NOT NULL DEFAULT 'N',
        SN_Permite_Whatsapp     Char(1)       NOT NULL DEFAULT 'N',
        Qtd_Max_Whatsapp_Mes    Integer       NULL,                       -- NULL = ilimitado
        Valor_Mensal            Decimal(15, 2) NULL,
        Valor_Anual             Decimal(15, 2) NULL,
        SN_Ativo                Char(1)       NOT NULL DEFAULT 'S',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        CONSTRAINT UK_PLANOS_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_PLANOS_SN_Permite_Convidar  CHECK (SN_Permite_Convidar IN ('S', 'N')),
        CONSTRAINT CK_PLANOS_SN_Permite_Caixinhas CHECK (SN_Permite_Caixinhas IN ('S', 'N')),
        CONSTRAINT CK_PLANOS_SN_Permite_Whatsapp  CHECK (SN_Permite_Whatsapp IN ('S', 'N')),
        CONSTRAINT CK_PLANOS_SN_Ativo             CHECK (SN_Ativo IN ('S', 'N')),
        CONSTRAINT CK_PLANOS_Limites CHECK (
                                            (Qtd_Max_Salas IS NULL OR Qtd_Max_Salas >= 0) AND
                                            (Qtd_Max_Membros_Sala IS NULL OR Qtd_Max_Membros_Sala >= 1) AND
                                            (Qtd_Max_Whatsapp_Mes IS NULL OR Qtd_Max_Whatsapp_Mes >= 0)
                                            )
    );
END;
GO

-- Carga inicial dos planos (limites do Premium ainda em aberto: NULL = ilimitado)
IF NOT EXISTS (SELECT 1 FROM dbo.PLANOS WHERE Codigo = 'GRATUITO')
BEGIN
    INSERT INTO dbo.PLANOS (Codigo, Nome, Descricao, Qtd_Max_Salas, Qtd_Max_Membros_Sala, SN_Permite_Convidar, SN_Permite_Caixinhas, SN_Permite_Whatsapp, Qtd_Max_Whatsapp_Mes)
    VALUES ('GRATUITO', 'Gratuito', 'Até 3 salas pessoais', 3, 1, 'N', 'N', 'N', 0);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.PLANOS WHERE Codigo = 'PREMIUM')
BEGIN
    INSERT INTO dbo.PLANOS (Codigo, Nome, Descricao, Qtd_Max_Salas, Qtd_Max_Membros_Sala, SN_Permite_Convidar, SN_Permite_Caixinhas, SN_Permite_Whatsapp, Qtd_Max_Whatsapp_Mes)
    VALUES ('PREMIUM', 'Premium', 'Convidar membros, caixinhas, cobranças e lembretes por WhatsApp', NULL, NULL, 'S', 'S', 'S', NULL);
END;
GO

-- =============================================================================
-- 7. TABELA: ASSINATURAS (QUEM PAGA É O DONO DA SALA)
-- =============================================================================
IF OBJECT_ID('dbo.ASSINATURAS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ASSINATURAS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Usuario              Integer       NOT NULL,                   -- titular da assinatura
        ID_Plano                Integer       NOT NULL,
        Origem                  Varchar(15)   NOT NULL,
        Periodicidade           Varchar(10)   NOT NULL,
        Status                  Varchar(15)   NOT NULL DEFAULT 'ATIVA',
        Data_Inicio             Datetime      NOT NULL,
        Data_Fim                Datetime      NOT NULL,                   -- substitui a antiga Data_Expiracao do usuário
        ID_Usuario_Concedeu     Integer       NULL,                       -- preenchido nas cortesias
        Motivo                  Varchar(255)  NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        CONSTRAINT FK_ASSINATURAS_USUARIOS         FOREIGN KEY (ID_Usuario)          REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT FK_ASSINATURAS_PLANOS           FOREIGN KEY (ID_Plano)            REFERENCES dbo.PLANOS(ID),
        CONSTRAINT FK_ASSINATURAS_USUARIOS_Concedeu FOREIGN KEY (ID_Usuario_Concedeu) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_ASSINATURAS_Origem        CHECK (Origem IN ('PAGAMENTO', 'CORTESIA', 'TESTE')),
        CONSTRAINT CK_ASSINATURAS_Periodicidade CHECK (Periodicidade IN ('MENSAL', 'ANUAL')),
        CONSTRAINT CK_ASSINATURAS_Status        CHECK (Status IN ('ATIVA', 'CANCELADA', 'EXPIRADA')),
        CONSTRAINT CK_ASSINATURAS_Datas         CHECK (Data_Fim > Data_Inicio)
    );

    CREATE NONCLUSTERED INDEX IDX_ASSINATURAS_Vigencia ON dbo.ASSINATURAS(ID_Usuario, Status, Data_Fim);
END;
GO

-- =============================================================================
-- 8. TABELA: ASSINATURA_EVENTOS (HISTÓRICO DA ASSINATURA)
-- =============================================================================
IF OBJECT_ID('dbo.ASSINATURA_EVENTOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ASSINATURA_EVENTOS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Assinatura           Integer       NOT NULL,
        ID_Usuario              Integer       NULL,                       -- quem executou (NULL = sistema)
        Evento                  Varchar(20)   NOT NULL,
        Detalhes_Json           Varchar(MAX)  NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_ASSINATURA_EVENTOS_ASSINATURAS FOREIGN KEY (ID_Assinatura) REFERENCES dbo.ASSINATURAS(ID),
        CONSTRAINT FK_ASSINATURA_EVENTOS_USUARIOS    FOREIGN KEY (ID_Usuario)    REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_ASSINATURA_EVENTOS_Evento CHECK (Evento IN ('CRIADA', 'RENOVADA', 'CANCELADA', 'EXPIRADA', 'ALTERADA')),
        CONSTRAINT CK_ASSINATURA_EVENTOS_Detalhes_Json CHECK (Detalhes_Json IS NULL OR ISJSON(Detalhes_Json) = 1)
    );

    CREATE NONCLUSTERED INDEX IDX_ASSINATURA_EVENTOS_ID_Assinatura ON dbo.ASSINATURA_EVENTOS(ID_Assinatura, Data_Cadastro);
END;
GO

-- =============================================================================
-- 9. TABELA: SALAS (WORKSPACES FINANCEIROS)
-- =============================================================================
IF OBJECT_ID('dbo.SALAS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.SALAS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        Nome                    Varchar(100)  NOT NULL,
        Descricao               Varchar(255)  NULL,
        ID_Usuario_Dono         Integer       NOT NULL,                   -- a assinatura do dono define os limites da sala
        Status_Acesso           Varchar(15)   NOT NULL DEFAULT 'ATIVA',   -- atualizado por job conforme a assinatura do dono
        SN_Ativa                Char(1)       NOT NULL DEFAULT 'S',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        CONSTRAINT FK_SALAS_USUARIOS FOREIGN KEY (ID_Usuario_Dono) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_SALAS_Status_Acesso CHECK (Status_Acesso IN ('ATIVA', 'SOMENTE_LEITURA', 'CONGELADA')),
        CONSTRAINT CK_SALAS_SN_Ativa      CHECK (SN_Ativa IN ('S', 'N'))
    );

    CREATE NONCLUSTERED INDEX IDX_SALAS_ID_Usuario_Dono ON dbo.SALAS(ID_Usuario_Dono);
END;
GO

-- =============================================================================
-- 10. TABELA: MEMBROS_SALA (CONTROLE DE ACESSO RBAC POR SALA)
-- =============================================================================
IF OBJECT_ID('dbo.MEMBROS_SALA', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MEMBROS_SALA (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        ID_Usuario              Integer       NOT NULL,
        Papel                   Varchar(20)   NOT NULL DEFAULT 'MEMBRO',  -- DONO deve coincidir com SALAS.ID_Usuario_Dono
        SN_Ativo                Char(1)       NOT NULL DEFAULT 'S',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Remocao            Datetime,
        CONSTRAINT FK_MEMBROS_SALA_SALAS    FOREIGN KEY (ID_Sala)    REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_MEMBROS_SALA_USUARIOS FOREIGN KEY (ID_Usuario) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_MEMBROS_SALA_Papel    CHECK (Papel IN ('DONO', 'ADMIN', 'MEMBRO', 'VISUALIZADOR')),
        CONSTRAINT CK_MEMBROS_SALA_SN_Ativo CHECK (SN_Ativo IN ('S', 'N')),
        CONSTRAINT UK_MEMBROS_SALA_ID_Sala_ID_Usuario UNIQUE (ID_Sala, ID_Usuario)
    );

    CREATE NONCLUSTERED INDEX IDX_MEMBROS_SALA_ID_Usuario ON dbo.MEMBROS_SALA(ID_Usuario) INCLUDE (ID_Sala, Papel, SN_Ativo);
END;
GO

-- =============================================================================
-- 11. TABELA: CONVITES_SALA
-- =============================================================================
IF OBJECT_ID('dbo.CONVITES_SALA', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CONVITES_SALA (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        Email                   Varchar(255)  NOT NULL,
        Papel                   Varchar(20)   NOT NULL DEFAULT 'MEMBRO',
        Token_Hash              Varchar(128)  NOT NULL,                   -- guardar SOMENTE o hash do token
        Status                  Varchar(15)   NOT NULL DEFAULT 'PENDENTE',
        ID_Usuario_Convidou     Integer       NOT NULL,
        ID_Usuario_Aceitou      Integer       NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Expiracao          Datetime      NOT NULL,
        CONSTRAINT FK_CONVITES_SALA_SALAS             FOREIGN KEY (ID_Sala)             REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_CONVITES_SALA_USUARIOS_Convidou FOREIGN KEY (ID_Usuario_Convidou) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT FK_CONVITES_SALA_USUARIOS_Aceitou  FOREIGN KEY (ID_Usuario_Aceitou)  REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_CONVITES_SALA_Papel  CHECK (Papel IN ('ADMIN', 'MEMBRO', 'VISUALIZADOR')),
        CONSTRAINT CK_CONVITES_SALA_Status CHECK (Status IN ('PENDENTE', 'ACEITO', 'RECUSADO', 'EXPIRADO', 'CANCELADO')),
        CONSTRAINT UK_CONVITES_SALA_Token_Hash UNIQUE (Token_Hash)
    );

    CREATE NONCLUSTERED INDEX IDX_CONVITES_SALA_ID_Sala_Email ON dbo.CONVITES_SALA(ID_Sala, Email);
END;
GO

-- =============================================================================
-- 12. TABELA: CONFIGURACOES_SALA (MÓDULOS, REGRAS E ALERTAS POR SALA)
-- =============================================================================
IF OBJECT_ID('dbo.CONFIGURACOES_SALA', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CONFIGURACOES_SALA (
        ID                          Integer       PRIMARY KEY IDENTITY,
        ID_Sala                     Integer       NOT NULL,
        SN_Modulo_Contas_Ativo      Char(1)       NOT NULL DEFAULT 'S',
        SN_Modulo_Caixinhas_Ativo   Char(1)       NOT NULL DEFAULT 'S',
        SN_Alerta_Email_Ativo       Char(1)       NOT NULL DEFAULT 'S',
        SN_Alerta_Whatsapp_Ativo    Char(1)       NOT NULL DEFAULT 'N',
        Dias_Antecedencia_Aviso     Integer       NOT NULL DEFAULT 3,
        SN_Avisar_No_Vencimento     Char(1)       NOT NULL DEFAULT 'S',
        SN_Avisar_Apos_Vencimento   Char(1)       NOT NULL DEFAULT 'S',
        SN_Notificar_Aportes        Char(1)       NOT NULL DEFAULT 'S',
        SN_Exigir_Aprovacao_Aporte  Char(1)       NOT NULL DEFAULT 'N',
        SN_Exigir_Aprovacao_Resgate Char(1)       NOT NULL DEFAULT 'S',
        Moeda_Padrao                Varchar(5)    NOT NULL DEFAULT 'BRL',
        Data_Cadastro               Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao              Datetime,
        CONSTRAINT FK_CONFIGURACOES_SALA_SALAS FOREIGN KEY (ID_Sala) REFERENCES dbo.SALAS(ID) ON DELETE CASCADE,
        CONSTRAINT UK_CONFIGURACOES_SALA_ID_Sala UNIQUE (ID_Sala),
        CONSTRAINT CK_CONFIGURACOES_SALA_Dias_Antecedencia_Aviso CHECK (Dias_Antecedencia_Aviso BETWEEN 0 AND 60),
        CONSTRAINT CK_CONFIGURACOES_SALA_Flags CHECK (
                                                      SN_Modulo_Contas_Ativo      IN ('S', 'N') AND
                                                      SN_Modulo_Caixinhas_Ativo   IN ('S', 'N') AND
                                                      SN_Alerta_Email_Ativo       IN ('S', 'N') AND
                                                      SN_Alerta_Whatsapp_Ativo    IN ('S', 'N') AND
                                                      SN_Avisar_No_Vencimento     IN ('S', 'N') AND
                                                      SN_Avisar_Apos_Vencimento   IN ('S', 'N') AND
                                                      SN_Notificar_Aportes        IN ('S', 'N') AND
                                                      SN_Exigir_Aprovacao_Aporte  IN ('S', 'N') AND
                                                      SN_Exigir_Aprovacao_Resgate IN ('S', 'N')
                                                      )
    );
END;
GO

-- =============================================================================
-- 13. TABELA: CATEGORIAS (POR SALA)
-- =============================================================================
IF OBJECT_ID('dbo.CATEGORIAS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CATEGORIAS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        Nome                    Varchar(80)   NOT NULL,
        Tipo                    Varchar(10)   NOT NULL DEFAULT 'DESPESA',
        Cor_Hex                 Varchar(7)    NOT NULL DEFAULT '#3B82F6',
        Icone                   Varchar(50)   NULL,
        SN_Ativa                Char(1)       NOT NULL DEFAULT 'S',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_CATEGORIAS_SALAS FOREIGN KEY (ID_Sala) REFERENCES dbo.SALAS(ID),
        CONSTRAINT CK_CATEGORIAS_Tipo     CHECK (Tipo IN ('DESPESA', 'RECEITA')),
        CONSTRAINT CK_CATEGORIAS_Cor_Hex  CHECK (Cor_Hex LIKE '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'),
        CONSTRAINT CK_CATEGORIAS_SN_Ativa CHECK (SN_Ativa IN ('S', 'N')),
        CONSTRAINT UK_CATEGORIAS_ID_Sala_Nome UNIQUE (ID_Sala, Nome)
    );
END;
GO

-- =============================================================================
-- 14. TABELA: CAIXINHAS (POUPANÇAS E OBJETIVOS COMPARTILHADOS - SEM SALDO GRAVADO)
-- =============================================================================
IF OBJECT_ID('dbo.CAIXINHAS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CAIXINHAS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        ID_Usuario_Criador      Integer       NOT NULL,
        Nome                    Varchar(100)  NOT NULL,
        Descricao               Varchar(MAX)  NULL,
        Valor_Alvo              Decimal(15, 2) NULL,                      -- NULL = caixinha sem meta definida
        Data_Limite             Date          NULL,
        SN_Bloqueada_Resgate    Char(1)       NOT NULL DEFAULT 'N',
        Status                  Varchar(20)   NOT NULL DEFAULT 'EM_ANDAMENTO',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        CONSTRAINT FK_CAIXINHAS_SALAS    FOREIGN KEY (ID_Sala)            REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_CAIXINHAS_USUARIOS FOREIGN KEY (ID_Usuario_Criador) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_CAIXINHAS_Valor_Alvo           CHECK (Valor_Alvo IS NULL OR Valor_Alvo > 0),
        CONSTRAINT CK_CAIXINHAS_SN_Bloqueada_Resgate CHECK (SN_Bloqueada_Resgate IN ('S', 'N')),
        CONSTRAINT CK_CAIXINHAS_Status               CHECK (Status IN ('EM_ANDAMENTO', 'ATINGIDA', 'CANCELADA'))
    );

    CREATE NONCLUSTERED INDEX IDX_CAIXINHAS_ID_Sala ON dbo.CAIXINHAS(ID_Sala);
END;
GO

-- =============================================================================
-- 15. TABELA: MOVIMENTACOES_CAIXINHA (APORTES E RESGATES)
-- =============================================================================
IF OBJECT_ID('dbo.MOVIMENTACOES_CAIXINHA', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MOVIMENTACOES_CAIXINHA (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Caixinha             Integer       NOT NULL,
        ID_Usuario              Integer       NOT NULL,                   -- quem depositou / retirou
        Tipo                    Varchar(10)   NOT NULL,
        Valor                   Decimal(15, 2) NOT NULL,
        Data_Movimento          Date          NOT NULL,
        Observacao              Varchar(255)  NULL,
        Status                  Varchar(15)   NOT NULL DEFAULT 'CONFIRMADO', -- a aplicação grava PENDENTE se a sala exigir aprovação
        ID_Usuario_Decisao      Integer       NULL,
        Data_Decisao            Datetime,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_MOVIMENTACOES_CAIXINHA_CAIXINHAS        FOREIGN KEY (ID_Caixinha)        REFERENCES dbo.CAIXINHAS(ID),
        CONSTRAINT FK_MOVIMENTACOES_CAIXINHA_USUARIOS         FOREIGN KEY (ID_Usuario)         REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT FK_MOVIMENTACOES_CAIXINHA_USUARIOS_Decisao FOREIGN KEY (ID_Usuario_Decisao) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_MOVIMENTACOES_CAIXINHA_Tipo   CHECK (Tipo IN ('APORTE', 'RESGATE')),
        CONSTRAINT CK_MOVIMENTACOES_CAIXINHA_Valor  CHECK (Valor > 0),
        CONSTRAINT CK_MOVIMENTACOES_CAIXINHA_Status CHECK (Status IN ('PENDENTE', 'CONFIRMADO', 'REJEITADO'))
    );

    CREATE NONCLUSTERED INDEX IDX_MOVIMENTACOES_CAIXINHA_ID_Caixinha ON dbo.MOVIMENTACOES_CAIXINHA(ID_Caixinha, Status) INCLUDE (Tipo, Valor);
    CREATE NONCLUSTERED INDEX IDX_MOVIMENTACOES_CAIXINHA_ID_Usuario  ON dbo.MOVIMENTACOES_CAIXINHA(ID_Usuario);
END;
GO

-- =============================================================================
-- 16. TABELA: RECORRENCIAS (MODELO DAS CONTAS QUE SE REPETEM)
-- =============================================================================
IF OBJECT_ID('dbo.RECORRENCIAS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.RECORRENCIAS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        ID_Categoria            Integer       NULL,
        ID_Usuario_Criador      Integer       NOT NULL,
        Titulo                  Varchar(150)  NOT NULL,
        Tipo                    Varchar(10)   NOT NULL DEFAULT 'DESPESA',
        Valor                   Decimal(15, 2) NOT NULL,
        Frequencia              Varchar(10)   NOT NULL DEFAULT 'MENSAL',
        Dia_Vencimento          Integer       NOT NULL,                   -- dia do mês; a aplicação ajusta para o último dia quando necessário
        Data_Inicio             Date          NOT NULL,
        Data_Fim                Date          NULL,                       -- NULL = sem fim
        SN_Ativa                Char(1)       NOT NULL DEFAULT 'S',
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_RECORRENCIAS_SALAS      FOREIGN KEY (ID_Sala)            REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_RECORRENCIAS_CATEGORIAS FOREIGN KEY (ID_Categoria)       REFERENCES dbo.CATEGORIAS(ID),
        CONSTRAINT FK_RECORRENCIAS_USUARIOS   FOREIGN KEY (ID_Usuario_Criador) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_RECORRENCIAS_Tipo           CHECK (Tipo IN ('DESPESA', 'RECEITA')),
        CONSTRAINT CK_RECORRENCIAS_Valor          CHECK (Valor > 0),
        CONSTRAINT CK_RECORRENCIAS_Frequencia     CHECK (Frequencia IN ('SEMANAL', 'MENSAL', 'ANUAL')),
        CONSTRAINT CK_RECORRENCIAS_Dia_Vencimento CHECK (Dia_Vencimento BETWEEN 1 AND 31),
        CONSTRAINT CK_RECORRENCIAS_Datas          CHECK (Data_Fim IS NULL OR Data_Fim >= Data_Inicio),
        CONSTRAINT CK_RECORRENCIAS_SN_Ativa       CHECK (SN_Ativa IN ('S', 'N'))
    );

    CREATE NONCLUSTERED INDEX IDX_RECORRENCIAS_ID_Sala ON dbo.RECORRENCIAS(ID_Sala, SN_Ativa);
END;
GO

-- =============================================================================
-- 17. TABELA: PARCELAMENTOS (AGRUPADOR DE CONTAS PARCELADAS)
-- =============================================================================
IF OBJECT_ID('dbo.PARCELAMENTOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PARCELAMENTOS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        ID_Categoria            Integer       NULL,
        ID_Usuario_Criador      Integer       NOT NULL,
        Descricao               Varchar(150)  NOT NULL,
        Valor_Total             Decimal(15, 2) NOT NULL,
        Qtd_Parcelas            Integer       NOT NULL,
        Data_Primeira_Parcela   Date          NOT NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_PARCELAMENTOS_SALAS      FOREIGN KEY (ID_Sala)            REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_PARCELAMENTOS_CATEGORIAS FOREIGN KEY (ID_Categoria)       REFERENCES dbo.CATEGORIAS(ID),
        CONSTRAINT FK_PARCELAMENTOS_USUARIOS   FOREIGN KEY (ID_Usuario_Criador) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_PARCELAMENTOS_Valor_Total  CHECK (Valor_Total > 0),
        CONSTRAINT CK_PARCELAMENTOS_Qtd_Parcelas CHECK (Qtd_Parcelas BETWEEN 2 AND 360)
    );

    CREATE NONCLUSTERED INDEX IDX_PARCELAMENTOS_ID_Sala ON dbo.PARCELAMENTOS(ID_Sala);
END;
GO

-- =============================================================================
-- 18. TABELA: TRANSACOES (CONTAS A PAGAR E RECEITAS)
-- =============================================================================
IF OBJECT_ID('dbo.TRANSACOES', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TRANSACOES (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        ID_Categoria            Integer       NULL,
        ID_Parcelamento         Integer       NULL,
        Numero_Parcela          Integer       NULL,
        ID_Recorrencia          Integer       NULL,
        ID_Usuario_Criador      Integer       NOT NULL,
        Titulo                  Varchar(150)  NOT NULL,
        Descricao               Varchar(MAX)  NULL,
        Valor                   Decimal(15, 2) NOT NULL,                  -- valor previsto
        Valor_Pago              Decimal(15, 2) NULL,                      -- pode diferir do previsto (juros / desconto)
        Tipo                    Varchar(10)   NOT NULL DEFAULT 'DESPESA',
        Status                  Varchar(10)   NOT NULL DEFAULT 'PENDENTE',-- ATRASADO é calculado na view VW_TRANSACOES
        Data_Vencimento         Date          NOT NULL,
        Data_Pagamento          Datetime,
        ID_Usuario_Pagou        Integer       NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        Data_Exclusao           Datetime,
        CONSTRAINT FK_TRANSACOES_SALAS         FOREIGN KEY (ID_Sala)            REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_TRANSACOES_CATEGORIAS    FOREIGN KEY (ID_Categoria)       REFERENCES dbo.CATEGORIAS(ID),
        CONSTRAINT FK_TRANSACOES_PARCELAMENTOS FOREIGN KEY (ID_Parcelamento)    REFERENCES dbo.PARCELAMENTOS(ID),
        CONSTRAINT FK_TRANSACOES_RECORRENCIAS  FOREIGN KEY (ID_Recorrencia)     REFERENCES dbo.RECORRENCIAS(ID),
        CONSTRAINT FK_TRANSACOES_USUARIOS_Criador FOREIGN KEY (ID_Usuario_Criador) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT FK_TRANSACOES_USUARIOS_Pagou   FOREIGN KEY (ID_Usuario_Pagou)   REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_TRANSACOES_Valor      CHECK (Valor > 0),
        CONSTRAINT CK_TRANSACOES_Valor_Pago CHECK (Valor_Pago IS NULL OR Valor_Pago > 0),
        CONSTRAINT CK_TRANSACOES_Tipo       CHECK (Tipo IN ('DESPESA', 'RECEITA')),
        CONSTRAINT CK_TRANSACOES_Status     CHECK (Status IN ('PENDENTE', 'PAGO', 'CANCELADO')),
        CONSTRAINT CK_TRANSACOES_Pagamento  CHECK (Status <> 'PAGO' OR (Data_Pagamento IS NOT NULL AND ID_Usuario_Pagou IS NOT NULL)),
        CONSTRAINT CK_TRANSACOES_Parcela    CHECK (
                                                   (ID_Parcelamento IS NULL AND Numero_Parcela IS NULL) OR
                                                   (ID_Parcelamento IS NOT NULL AND Numero_Parcela >= 1)
                                                   )
    );

    CREATE NONCLUSTERED INDEX IDX_TRANSACOES_ID_Sala_Status_Vencimento
        ON dbo.TRANSACOES(ID_Sala, Status, Data_Vencimento) INCLUDE (Titulo, Valor, ID_Categoria)
        WHERE Data_Exclusao IS NULL;
    CREATE NONCLUSTERED INDEX IDX_TRANSACOES_Vencimento_Status
        ON dbo.TRANSACOES(Data_Vencimento, Status)
        WHERE Data_Exclusao IS NULL;
    -- impede parcela duplicada e geração duplicada de recorrência
    CREATE UNIQUE NONCLUSTERED INDEX UK_TRANSACOES_Parcelamento_Parcela
        ON dbo.TRANSACOES(ID_Parcelamento, Numero_Parcela) WHERE ID_Parcelamento IS NOT NULL;
    CREATE UNIQUE NONCLUSTERED INDEX UK_TRANSACOES_Recorrencia_Vencimento
        ON dbo.TRANSACOES(ID_Recorrencia, Data_Vencimento) WHERE ID_Recorrencia IS NOT NULL;
END;
GO

-- =============================================================================
-- 19. TABELA: TRANSACAO_DIVISOES (QUANTO CADA MEMBRO DEVE DE CADA CONTA)
-- =============================================================================
IF OBJECT_ID('dbo.TRANSACAO_DIVISOES', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TRANSACAO_DIVISOES (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Transacao            Integer       NOT NULL,
        ID_Usuario              Integer       NOT NULL,
        Valor_Parte             Decimal(15, 2) NOT NULL,
        SN_Pago                 Char(1)       NOT NULL DEFAULT 'N',
        Data_Pagamento          Datetime,
        CONSTRAINT FK_TRANSACAO_DIVISOES_TRANSACOES FOREIGN KEY (ID_Transacao) REFERENCES dbo.TRANSACOES(ID),
        CONSTRAINT FK_TRANSACAO_DIVISOES_USUARIOS   FOREIGN KEY (ID_Usuario)   REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_TRANSACAO_DIVISOES_Valor_Parte CHECK (Valor_Parte > 0),
        CONSTRAINT CK_TRANSACAO_DIVISOES_SN_Pago     CHECK (SN_Pago IN ('S', 'N')),
        CONSTRAINT UK_TRANSACAO_DIVISOES_ID_Transacao_ID_Usuario UNIQUE (ID_Transacao, ID_Usuario)
    );

    CREATE NONCLUSTERED INDEX IDX_TRANSACAO_DIVISOES_ID_Usuario ON dbo.TRANSACAO_DIVISOES(ID_Usuario, SN_Pago);
END;
GO

-- =============================================================================
-- 20. TABELA: COBRANCAS (COBRANÇA ENTRE MEMBROS - O SISTEMA NÃO MOVIMENTA DINHEIRO)
-- =============================================================================
IF OBJECT_ID('dbo.COBRANCAS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.COBRANCAS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Transacao_Divisao    Integer       NOT NULL,                   -- o devedor é o ID_Usuario da divisão
        ID_Usuario_Cobrador     Integer       NOT NULL,
        Valor                   Decimal(15, 2) NOT NULL,                  -- valor no momento da cobrança
        Status                  Varchar(25)   NOT NULL DEFAULT 'PENDENTE',
        Qtd_Lembretes           Integer       NOT NULL DEFAULT 0,
        Data_Ultimo_Lembrete    Datetime,
        Data_Marcada_Paga       Datetime,                                 -- quando o devedor disse "paguei"
        ID_Usuario_Decisao      Integer       NULL,                       -- quem confirmou ou recusou
        Data_Decisao            Datetime,
        Motivo_Recusa           Varchar(255)  NULL,                       -- obrigatório na recusa (regra da aplicação)
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Alteracao          Datetime,
        CONSTRAINT FK_COBRANCAS_TRANSACAO_DIVISOES FOREIGN KEY (ID_Transacao_Divisao) REFERENCES dbo.TRANSACAO_DIVISOES(ID),
        CONSTRAINT FK_COBRANCAS_USUARIOS_Cobrador  FOREIGN KEY (ID_Usuario_Cobrador)  REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT FK_COBRANCAS_USUARIOS_Decisao   FOREIGN KEY (ID_Usuario_Decisao)   REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_COBRANCAS_Valor         CHECK (Valor > 0),
        CONSTRAINT CK_COBRANCAS_Status        CHECK (Status IN ('PENDENTE', 'AGUARDANDO_CONFIRMACAO', 'PAGA', 'CANCELADA')),
        CONSTRAINT CK_COBRANCAS_Qtd_Lembretes CHECK (Qtd_Lembretes >= 0)
    );

    CREATE NONCLUSTERED INDEX IDX_COBRANCAS_ID_Transacao_Divisao ON dbo.COBRANCAS(ID_Transacao_Divisao);
    CREATE NONCLUSTERED INDEX IDX_COBRANCAS_Cobrador_Status      ON dbo.COBRANCAS(ID_Usuario_Cobrador, Status);
    -- no máximo uma cobrança em aberto por divisão
    CREATE UNIQUE NONCLUSTERED INDEX UK_COBRANCAS_Divisao_Aberta
        ON dbo.COBRANCAS(ID_Transacao_Divisao) WHERE Status IN ('PENDENTE', 'AGUARDANDO_CONFIRMACAO');
END;
GO

-- =============================================================================
-- 21. TABELA: ANEXOS (COMPROVANTES E NOTAS FISCAIS NO CLOUDFLARE R2)
-- =============================================================================
IF OBJECT_ID('dbo.ANEXOS', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ANEXOS (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Transacao            Integer       NULL,
        ID_Movimentacao         Integer       NULL,
        ID_Cobranca             Integer       NULL,
        ID_Usuario_Enviou       Integer       NOT NULL,
        Nome_Arquivo_Original   Varchar(255)  NOT NULL,
        Chave_R2                Varchar(500)  NOT NULL,                   -- path do objeto no R2 (acesso por URL pré-assinada)
        Tipo_Mime               Varchar(100)  NOT NULL,                   -- ex: 'image/jpeg', 'application/pdf'
        Tamanho_Bytes           Bigint        NOT NULL,
        Hash_Sha256             Char(64)      NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        Data_Exclusao           Datetime,
        CONSTRAINT FK_ANEXOS_TRANSACOES              FOREIGN KEY (ID_Transacao)      REFERENCES dbo.TRANSACOES(ID),
        CONSTRAINT FK_ANEXOS_MOVIMENTACOES_CAIXINHA  FOREIGN KEY (ID_Movimentacao)   REFERENCES dbo.MOVIMENTACOES_CAIXINHA(ID),
        CONSTRAINT FK_ANEXOS_COBRANCAS               FOREIGN KEY (ID_Cobranca)       REFERENCES dbo.COBRANCAS(ID),
        CONSTRAINT FK_ANEXOS_USUARIOS                FOREIGN KEY (ID_Usuario_Enviou) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_ANEXOS_Destino CHECK (
                                            (CASE WHEN ID_Transacao    IS NULL THEN 0 ELSE 1 END +
                                             CASE WHEN ID_Movimentacao IS NULL THEN 0 ELSE 1 END +
                                             CASE WHEN ID_Cobranca     IS NULL THEN 0 ELSE 1 END) = 1
                                            ),
        CONSTRAINT CK_ANEXOS_Tamanho_Bytes CHECK (Tamanho_Bytes > 0),
        CONSTRAINT CK_ANEXOS_Tipo_Mime     CHECK (Tipo_Mime IN ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
        CONSTRAINT UK_ANEXOS_Chave_R2 UNIQUE (Chave_R2)
    );

    CREATE NONCLUSTERED INDEX IDX_ANEXOS_ID_Transacao    ON dbo.ANEXOS(ID_Transacao)    WHERE ID_Transacao IS NOT NULL;
    CREATE NONCLUSTERED INDEX IDX_ANEXOS_ID_Movimentacao ON dbo.ANEXOS(ID_Movimentacao) WHERE ID_Movimentacao IS NOT NULL;
    CREATE NONCLUSTERED INDEX IDX_ANEXOS_ID_Cobranca     ON dbo.ANEXOS(ID_Cobranca)     WHERE ID_Cobranca IS NOT NULL;
END;
GO

-- =============================================================================
-- 22. TABELA: NOTIFICACOES_LOG (HISTÓRICO DE DISPAROS E CONTROLE ANTI-SPAM)
-- =============================================================================
IF OBJECT_ID('dbo.NOTIFICACOES_LOG', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.NOTIFICACOES_LOG (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        ID_Transacao            Integer       NULL,
        ID_Movimentacao         Integer       NULL,
        ID_Cobranca             Integer       NULL,
        ID_Usuario_Destinatario Integer       NOT NULL,
        Canal                   Varchar(10)   NOT NULL,
        Tipo_Evento             Varchar(30)   NOT NULL,
        Data_Referencia         Date          NOT NULL DEFAULT CAST(GETDATE() AS Date),
        Status_Envio            Varchar(10)   NOT NULL,
        Mensagem_Erro           Varchar(MAX)  NULL,
        Data_Envio              Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_NOTIFICACOES_LOG_SALAS                FOREIGN KEY (ID_Sala)                REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_NOTIFICACOES_LOG_TRANSACOES           FOREIGN KEY (ID_Transacao)           REFERENCES dbo.TRANSACOES(ID),
        CONSTRAINT FK_NOTIFICACOES_LOG_MOVIMENTACOES_CAIXINHA FOREIGN KEY (ID_Movimentacao)      REFERENCES dbo.MOVIMENTACOES_CAIXINHA(ID),
        CONSTRAINT FK_NOTIFICACOES_LOG_COBRANCAS            FOREIGN KEY (ID_Cobranca)            REFERENCES dbo.COBRANCAS(ID),
        CONSTRAINT FK_NOTIFICACOES_LOG_USUARIOS             FOREIGN KEY (ID_Usuario_Destinatario) REFERENCES dbo.USUARIOS(ID),
        CONSTRAINT CK_NOTIFICACOES_LOG_Canal        CHECK (Canal IN ('EMAIL', 'WHATSAPP')),
        CONSTRAINT CK_NOTIFICACOES_LOG_Tipo_Evento  CHECK (Tipo_Evento IN ('VENCIMENTO_PROXIMO', 'VENCE_HOJE', 'ATRASO', 'NOVO_APORTE', 'APORTE_PENDENTE', 'RESGATE_PENDENTE', 'COBRANCA', 'CONVITE')),
        CONSTRAINT CK_NOTIFICACOES_LOG_Status_Envio CHECK (Status_Envio IN ('ENVIADO', 'FALHA'))
    );

    CREATE NONCLUSTERED INDEX IDX_NOTIFICACOES_LOG_Busca ON dbo.NOTIFICACOES_LOG(ID_Sala, ID_Usuario_Destinatario, Data_Envio);
    -- no máximo um envio bem-sucedido por evento / canal / dia / destinatário (inclui o limite de 1 lembrete de cobrança por dia)
    CREATE UNIQUE NONCLUSTERED INDEX UK_NOTIFICACOES_LOG_AntiSpam_Transacao
        ON dbo.NOTIFICACOES_LOG(ID_Transacao, ID_Usuario_Destinatario, Canal, Tipo_Evento, Data_Referencia)
        WHERE ID_Transacao IS NOT NULL AND Status_Envio = 'ENVIADO';
    CREATE UNIQUE NONCLUSTERED INDEX UK_NOTIFICACOES_LOG_AntiSpam_Cobranca
        ON dbo.NOTIFICACOES_LOG(ID_Cobranca, ID_Usuario_Destinatario, Canal, Tipo_Evento, Data_Referencia)
        WHERE ID_Cobranca IS NOT NULL AND Status_Envio = 'ENVIADO';
END;
GO

-- =============================================================================
-- 23. TABELA: AUDITORIA_ATIVIDADES (HISTÓRICO DE AÇÕES NA SALA)
-- =============================================================================
IF OBJECT_ID('dbo.AUDITORIA_ATIVIDADES', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AUDITORIA_ATIVIDADES (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Sala                 Integer       NOT NULL,
        ID_Usuario              Integer       NULL,
        Entidade                Varchar(50)   NOT NULL,                   -- 'TRANSACAO', 'CAIXINHA', 'MOVIMENTACAO', 'COBRANCA', 'SALA', 'MEMBRO', 'CONFIGURACAO', 'ANEXO'
        ID_Entidade             Integer       NOT NULL,
        Acao                    Varchar(50)   NOT NULL,                   -- 'CRIOU', 'EDITOU', 'PAGOU', 'EXCLUIU', 'APORTOU', 'RESGATOU', 'CONFIRMOU', 'RECUSOU'
        Detalhes_Json           Varchar(MAX)  NULL,                       -- JSON com dados do antes/depois
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_AUDITORIA_ATIVIDADES_SALAS    FOREIGN KEY (ID_Sala)    REFERENCES dbo.SALAS(ID),
        CONSTRAINT FK_AUDITORIA_ATIVIDADES_USUARIOS FOREIGN KEY (ID_Usuario) REFERENCES dbo.USUARIOS(ID) ON DELETE SET NULL,
        CONSTRAINT CK_AUDITORIA_ATIVIDADES_Detalhes_Json CHECK (Detalhes_Json IS NULL OR ISJSON(Detalhes_Json) = 1)
    );

    CREATE NONCLUSTERED INDEX IDX_AUDITORIA_ATIVIDADES_ID_Sala ON dbo.AUDITORIA_ATIVIDADES(ID_Sala, Data_Cadastro DESC);
    CREATE NONCLUSTERED INDEX IDX_AUDITORIA_ATIVIDADES_Entidade ON dbo.AUDITORIA_ATIVIDADES(Entidade, ID_Entidade);
END;
GO

-- =============================================================================
-- 24. TABELA: AUDITORIA_SEGURANCA (LOGIN, SENHA, SESSÃO - NÃO PERTENCE A NENHUMA SALA)
-- =============================================================================
IF OBJECT_ID('dbo.AUDITORIA_SEGURANCA', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AUDITORIA_SEGURANCA (
        ID                      Integer       PRIMARY KEY IDENTITY,
        ID_Usuario              Integer       NULL,                       -- NULL = tentativa com e-mail inexistente
        Evento                  Varchar(30)   NOT NULL,                   -- 'LOGIN_SUCESSO', 'LOGIN_FALHA', 'SENHA_ALTERADA', 'EMAIL_VERIFICADO', 'IDENTIDADE_VINCULADA', 'CONTA_BLOQUEADA', 'SESSAO_REVOGADA'
        Provedor                Varchar(20)   NULL,                       -- 'SENHA' ou 'GOOGLE'
        Email_Informado         Varchar(255)  NULL,
        IP                      Varchar(45)   NULL,
        User_Agent              Varchar(255)  NULL,
        Detalhes_Json           Varchar(MAX)  NULL,
        Data_Cadastro           Datetime      NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_AUDITORIA_SEGURANCA_USUARIOS FOREIGN KEY (ID_Usuario) REFERENCES dbo.USUARIOS(ID) ON DELETE SET NULL,
        CONSTRAINT CK_AUDITORIA_SEGURANCA_Detalhes_Json CHECK (Detalhes_Json IS NULL OR ISJSON(Detalhes_Json) = 1)
    );

    CREATE NONCLUSTERED INDEX IDX_AUDITORIA_SEGURANCA_ID_Usuario ON dbo.AUDITORIA_SEGURANCA(ID_Usuario, Data_Cadastro DESC);
    CREATE NONCLUSTERED INDEX IDX_AUDITORIA_SEGURANCA_Evento     ON dbo.AUDITORIA_SEGURANCA(Evento, Data_Cadastro DESC);
END;
GO

-- =============================================================================
-- VIEWS
-- =============================================================================
-- Saldo em tempo real de cada caixinha (somente movimentações confirmadas)
CREATE OR ALTER VIEW dbo.VW_CAIXINHAS_SALDO AS
SELECT  C.ID           AS ID_Caixinha,
        C.ID_Sala,
        C.Nome,
        C.Valor_Alvo,
        COALESCE(SUM(CASE WHEN M.Status = 'CONFIRMADO' AND M.Tipo = 'APORTE'  THEN M.Valor END), 0)
      - COALESCE(SUM(CASE WHEN M.Status = 'CONFIRMADO' AND M.Tipo = 'RESGATE' THEN M.Valor END), 0) AS Saldo_Atual
FROM dbo.CAIXINHAS C
LEFT JOIN dbo.MOVIMENTACOES_CAIXINHA M ON M.ID_Caixinha = C.ID
GROUP BY C.ID, C.ID_Sala, C.Nome, C.Valor_Alvo;
GO

-- Transações com o status de exibição (inclui ATRASADO calculado)
CREATE OR ALTER VIEW dbo.VW_TRANSACOES AS
SELECT  T.*,
        CASE WHEN T.Status = 'PENDENTE' AND T.Data_Vencimento < CAST(GETDATE() AS Date)
             THEN 'ATRASADO' ELSE T.Status END AS Status_Exibicao
FROM dbo.TRANSACOES T
WHERE T.Data_Exclusao IS NULL;
GO