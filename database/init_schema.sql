-- =============================================================================
-- PROJETO: CONTA COMIGO
-- SISTEMA DE GESTÃO FINANCEIRA COLABORATIVA COM SALAS, METAS E COMPROVANTES
-- SGBD: Microsoft SQL Server 2022+ (T-SQL para Docker / Dapper / .NET)
-- =============================================================================

-- =============================================================================
-- 1. TABELA: USUARIOS
-- =============================================================================
IF OBJECT_ID('dbo.usuarios', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.usuarios (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        nome NVARCHAR(150) NOT NULL,
        email NVARCHAR(255) NOT NULL,
        senha_hash NVARCHAR(255) NOT NULL,
        telefone_whatsapp NVARCHAR(20) NULL,
        foto_url NVARCHAR(500) NULL,
        ativo BIT NOT NULL DEFAULT 1,
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        atualizado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT uk_usuarios_email UNIQUE (email)
    );

    CREATE NONCLUSTERED INDEX idx_usuarios_email ON dbo.usuarios(email);
END;

-- =============================================================================
-- 2. TABELA: PREFERENCIAS_NOTIFICACAO_USUARIO
-- =============================================================================
IF OBJECT_ID('dbo.preferencias_notificacao_usuario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.preferencias_notificacao_usuario (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        usuario_id UNIQUEIDENTIFIER NOT NULL,
        receber_email BIT NOT NULL DEFAULT 1,
        receber_whatsapp BIT NOT NULL DEFAULT 1,
        silenciar_tudo BIT NOT NULL DEFAULT 0,
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        atualizado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_pref_usuario FOREIGN KEY (usuario_id) REFERENCES dbo.usuarios(id) ON DELETE CASCADE,
        CONSTRAINT uk_pref_usuario UNIQUE (usuario_id)
    );
END;

-- =============================================================================
-- 3. TABELA: SALAS (WORKSPACES FINANCEIROS)
-- =============================================================================
IF OBJECT_ID('dbo.salas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.salas (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        nome NVARCHAR(100) NOT NULL,
        descricao NVARCHAR(255) NULL,
        tipo NVARCHAR(30) NOT NULL DEFAULT 'GERAL',
        criada_por UNIQUEIDENTIFIER NOT NULL,
        ativa BIT NOT NULL DEFAULT 1,
        criada_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        atualizada_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_salas_criador FOREIGN KEY (criada_por) REFERENCES dbo.usuarios(id),
        CONSTRAINT ck_salas_tipo CHECK (tipo IN ('FIXAS', 'CAIXINHA', 'GERAL'))
    );

    CREATE NONCLUSTERED INDEX idx_salas_criada_por ON dbo.salas(criada_por);
END;

-- =============================================================================
-- 4. TABELA: MEMBROS_SALA (CONTROLE DE ACESSO RBAC POR SALA)
-- =============================================================================
IF OBJECT_ID('dbo.membros_sala', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.membros_sala (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        usuario_id UNIQUEIDENTIFIER NOT NULL,
        papel NVARCHAR(20) NOT NULL DEFAULT 'MEMBRO',
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_membros_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE,
        CONSTRAINT fk_membros_usuario FOREIGN KEY (usuario_id) REFERENCES dbo.usuarios(id) ON DELETE CASCADE,
        CONSTRAINT ck_membros_papel CHECK (papel IN ('DONO', 'ADMIN', 'MEMBRO', 'VISUALIZADOR')),
        CONSTRAINT uk_membros_sala UNIQUE (sala_id, usuario_id)
    );

    CREATE NONCLUSTERED INDEX idx_membros_sala_sala_id ON dbo.membros_sala(sala_id);
    CREATE NONCLUSTERED INDEX idx_membros_sala_usuario_id ON dbo.membros_sala(usuario_id);
END;

-- =============================================================================
-- 5. TABELA: CONFIGURACOES_SALA (REGRAS E ALERTAS POR SALA)
-- =============================================================================
IF OBJECT_ID('dbo.configuracoes_sala', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.configuracoes_sala (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        alerta_email_ativo BIT NOT NULL DEFAULT 1,
        alerta_whatsapp_ativo BIT NOT NULL DEFAULT 0,
        dias_antecedencia_aviso INT NOT NULL DEFAULT 3,
        avisar_no_dia_vencimento BIT NOT NULL DEFAULT 1,
        avisar_apos_vencimento BIT NOT NULL DEFAULT 1,
        notificar_aportes_caixinha BIT NOT NULL DEFAULT 1,
        exigir_aprovacao_saque BIT NOT NULL DEFAULT 1,
        moeda_padrao NVARCHAR(5) NOT NULL DEFAULT 'BRL',
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        atualizado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_config_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE,
        CONSTRAINT uk_config_sala UNIQUE (sala_id)
    );
END;

-- =============================================================================
-- 6. TABELA: CATEGORIAS (POR SALA)
-- =============================================================================
IF OBJECT_ID('dbo.categorias', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.categorias (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        nome NVARCHAR(80) NOT NULL,
        cor_hex NVARCHAR(7) NOT NULL DEFAULT '#3B82F6',
        icone NVARCHAR(50) NULL,
        criada_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_categorias_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE
    );

    CREATE NONCLUSTERED INDEX idx_categorias_sala_id ON dbo.categorias(sala_id);
END;

-- =============================================================================
-- 7. TABELA: METAS_CAIXINHAS (POUPANÇAS E OBJETIVOS COMPARTILHADOS)
-- =============================================================================
IF OBJECT_ID('dbo.metas_caixinhas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.metas_caixinhas (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        criada_por UNIQUEIDENTIFIER NOT NULL,
        nome NVARCHAR(100) NOT NULL,
        descricao NVARCHAR(MAX) NULL,
        valor_alvo DECIMAL(15, 2) NOT NULL,
        saldo_atual DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
        data_limite DATE NULL,
        bloqueada_para_saque BIT NOT NULL DEFAULT 0,
        status NVARCHAR(20) NOT NULL DEFAULT 'EM_ANDAMENTO',
        criada_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        atualizada_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_metas_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE,
        CONSTRAINT fk_metas_criador FOREIGN KEY (criada_por) REFERENCES dbo.usuarios(id),
        CONSTRAINT ck_metas_valor_alvo CHECK (valor_alvo > 0),
        CONSTRAINT ck_metas_saldo_atual CHECK (saldo_atual >= 0),
        CONSTRAINT ck_metas_status CHECK (status IN ('EM_ANDAMENTO', 'ATINGIDA', 'CANCELADA'))
    );

    CREATE NONCLUSTERED INDEX idx_metas_caixinhas_sala_id ON dbo.metas_caixinhas(sala_id);
END;

-- =============================================================================
-- 8. TABELA: PARCELAMENTOS (AGRUPADOR DE CONTAS PARCELADAS)
-- =============================================================================
IF OBJECT_ID('dbo.parcelamentos', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.parcelamentos (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        criado_por UNIQUEIDENTIFIER NOT NULL,
        descricao NVARCHAR(150) NOT NULL,
        valor_total DECIMAL(15, 2) NOT NULL,
        quantidade_parcelas INT NOT NULL,
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_parcelamentos_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE,
        CONSTRAINT fk_parcelamentos_criador FOREIGN KEY (criado_por) REFERENCES dbo.usuarios(id),
        CONSTRAINT ck_parcelamentos_valor_total CHECK (valor_total > 0),
        CONSTRAINT ck_parcelamentos_quantidade CHECK (quantidade_parcelas > 1)
    );

    CREATE NONCLUSTERED INDEX idx_parcelamentos_sala_id ON dbo.parcelamentos(sala_id);
END;

-- =============================================================================
-- 9. TABELA: TRANSACOES (CONTAS FIXAS, RECEITAS, DESPESAS E APORTES)
-- =============================================================================
IF OBJECT_ID('dbo.transacoes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.transacoes (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        categoria_id UNIQUEIDENTIFIER NULL,
        meta_id UNIQUEIDENTIFIER NULL,
        parcelamento_id UNIQUEIDENTIFIER NULL,
        numero_parcela INT NULL,
        criado_por UNIQUEIDENTIFIER NOT NULL,
        atribuido_a UNIQUEIDENTIFIER NULL,
        titulo NVARCHAR(150) NOT NULL,
        descricao NVARCHAR(MAX) NULL,
        valor DECIMAL(15, 2) NOT NULL,
        tipo NVARCHAR(25) NOT NULL,
        status NVARCHAR(20) NOT NULL DEFAULT 'PENDENTE',
        data_vencimento DATE NOT NULL,
        data_pagamento DATETIMEOFFSET NULL,
        pago_por UNIQUEIDENTIFIER NULL,
        recorrente BIT NOT NULL DEFAULT 0,
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        atualizado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_transacoes_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE,
        CONSTRAINT fk_transacoes_categoria FOREIGN KEY (categoria_id) REFERENCES dbo.categorias(id) ON DELETE SET NULL,
        CONSTRAINT fk_transacoes_meta FOREIGN KEY (meta_id) REFERENCES dbo.metas_caixinhas(id) ON DELETE SET NULL,
        CONSTRAINT fk_transacoes_parcelamento FOREIGN KEY (parcelamento_id) REFERENCES dbo.parcelamentos(id) ON DELETE SET NULL,
        CONSTRAINT fk_transacoes_criador FOREIGN KEY (criado_por) REFERENCES dbo.usuarios(id),
        CONSTRAINT fk_transacoes_atribuido FOREIGN KEY (atribuido_a) REFERENCES dbo.usuarios(id),
        CONSTRAINT fk_transacoes_pagador FOREIGN KEY (pago_por) REFERENCES dbo.usuarios(id),
        CONSTRAINT ck_transacoes_valor CHECK (valor > 0),
        CONSTRAINT ck_transacoes_tipo CHECK (tipo IN ('DESPESA', 'RECEITA', 'APORTE_CAIXINHA', 'RESGATE_CAIXINHA')),
        CONSTRAINT ck_transacoes_status CHECK (status IN ('PENDENTE', 'PAGO', 'CANCELADO'))
    );

    CREATE NONCLUSTERED INDEX idx_transacoes_sala_id ON dbo.transacoes(sala_id);
    CREATE NONCLUSTERED INDEX idx_transacoes_vencimento ON dbo.transacoes(data_vencimento);
    CREATE NONCLUSTERED INDEX idx_transacoes_status ON dbo.transacoes(status);
    CREATE NONCLUSTERED INDEX idx_transacoes_meta_id ON dbo.transacoes(meta_id);
    CREATE NONCLUSTERED INDEX idx_transacoes_parcelamento_id ON dbo.transacoes(parcelamento_id);
END;

-- =============================================================================
-- 10. TABELA: ANEXOS_TRANSACAO (COMPROVANTES E NOTAS FISCAIS NO CLOUDFLARE R2)
-- =============================================================================
IF OBJECT_ID('dbo.anexos_transacao', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.anexos_transacao (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        transacao_id UNIQUEIDENTIFIER NOT NULL,
        enviado_por UNIQUEIDENTIFIER NOT NULL,
        nome_arquivo_original NVARCHAR(255) NOT NULL,
        chave_r2 NVARCHAR(500) NOT NULL, -- Path do objeto no Cloudflare R2
        tipo_mime NVARCHAR(100) NOT NULL, -- ex: 'image/jpeg', 'application/pdf'
        tamanho_bytes BIGINT NOT NULL,
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_anexos_transacao FOREIGN KEY (transacao_id) REFERENCES dbo.transacoes(id) ON DELETE CASCADE,
        CONSTRAINT fk_anexos_enviado_por FOREIGN KEY (enviado_por) REFERENCES dbo.usuarios(id)
    );

    CREATE NONCLUSTERED INDEX idx_anexos_transacao_transacao_id ON dbo.anexos_transacao(transacao_id);
END;

-- =============================================================================
-- 11. TABELA: NOTIFICACOES_LOG (HISTÓRICO DE DISPAROS E CONTROLE ANTI-SPAM)
-- =============================================================================
IF OBJECT_ID('dbo.notificacoes_log', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.notificacoes_log (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        transacao_id UNIQUEIDENTIFIER NULL,
        destinatario_id UNIQUEIDENTIFIER NOT NULL,
        canal NVARCHAR(20) NOT NULL,
        tipo_evento NVARCHAR(30) NOT NULL,
        status_envio NVARCHAR(20) NOT NULL,
        mensagem_erro NVARCHAR(MAX) NULL,
        enviado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_notif_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE,
        CONSTRAINT fk_notif_transacao FOREIGN KEY (transacao_id) REFERENCES dbo.transacoes(id) ON DELETE CASCADE,
        CONSTRAINT fk_notif_destinatario FOREIGN KEY (destinatario_id) REFERENCES dbo.usuarios(id) ON DELETE CASCADE,
        CONSTRAINT ck_notif_canal CHECK (canal IN ('EMAIL', 'WHATSAPP')),
        CONSTRAINT ck_notif_tipo_evento CHECK (tipo_evento IN ('VENCIMENTO_PROXIMO', 'VENCE_HOJE', 'ATRASO', 'NOVO_APORTE')),
        CONSTRAINT ck_notif_status_envio CHECK (status_envio IN ('ENVIADO', 'FALHA'))
    );

    CREATE NONCLUSTERED INDEX idx_notificacoes_log_busca ON dbo.notificacoes_log(sala_id, destinatario_id, enviado_em);
END;

-- =============================================================================
-- 12. TABELA: AUDITORIA_ATIVIDADES (HISTÓRICO DE AÇÕES NA SALA)
-- =============================================================================
IF OBJECT_ID('dbo.auditoria_atividades', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.auditoria_atividades (
        id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        sala_id UNIQUEIDENTIFIER NOT NULL,
        usuario_id UNIQUEIDENTIFIER NULL,
        entidade NVARCHAR(50) NOT NULL, -- 'TRANSACAO', 'CAIXINHA', 'SALA', 'CONFIGURACAO'
        entidade_id UNIQUEIDENTIFIER NOT NULL,
        acao NVARCHAR(50) NOT NULL, -- 'CRIOU', 'EDITOU', 'PAGOU', 'EXCLUIU', 'SACOU'
        detalhes_json NVARCHAR(MAX) NULL, -- JSON com dados do antes/depois
        criado_em DATETIMEOFFSET NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        CONSTRAINT fk_auditoria_sala FOREIGN KEY (sala_id) REFERENCES dbo.salas(id) ON DELETE CASCADE,
        CONSTRAINT fk_auditoria_usuario FOREIGN KEY (usuario_id) REFERENCES dbo.usuarios(id) ON DELETE SET NULL,
        CONSTRAINT ck_auditoria_detalhes_json CHECK (detalhes_json IS NULL OR ISJSON(detalhes_json) = 1)
    );

    CREATE NONCLUSTERED INDEX idx_auditoria_sala_id ON dbo.auditoria_atividades(sala_id);
END;
