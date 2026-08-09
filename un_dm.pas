unit un_dm;

interface

uses
  System.SysUtils, System.Classes, Data.DB, IBX.IBCustomDataSet, IBX.IBQuery,
  IBX.IBDatabase, IBX.IBSQL, FireDAC.Stan.Intf,IniFiles,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef, FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet;

type

  TDM = class(TDataModule)
    Qr_Crud: TIBQuery;
    IBT_Crud: TIBTransaction;
    IBT_Consulta: TIBTransaction;
    IBD_Gestao: TIBDatabase;
    IBT_Atualiza: TIBTransaction;
    IBD_Servidor: TIBDatabase;
    IBT_Servidor: TIBTransaction;
    IBSQL: TIBSQL;
    Qr_Acao: TIBQuery;
    Qr_Consulta: TIBQuery;
    IB_Transacao: TIBTransaction;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure setBDCrud(BD:TIBDatabase);
    procedure ExecConsulta(SqlTxt: String);
    procedure ExecComando(SqlTxt: String);
    // Igual ao ExecComando, mas devolve as linhas afetadas (RowsAffected) -
    // usado pela primeira carga para informar quantos registros entraram na fila.
    function ExecComandoRet(SqlTxt: String): Integer;
    procedure AtivaTrigger(op: Boolean);
    procedure ConectaBancoLocal;
    procedure ConectaBancoServidor;
    // Bootstrap do banco do cliente (Infra-IA/Sincronizador/prompt_construcao_
    // banco_cliente.md, decisoes 1-10) - prepara o Firebird inteiro sem SQL
    // manual: TB_SINCRONIA + generator/trigger, TB_LISTA_SINCRONIA + seed +
    // LAST_UPDATE, DELETED universal, EXTERNALCODE e triggers TG_SRC_*.
    // Todo DDL usa apenas sintaxe valida no Firebird 2.5 E 5.0 (decisao 10).
    function  TabelaExiste(const ANomeTabela: String): Boolean;
    function  TabelaVazia(const ANomeTabela: String): Boolean;
    function  CampoExiste(const ANomeTabela, ANomeCampo: String): Boolean;
    function  GeneratorExiste(const ANomeGenerator: String): Boolean;
    function  TriggerExiste(const ANomeTrigger: String): Boolean;
    procedure EnsureSincroniaTable;
    procedure EnsureListaSincroniaTable;
    procedure SeedListaSincroniaIfEmpty;
    procedure EnforceSeqCatalogo;
    procedure EnsureDeletedColumns;
    procedure EnsureExternalCode;
    procedure EnsureCategoryTable;
    procedure EnsureTriggers;
    // Conversao TB_GRUPOS/TB_SUBGRUPOS -> TB_CATEGORY (Valdo, 2026-08-01):
    // arvore de DOIS niveis (grupo = raiz, subgrupo = filha) + preenche
    // TB_PRODUTO.PRO_CODCAT onde ainda esta vazio. Roda DEPOIS de
    // EnsureTriggers para a conversao cair na TB_SINCRONIA e sincronizar.
    procedure MigraGruposParaCategoria;
    // Limpeza final do bootstrap (Valdo, 2026-08-09; CORRIGIDO 2026-08-09 —
    // so no clique manual, nunca no start automatico): a propria preparacao
    // do banco (em especial MigraGruposParaCategoria, que roda DEPOIS dos
    // triggers TG_SRC_* de proposito) pode enfileirar TB_SINCRONIA so por
    // efeito colateral do boot - nao e mudanca legitima nem Primeira Carga.
    // Zera a fila e o generator, mas SOMENTE quando pLimparFila=True
    // (MnuPreparaLocalClick/"Preparar o banco") - o start automatico
    // (DataModuleCreate) NUNCA deve zerar a fila, senao qualquer abertura
    // do Sincronizador apaga registros legitimos ainda pendentes de envio.
    procedure LimpaFilaSincroniaDoBootstrap;
    procedure EnsureSincronia(pLimparFila: Boolean = False);
    // Motor de reindexação (D3/D4): resolve o CPF/CNPJ real a partir do
    // código interno do Firebird (EMP_CODIGO) — usado por toda classe de
    // envio que hoje só manda o código local onde o contrato novo exige
    // *Document (customerDocument/salesmanDocument/providerDocument/...).
    // '' quando o código é 0/inexistente/sem documento cadastrado.
    function GetDocumentByEmpCodigo(pCodigoEmpresa: Integer): String;
    // Le o flag DELETED real do registro (decisao 8) - usado pelas classes
    // *_send_web para montar o payload; 'N' quando registro/coluna ausente.
    function GetDeletedFlag(const pTabela, pCampoChave: String; pCodigo: Integer): String;
    // Numero da NFS-e da nota de SERVICO (decisao Valdo 2026-08-01): na nota
    // de servico o NFL_NUMERO fica vazio - o numero real esta no RETORNO da
    // NFS-e (TB_RETORNO_NFS.NFS_NUMERO, chave NFS_CODNFL = NFL_CODIGO).
    // '' quando ainda nao ha retorno (a nota reenvia no proximo ciclo ate a
    // NFS-e ser autorizada) ou banco sem NFS-e.
    function GetNfsNumero(pCodNfl: Integer): String;
    // Indexacao do AUTOR (prompt_indexacao_usuario_firebird.md, decisao 2):
    // resolve USU_CODIGO para a referencia do bloco `user` dos movimentos.
    // Cascata: colaborador vinculado com CPF/CNPJ VALIDO -> pDocumento;
    // colaborador sem doc -> TB_COLABORADOR.EXTERNALCODE; sem colaborador ->
    // TB_USUARIO.EXTERNALCODE. Decisao 8 (PDV): com GbTerminal <> 0 so
    // resolve por DOCUMENTO (EXTERNALCODE nao e replicado pela retaguarda) -
    // sem doc o movimento viaja SEM bloco user (fallback da web).
    // False = sem referencia disponivel neste ciclo (auto-heal).
    function GetUserSyncRef(pUsuCodigo: Integer; var pDocumento, pExternalCode: String): Boolean;
  public
    // Gate (criterio de sucesso 2): a sincronizacao so e liberada quando o
    // bootstrap completou sem erro nesta execucao.
    BootstrapOk : Boolean;
    // Indexador terminal (prompt_indexador_terminal_pdv.md, decisoes 1-3):
    // numero do terminal desta instalacao, lido de SISWEB\TERMINAL no start.
    // Convencao: 0 = Servidor Local/Base unica; 1..N = PDVs. Vai em TODOS os
    // payloads de movimento (LcSendWeb.Terminal em un_send_to_web_server).
    GbTerminal  : Integer;
  end;

var
  DM: TDM;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

uses uMain, un_funcoes, un_sistema, un_sincronia_seed, UnFunctions;

{$R *.dfm}

procedure TDM.AtivaTrigger(op: Boolean);
begin
  if op then
  Begin
    DM.ExecComando(concat(
          'update RDB$TRIGGERS set RDB$TRIGGER_INACTIVE = 0 ',
          'where rdb$trigger_source is not null and ((rdb$system_flag = 0) or ',
          '(rdb$system_flag is null)) '
    ));
  End
  else
  Begin
    DM.ExecComando(concat(
          'update rdb$triggers ',
          'set rdb$trigger_inactive = 1 ',
          'where ',
          '    rdb$trigger_source is not null ',
          '   and (coalesce(rdb$system_flag,0) = 0) ',
          '    and rdb$trigger_source not starting with ''CHECK''  '
    ));
  End;
end;

procedure TDM.ConectaBancoLocal;
var
   LcPAth : String;
begin
  // Secao unificada com a tela de configuracao (tas_config grava em [SISWEB];
  // a leitura antiga em [SINCRONIA] fazia o path vir vazio no start)
  LcPAth := Fc_Aq_Geral('L','SISWEB', 'BDPathBDLocal','');
  IBD_Gestao.Connected := False;
  IBD_Gestao.Params.Clear;
  IBD_Gestao.Params.Add('user_name=SYSDBA');
  IBD_Gestao.Params.Add('password=masterkey');
  IBD_Gestao.Params.Add('lc_ctype=WIN1252');
  IBD_Gestao.DatabaseName := LcPAth;
  Try
    IBD_Gestao.Connected := True;
  except
    BEgin
      IBD_Gestao.Connected := FAlse;
    End;
  End;
end;

procedure TDM.ConectaBancoServidor;
var
   Lc_Arq_Ini: TIniFile;
   LcPAth : String;
begin
  Lc_Arq_Ini := TIniFile.Create(getPathExe + 'config.ini');
  Try
    if ( Fc_Aq_Geral('L','SINCRONIA', 'ReceiveLocalServer','S') = 'S')  then
    Begin
      LcPAth := Lc_Arq_Ini.ReadString('SINCRONIA', 'BDPathBDServidor','');
      if FileExists(LcPAth) then
      Begin
        IBD_Servidor.Connected := False;
        IBD_Servidor.Params.Clear;
        IBD_Servidor.Params.Add('user_name=SYSDBA');
        IBD_Servidor.Params.Add('password=masterkey');
        IBD_Servidor.Params.Add('lc_ctype=WIN1252');
        IBD_Servidor.DatabaseName := LcPAth;
        Try
          IBD_Servidor.Connected := True
        Except
          IBD_Servidor.Connected := False;
        End;
      End;
    End;
  Finally
    Lc_Arq_Ini.DisposeOf;
  End;
end;

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  BootstrapOk := False;
  // Decisao 1 do indexador terminal: fonte = registro SISWEB\TERMINAL
  // (mesma secao de FApiKey/FPathURL; tela de config ja grava a chave).
  GbTerminal := StrToIntDef(Fc_Aq_Geral('L', 'SISWEB', 'TERMINAL', '0'), 0);
  ConectaBancoLocal;
  ConectaBancoServidor;
  // Bootstrap completo do banco do cliente sem SQL manual (decisoes 1-10) -
  // so roda se o banco local conectou; falha mantem BootstrapOk = False e a
  // sincronizacao fica bloqueada (gate no uMain), sem derrubar o app.
  if IBD_Gestao.Connected then
  Begin
    try
      EnsureSincronia;
    except
      on E: Exception do
        GeralogCrashlytics('TDM.EnsureSincronia', E.Message);
    end;
  End;
end;

procedure TDM.DataModuleDestroy(Sender: TObject);
begin
  IBD_Gestao.Close;
  IBD_Servidor.Close;
end;

procedure TDM.ExecComando(SqlTxt: String);
begin
  ExecComandoRet(SqlTxt);
end;

function TDM.ExecComandoRet(SqlTxt: String): Integer;
begin
  with Qr_Crud do
  Begin
    if not Transaction.InTransaction then Transaction.StartTransaction;
    active := False;
    sql.Clear;
    SQL.Add(SqlTxt);
    ExecSQL;
    Result := RowsAffected;
    if Transaction.InTransaction then Transaction.Commit;
    Close;
  End;
end;

procedure TDM.ExecConsulta(SqlTxt: String);
begin
  with Qr_Crud do
  Begin
    if Transaction.InTransaction then Transaction.CommitRetaining;
    close;
    sql.Clear;
    SQL.Add(SqlTxt);
    Active := True;
    FetchAll;
    First;
  End;
end;


{ ---------------------------------------------------------------------
  Bootstrap do banco do cliente (prompt_construcao_banco_cliente.md).
  Roda a cada start do Sincronizador (DataModuleCreate); idempotente:
  cada passo verifica os metadados (RDB$) antes de agir.
  Compatibilidade: todo DDL e valido no Firebird 2.5 E 5.0 (decisao 10) -
  sem IDENTITY, sem BOOLEAN, generator via GEN_ID.
  --------------------------------------------------------------------- }

function TDM.TabelaExiste(const ANomeTabela: String): Boolean;
begin
  ExecConsulta(
    'SELECT COUNT(*) AS QTDE FROM RDB$RELATIONS ' +
    'WHERE UPPER(RDB$RELATION_NAME) = ''' + UpperCase(ANomeTabela) + ''' ' +
    'AND RDB$SYSTEM_FLAG = 0'
  );
  Result := Qr_Crud.FieldByName('QTDE').AsInteger > 0;
end;

function TDM.TabelaVazia(const ANomeTabela: String): Boolean;
begin
  ExecConsulta('SELECT COUNT(*) AS QTDE FROM ' + ANomeTabela);
  Result := Qr_Crud.FieldByName('QTDE').AsInteger = 0;
end;

function TDM.CampoExiste(const ANomeTabela, ANomeCampo: String): Boolean;
begin
  ExecConsulta(
    'SELECT COUNT(*) AS QTDE FROM RDB$RELATION_FIELDS ' +
    'WHERE UPPER(TRIM(RDB$RELATION_NAME)) = ''' + UpperCase(ANomeTabela) + ''' ' +
    'AND UPPER(TRIM(RDB$FIELD_NAME)) = ''' + UpperCase(ANomeCampo) + ''''
  );
  Result := Qr_Crud.FieldByName('QTDE').AsInteger > 0;
end;

function TDM.GeneratorExiste(const ANomeGenerator: String): Boolean;
begin
  ExecConsulta(
    'SELECT COUNT(*) AS QTDE FROM RDB$GENERATORS ' +
    'WHERE UPPER(TRIM(RDB$GENERATOR_NAME)) = ''' + UpperCase(ANomeGenerator) + ''''
  );
  Result := Qr_Crud.FieldByName('QTDE').AsInteger > 0;
end;

function TDM.TriggerExiste(const ANomeTrigger: String): Boolean;
begin
  // Firebird 2.5/5.0: nao existe DROP TRIGGER IF EXISTS — verifica nos
  // metadados antes (mesmo padrao de TabelaExiste/GeneratorExiste).
  ExecConsulta(
    'SELECT COUNT(*) AS QTDE FROM RDB$TRIGGERS ' +
    'WHERE UPPER(TRIM(RDB$TRIGGER_NAME)) = ''' + UpperCase(ANomeTrigger) + ''' ' +
    'AND COALESCE(RDB$SYSTEM_FLAG,0) = 0'
  );
  Result := Qr_Crud.FieldByName('QTDE').AsInteger > 0;
end;

{ Passo 1 - TB_SINCRONIA + GN_SINCRONIA + TG_SINCRONIA (decisao 2 - DDL
  autoritativa fornecida pelo Valdo). }
procedure TDM.EnsureSincroniaTable;
begin
  if not GeneratorExiste('GN_SINCRONIA') then
    ExecComando('CREATE GENERATOR GN_SINCRONIA');

  if not TabelaExiste('TB_SINCRONIA') then
    ExecComando(
      'CREATE TABLE TB_SINCRONIA (' +
      'SRC_CODIGO    INTEGER NOT NULL, ' +
      'SRC_TABELA    VARCHAR(30), ' +
      'SRC_CHAVE     VARCHAR(30), ' +
      'SRC_OPER      CHAR(1), ' +
      'SRC_TIME      TIMESTAMP, ' +
      'SRC_REGISTRO  INTEGER, ' +
      'SRC_LOG       VARCHAR(255), ' +
      'CONSTRAINT PK_TB_SINCRONIA PRIMARY KEY (SRC_CODIGO))'
    );

  // CREATE OR ALTER = idempotente nas duas versoes
  ExecComando(
    'CREATE OR ALTER TRIGGER TG_SINCRONIA FOR TB_SINCRONIA ' +
    'ACTIVE BEFORE INSERT POSITION 0 ' +
    'AS BEGIN NEW.SRC_CODIGO = GEN_ID(GN_SINCRONIA, 1); END'
  );
end;

{ TB_SYNC_TABLE: NUNCA tocar (decisao 4 do prompt_indexador_terminal_pdv.md,
  2026-07-26 — REVERTE a decisao 1 do bootstrap). Ela e checkpoint vivo da
  RETAGUARDA do Gestao2016 (ControllerRetaguardaSendToLocal/Un_Funcoes.
  updateTableSync); o Sincronizador nao a usa, mas dropa-la destruia a
  sincronia local Servidor x PDVs. O checkpoint DESTE processo segue em
  TB_LISTA_SINCRONIA.LAST_UPDATE. }

procedure TDM.EnsureListaSincroniaTable;
begin
  if not TabelaExiste('TB_LISTA_SINCRONIA') then
  Begin
    try
      ExecComando(
        'CREATE TABLE TB_LISTA_SINCRONIA (' +
        'WAY VARCHAR(1) NOT NULL, ' +
        'DESC_TABELA VARCHAR(60) NOT NULL, ' +
        'KIND VARCHAR(20) NOT NULL, ' +
        'DESC_PROCESS VARCHAR(100), ' +
        'SEQ INTEGER, ' +
        'DESC_FIELD VARCHAR(60), ' +
        'DESC_TRIGGER VARCHAR(60), ' +
        'NOTE VARCHAR(255), ' +
        'SET_ON VARCHAR(1), ' +
        'CLASS_NAME VARCHAR(100), ' +
        'END_POINT VARCHAR(200), ' +
        'LAST_UPDATE TIMESTAMP, ' +
        'CONSTRAINT PK_LISTA_SINCRONIA PRIMARY KEY (WAY, DESC_TABELA, KIND))'
      );
    except
      on E: Exception do
        // corrida entre instancias/terminais iniciando ao mesmo tempo: se
        // outro processo ja criou a tabela, ignora; qualquer outro erro sobe
        if Pos('already exist', LowerCase(E.Message)) = 0 then raise;
    end;
  End;
  // Bancos criados antes da decisao 3 ganham a coluna de checkpoint
  if not CampoExiste('TB_LISTA_SINCRONIA','LAST_UPDATE') then
    ExecComando('ALTER TABLE TB_LISTA_SINCRONIA ADD LAST_UPDATE TIMESTAMP');
end;

procedure TDM.SeedListaSincroniaIfEmpty;
Var
  I   : Integer;
  Row : TSincroniaSeedRow;
begin
  // Modulo restaurante REMOVIDO do catalogo (Valdo, 2026-07-26): alem de
  // nao semear, bancos ja semeados perdem as 7 linhas TB_REST_* aqui
  // (idempotente - roda a cada start, DELETE de 0 linhas e no-op).
  ExecComando('DELETE FROM TB_LISTA_SINCRONIA WHERE DESC_TABELA LIKE ''TB_REST_%''');

  // Rodada 2 — Sincronia por PROCESSO (D8/D11 de prompt_notas_mercadoria_
  // servico.md, 2026-07-27): TB_PEDIDO saiu da fila e a NOTA_MERCADORIA
  // intermediaria tambem — bancos ja semeados perdem as 5 linhas aqui
  // (mesmo padrao TB_REST_*). ATENCAO: o DELETE e por TABELA/KIND, NUNCA
  // por SEQ — a renumeracao de 2026-07-27 REUTILIZOU o Seq 21 antigo da
  // NOTA_MERCADORIA para a NOTA_SERVICO (deletar por SEQ mataria a linha
  // nova no start seguinte). As linhas NOVAS (22/23/24) NAO sao
  // ressemeadas (o seed so roda com a tabela vazia) — INSERT manual
  // documentado no patch 07; o SEQ, esse sim, e imposto pelo
  // EnforceSeqCatalogo abaixo.
  ExecComando('DELETE FROM TB_LISTA_SINCRONIA WHERE DESC_TABELA = ''TB_PEDIDO''');
  ExecComando(
    'DELETE FROM TB_LISTA_SINCRONIA ' +
    'WHERE DESC_TABELA = ''TB_NOTA_FISCAL'' AND KIND = ''NOTA_MERCADORIA''');
  // O trigger de captura de TB_PEDIDO morre junto (D8). Nome real gerado
  // pelo EnsureTriggers: TG_SRC_PEDIDO (prefixo TB_ removido) — com as
  // linhas fora do catalogo ele nao e recriado.
  if TriggerExiste('TG_SRC_PEDIDO') then
    ExecComando('DROP TRIGGER TG_SRC_PEDIDO');
  // Fila orfa: sem KIND de TB_PEDIDO no catalogo, linhas pendentes dessa
  // tabela nunca mais seriam consumidas — remove de vez (D13 estendeu a
  // limpeza diaria para QUALQUER registro > 48h, mas aqui sai na hora).
  ExecComando('DELETE FROM TB_SINCRONIA WHERE SRC_TABELA = ''TB_PEDIDO''');

  if not TabelaVazia('TB_LISTA_SINCRONIA') then
  Begin
    // Banco ja semeado: impoe o SEQ canonico por (WAY, DESC_TABELA, KIND)
    // — renumeracao de 2026-07-27 aplicada SOZINHA, sem SQL manual.
    EnforceSeqCatalogo;
    Exit;
  End;

  with Qr_Acao do
  Begin
    Database    := IBD_Gestao;
    Transaction := IBD_Gestao.DefaultTransaction;
    if not Transaction.InTransaction then Transaction.StartTransaction;
    try
      SQL.Text :=
        'INSERT INTO TB_LISTA_SINCRONIA ' +
        '(WAY, DESC_TABELA, KIND, DESC_PROCESS, SEQ, DESC_FIELD, DESC_TRIGGER, NOTE, SET_ON, CLASS_NAME, END_POINT) ' +
        'VALUES (:WAY, :DESC_TABELA, :KIND, :DESC_PROCESS, :SEQ, :DESC_FIELD, :DESC_TRIGGER, :NOTE, :SET_ON, :CLASS_NAME, :END_POINT)';
      Prepare;
      for I := Low(SINCRONIA_SEED) to High(SINCRONIA_SEED) do
      Begin
        Row := SINCRONIA_SEED[I];
        ParamByName('WAY').AsString          := Row.Way;
        ParamByName('DESC_TABELA').AsString  := Row.DescTabela;
        ParamByName('KIND').AsString         := Row.Kind;
        ParamByName('DESC_PROCESS').AsString := Row.DescProcess;
        ParamByName('SEQ').AsInteger         := Row.Seq;
        if Row.DescField <> '' then
          ParamByName('DESC_FIELD').AsString := Row.DescField
        else
          ParamByName('DESC_FIELD').Clear;
        // Nenhum nome real de trigger confirmado no codigo - ver MAPA_INDEXACAO.md
        ParamByName('DESC_TRIGGER').Clear;
        ParamByName('NOTE').AsString       := Row.Note;
        ParamByName('SET_ON').AsString     := Row.SetOn;
        ParamByName('CLASS_NAME').AsString := Row.ClassName;
        if Row.EndPoint <> '' then
          ParamByName('END_POINT').AsString := Row.EndPoint
        else
          ParamByName('END_POINT').Clear;
        ExecSQL;
      End;
      Transaction.Commit;
    except
      on E: Exception do
      Begin
        if Transaction.InTransaction then Transaction.Rollback;
        raise;
      End;
    end;
  End;

  // Perfil PDV (decisao 3 do indexador terminal): em terminal <> 0 os
  // CADASTROS nascem desligados - eles chegam ao PDV pela retaguarda e
  // seriam reenvio redundante; o PDV sincroniza so MOVIMENTO (Seqs 20-33).
  // Aplicado apenas no seed inicial (base recem-preparada); reativacao
  // manual via UPDATE continua possivel.
  // Reordenacao 2026-07-27 (usuario -> Seq 1; cadastros -> 2-17; carrier e
  // servico -> 18/19, antes das notas): o filtro virou "tudo que NAO e o
  // bloco de movimento" — robusto a renumeracoes de cadastro.
  if GbTerminal <> 0 then
    ExecComando(
      'UPDATE TB_LISTA_SINCRONIA SET SET_ON = ''N'' ' +
      'WHERE ( SEQ NOT BETWEEN 20 AND 33 )'
    );
end;

{ Renumeracao do catalogo (Valdo, 2026-07-27): a cada start, o SEQ de cada
  linha do catalogo canonico (un_sincronia_seed.pas) e imposto ao banco por
  (WAY, DESC_TABELA, KIND) — a chave real da mecanica. Bancos ja semeados
  se renumeram SOZINHOS, sem SQL manual de UPDATE.
  FASE UNICA (sem SEQ = SEQ + 1000 intermediario): a PK da tabela e
  (WAY, DESC_TABELA, KIND) e SEQ nao tem PK/UNIQUE/index — duplicidade
  transitoria de SEQ durante o loop nao viola constraint nenhuma e ao final
  todos os SEQs canonicos sao unicos. UPDATE de 0 linhas quando ja esta
  certo = no-op idempotente; interrompido no meio, o proximo start conclui. }
procedure TDM.EnforceSeqCatalogo;
Var
  I   : Integer;
  Row : TSincroniaSeedRow;
begin
  for I := Low(SINCRONIA_SEED) to High(SINCRONIA_SEED) do
  Begin
    Row := SINCRONIA_SEED[I];
    ExecComando(
      'UPDATE TB_LISTA_SINCRONIA SET SEQ = ' + IntToStr(Row.Seq) + ' ' +
      'WHERE WAY = ''' + Row.Way + ''' ' +
      'AND DESC_TABELA = ''' + Row.DescTabela + ''' ' +
      'AND KIND = ''' + Row.Kind + ''' ' +
      'AND COALESCE(SEQ, -1) <> ' + IntToStr(Row.Seq)
    );
  End;
end;

{ Passo 5 - soft delete universal (decisao 8): DELETED CHAR(1) DEFAULT 'N'
  em TODAS as tabelas de usuario, exceto as 2 de controle. O backfill e
  necessario porque na 2.5 o DEFAULT nao retroage aos registros existentes. }
procedure TDM.EnsureDeletedColumns;
Var
  LcTabelas : TStringList;
  I         : Integer;
begin
  LcTabelas := TStringList.Create;
  try
    ExecConsulta(
      'SELECT TRIM(RDB$RELATION_NAME) AS NOME FROM RDB$RELATIONS ' +
      'WHERE COALESCE(RDB$SYSTEM_FLAG,0) = 0 AND RDB$VIEW_BLR IS NULL ' +
      'AND UPPER(TRIM(RDB$RELATION_NAME)) NOT IN (''TB_SINCRONIA'',''TB_LISTA_SINCRONIA'')'
    );
    while not Qr_Crud.Eof do
    Begin
      LcTabelas.Add(Trim(Qr_Crud.FieldByName('NOME').AsString));
      Qr_Crud.Next;
    End;
    for I := 0 to LcTabelas.Count - 1 do
    Begin
      if not CampoExiste(LcTabelas[I],'DELETED') then
      Begin
        ExecComando('ALTER TABLE ' + LcTabelas[I] + ' ADD DELETED CHAR(1) DEFAULT ''N''');
        ExecComando('UPDATE ' + LcTabelas[I] + ' SET DELETED = ''N'' WHERE DELETED IS NULL');
      End;
    End;
  finally
    LcTabelas.DisposeOf;
  end;
end;

{ EXTERNALCODE em TB_EMPRESA (D4/D14 da revisao do sincronizador - UUID
  devolvido pela setes-sync p/ registros sem CPF/CNPJ). Incorporado ao
  bootstrap pela decisao 8 (supera o patch manual 01_firebird_ddl.sql). }
procedure TDM.EnsureExternalCode;
begin
  if not CampoExiste('TB_EMPRESA','EXTERNALCODE') then
  Begin
    ExecComando('ALTER TABLE TB_EMPRESA ADD EXTERNALCODE VARCHAR(36)');
    ExecComando('CREATE INDEX IDX_EMPRESA_EXTERNALCODE ON TB_EMPRESA (EXTERNALCODE)');
  End;
  // Decisao 1 da revisao de entidades (2026-07-25): colaborador sem CPF
  // tambem fecha o ciclo do externalCode (TB_COLABORADOR e independente
  // da TB_EMPRESA).
  if not CampoExiste('TB_COLABORADOR','EXTERNALCODE') then
  Begin
    ExecComando('ALTER TABLE TB_COLABORADOR ADD EXTERNALCODE VARCHAR(36)');
    ExecComando('CREATE INDEX IDX_COLABORADOR_EXTERNALCODE ON TB_COLABORADOR (EXTERNALCODE)');
  End;
  // Decisao 1 da indexacao de usuarios (2026-07-26): usuario SEM colaborador
  // (ex-funcionario inclusive) fecha o ciclo pelo proprio TB_USUARIO.
  if not CampoExiste('TB_USUARIO','EXTERNALCODE') then
  Begin
    ExecComando('ALTER TABLE TB_USUARIO ADD EXTERNALCODE VARCHAR(36)');
    ExecComando('CREATE INDEX IDX_USUARIO_EXTERNALCODE ON TB_USUARIO (EXTERNALCODE)');
  End;
end;

{ TB_CATEGORY local + GN_CATEGORY + TB_PRODUTO.PRO_CODCAT (conversao de
  categorias, Valdo 2026-08-01): o modelo novo categoriza produto por
  TB_CATEGORY (mesma forma da web - arvore por POSIT_LEVEL, caminho
  materializado '001.005'); TB_GRUPOS/TB_SUBGRUPOS ficam como legado. Em
  banco de cliente antigo nada disso existe - o bootstrap cria. DDL
  fornecida pelo Valdo; PK em ID (na web a PK e id+institution, mas o banco
  local e de UMA instalacao). Criada ANTES de EnsureTriggers para a
  TG_SRC_CATEGORY (catalogo Seq 3) nascer no mesmo start. }
procedure TDM.EnsureCategoryTable;
begin
  if not GeneratorExiste('GN_CATEGORY') then
    ExecComando('CREATE GENERATOR GN_CATEGORY');

  if not TabelaExiste('TB_CATEGORY') then
    ExecComando(
      'CREATE TABLE TB_CATEGORY (' +
      'ID               INTEGER NOT NULL, ' +
      'TB_INSTITUTE_ID  INTEGER NOT NULL, ' +
      'DESCRIPTION      VARCHAR(100) CHARACTER SET WIN1252 COLLATE WIN_PTBR, ' +
      'POSIT_LEVEL      VARCHAR(40) CHARACTER SET WIN1252 COLLATE WIN_PTBR, ' +
      'KIND             CHAR(1), ' +
      'ENABLED          VARCHAR(1), ' +
      'UPDATE_AT        TIMESTAMP, ' +
      'DELETED          CHAR(1) DEFAULT ''N'', ' +
      'CONSTRAINT PK_TB_CATEGORY PRIMARY KEY (ID))'
    );

  // O produto passa a apontar para a categoria nova (bancos legados nao
  // tem a coluna; o desktop novo ja nasce com ela)
  if TabelaExiste('TB_PRODUTO') and (not CampoExiste('TB_PRODUTO','PRO_CODCAT')) then
    ExecComando('ALTER TABLE TB_PRODUTO ADD PRO_CODCAT INTEGER');
end;

{ Passo 6 - triggers de captura TG_SRC_* (decisoes 5, 6 e 7): UMA trigger
  multi-evento por tabela (AFTER INSERT OR UPDATE, sem DELETE - exclusao
  fisica nao existe mais), gerada a partir de TB_LISTA_SINCRONIA
  (DESC_TABELA + DESC_FIELD, WAY='E', SET_ON='S'). O nome criado e gravado
  de volta em DESC_TRIGGER. }
procedure TDM.EnsureTriggers;
Var
  LcTabela  : String;
  LcCampo   : String;
  LcTrigger : String;
  LcNomeBase: String;
  LcLista   : TStringList;
  I         : Integer;
begin
  // Materializa a lista antes de executar DDL (Qr_Crud e reutilizado)
  LcLista := TStringList.Create;
  try
    ExecConsulta(
      'SELECT DISTINCT DESC_TABELA, DESC_FIELD FROM TB_LISTA_SINCRONIA ' +
      'WHERE WAY = ''E'' AND SET_ON = ''S'' ' +
      'AND DESC_FIELD IS NOT NULL AND DESC_FIELD <> '''''
    );
    while not Qr_Crud.Eof do
    Begin
      LcLista.Add(
        Trim(Qr_Crud.FieldByName('DESC_TABELA').AsString) + '=' +
        Trim(Qr_Crud.FieldByName('DESC_FIELD').AsString));
      Qr_Crud.Next;
    End;

    for I := 0 to LcLista.Count - 1 do
    Begin
      LcTabela := LcLista.Names[I];
      LcCampo  := LcLista.ValueFromIndex[I];
      if not TabelaExiste(LcTabela) then Continue; // tabela ainda nao existe neste banco

      // TG_SRC_EMPRESA para TB_EMPRESA; identificadores Firebird <= 31 chars
      LcNomeBase := LcTabela;
      if Pos('TB_', LcNomeBase) = 1 then Delete(LcNomeBase, 1, 3);
      LcTrigger := Copy('TG_SRC_' + LcNomeBase, 1, 31);

      // Corpo conforme decisao 7: INSERT grava NEW.<chave> com 'I',
      // UPDATE grava OLD.<chave> com 'U'; SRC_CODIGO=0 (TG_SINCRONIA gera).
      ExecComando(
        'CREATE OR ALTER TRIGGER ' + LcTrigger + ' FOR ' + LcTabela + ' ' +
        'ACTIVE AFTER INSERT OR UPDATE POSITION 0 ' +
        'AS BEGIN ' +
        'IF (INSERTING) THEN ' +
        'INSERT INTO TB_SINCRONIA (SRC_CODIGO, SRC_TABELA, SRC_CHAVE, SRC_OPER, SRC_REGISTRO, SRC_TIME) ' +
        'VALUES (0, ''' + LcTabela + ''', ''' + LcCampo + ''', ''I'', NEW.' + LcCampo + ', CURRENT_TIMESTAMP); ' +
        'ELSE ' +
        'INSERT INTO TB_SINCRONIA (SRC_CODIGO, SRC_TABELA, SRC_CHAVE, SRC_OPER, SRC_REGISTRO, SRC_TIME) ' +
        'VALUES (0, ''' + LcTabela + ''', ''' + LcCampo + ''', ''U'', OLD.' + LcCampo + ', CURRENT_TIMESTAMP); ' +
        'END'
      );

      ExecComando(
        'UPDATE TB_LISTA_SINCRONIA SET DESC_TRIGGER = ''' + LcTrigger + ''' ' +
        'WHERE WAY = ''E'' AND DESC_TABELA = ''' + LcTabela + ''''
      );
    End;
  finally
    LcLista.DisposeOf;
  end;
end;

type
  // Linha materializada da conversao grupo/subgrupo -> categoria
  TConvCategoriaRow = record
    Codigo    : Integer;  // GRP_CODIGO (grupo) ou SBG_CODIGO (subgrupo)
    GrupoCod  : Integer;  // SBG_CODGRP (0 na linha de grupo)
    Descricao : String;
    Ativo     : String;
    Deleted   : String;
    CatId     : Integer;  // preenchidos durante a conversao
    CatPath   : String;
  end;
  TConvCategoriaRows = array of TConvCategoriaRow;

  // Linha ja existente na TB_CATEGORY (checagem de sujeira do Passo 0)
  TCatExistenteRow = record
    Descricao : String;
    Nivel     : String;
  end;
  TCatExistenteRows = array of TCatExistenteRow;

{ Conversao TB_GRUPOS/TB_SUBGRUPOS -> TB_CATEGORY (Valdo, 2026-08-01):
  hierarquia de DOIS niveis - grupo vira categoria RAIZ (POSIT_LEVEL '001')
  e subgrupo vira FILHA do seu grupo ('001.005'; INNER JOIN GRP_CODIGO =
  SBG_CODGRP). Ids NOVOS via GN_CATEGORY - os codigos legados de grupo e
  subgrupo colidem entre si e nao servem de id. TB_PRODUTO.PRO_CODCAT e
  gravado na mesma passada e pode ser SUBSTITUIDO (Valdo, 2026-08-01: o
  campo nao esta em uso) - nivel 2 pelo subgrupo (PRO_CODSBG) e, para
  produto SO com grupo, a categoria raiz; o filtro <> nos UPDATEs so pula
  linha ja correta (idempotencia - UPDATE sem mudanca ainda dispararia a
  TG_SRC_PRODUTO e reencheria a fila a cada start).
  Idempotente por DESCRICAO (raiz = POSIT_LEVEL sem ponto; filha = debaixo
  do caminho do pai - mesma mecanica do getAutoCreateBy* do
  ControllerDskCategory): roda a cada start e converte tambem grupos que o
  desktop legado criar depois. LIMPEZA PREVIA (Passo 0, Valdo 2026-08-04):
  linha que a conversao nao produziria = tabela suja -> zera TB_CATEGORY +
  PRO_CODCAT + generator e reconverte do zero; tabela conforme passa ilesa. Roda DEPOIS de EnsureTriggers de proposito:
  INSERT/UPDATE caem na TB_SINCRONIA e a web recebe categorias e produtos
  no ciclo normal (raizes inserem antes das filhas; catalogo Seq 3
  [category] < Seq 6 [produto]). }
procedure TDM.MigraGruposParaCategoria;
Var
  LcGrupos  : TConvCategoriaRows;
  LcSubs    : TConvCategoriaRows;
  LcCats    : TCatExistenteRows;
  I, J, K   : Integer;
  LcPaiIdx  : Integer;
  LcCatId   : Integer;
  LcPath    : String;
  LcSujeira : Boolean;
  LcAchou   : Boolean;
  LcPaiDesc : String;

  function ContaPontos(const pNivel: String): Integer;
  Var
    P: Integer;
  begin
    Result := 0;
    for P := 1 to Length(pNivel) do
      if pNivel[P] = '.' then Inc(Result);
  end;

  function ProximoId: Integer;
  begin
    ExecConsulta('SELECT GEN_ID(GN_CATEGORY, 1) AS ID FROM RDB$DATABASE');
    Result := Qr_Crud.FieldByName('ID').AsInteger;
  end;

  procedure InsereCategoria(pId: Integer; const pDescricao, pPath, pAtivo, pDeleted: String);
  begin
    with Qr_Acao do
    Begin
      Database    := IBD_Gestao;
      Transaction := IBD_Gestao.DefaultTransaction;
      if not Transaction.InTransaction then Transaction.StartTransaction;
      try
        SQL.Text :=
          'INSERT INTO TB_CATEGORY ' +
          '(ID, TB_INSTITUTE_ID, DESCRIPTION, POSIT_LEVEL, KIND, ENABLED, UPDATE_AT, DELETED) ' +
          'VALUES (:ID, 1, :DESCRIPTION, :POSIT_LEVEL, ''P'', :ENABLED, CURRENT_TIMESTAMP, :DELETED)';
        // TB_INSTITUTE_ID = 1: valor LOCAL (mesmo das rotinas existentes -
        // tas_config/Fc_GrupoToCategoria); nao viaja no /category/sincronize
        // (D12 - o servidor deriva a institution da API key). KIND 'P' =
        // arvore de produtos.
        ParamByName('ID').AsInteger         := pId;
        ParamByName('DESCRIPTION').AsString := pDescricao;
        ParamByName('POSIT_LEVEL').AsString := pPath;
        if Trim(pAtivo) = 'N' then
          ParamByName('ENABLED').AsString := 'N'
        else
          ParamByName('ENABLED').AsString := 'S';
        if Trim(pDeleted) = 'S' then
          ParamByName('DELETED').AsString := 'S'
        else
          ParamByName('DELETED').AsString := 'N';
        ExecSQL;
        Transaction.Commit;
      except
        on E: Exception do
        Begin
          if Transaction.InTransaction then Transaction.Rollback;
          raise;
        End;
      end;
    End;
  end;

begin
  // Perfil PDV (decisao 3 do indexador terminal): quem converte e o
  // SERVIDOR LOCAL (terminal 0). No PDV a conversao criaria ids proprios
  // via GN_CATEGORY e colidiria com o que a retaguarda do Gestao2016
  // replicar (mesma pendencia da replicacao de EXTERNALCODE - Q8).
  if GbTerminal <> 0 then Exit;

  // Instalacao ja nascida no modelo novo (sem legado): nada a converter
  if not TabelaExiste('TB_GRUPOS') then Exit;

  // Materializa as listas ANTES de qualquer lookup (Qr_Crud e reutilizado)
  ExecConsulta(
    'SELECT GRP_CODIGO, GRP_DESCRICAO, GRP_ATIVO, DELETED FROM TB_GRUPOS ' +
    'WHERE GRP_DESCRICAO IS NOT NULL AND TRIM(GRP_DESCRICAO) <> '''' ' +
    'ORDER BY GRP_CODIGO'
  );
  SetLength(LcGrupos, 0);
  while not Qr_Crud.Eof do
  Begin
    SetLength(LcGrupos, Length(LcGrupos) + 1);
    with LcGrupos[High(LcGrupos)] do
    Begin
      Codigo    := Qr_Crud.FieldByName('GRP_CODIGO').AsInteger;
      GrupoCod  := 0;
      Descricao := Trim(Qr_Crud.FieldByName('GRP_DESCRICAO').AsString);
      Ativo     := Trim(Qr_Crud.FieldByName('GRP_ATIVO').AsString);
      Deleted   := Trim(Qr_Crud.FieldByName('DELETED').AsString);
      CatId     := 0;
      CatPath   := '';
    End;
    Qr_Crud.Next;
  End;
  if Length(LcGrupos) = 0 then Exit;

  SetLength(LcSubs, 0);
  if TabelaExiste('TB_SUBGRUPOS') then
  Begin
    ExecConsulta(
      'SELECT S.SBG_CODIGO, S.SBG_CODGRP, S.SBG_DESCRICAO, S.SBG_ATIVO, S.DELETED ' +
      'FROM TB_SUBGRUPOS S ' +
      'INNER JOIN TB_GRUPOS G ON (G.GRP_CODIGO = S.SBG_CODGRP) ' +
      'WHERE S.SBG_DESCRICAO IS NOT NULL AND TRIM(S.SBG_DESCRICAO) <> '''' ' +
      'ORDER BY S.SBG_CODGRP, S.SBG_CODIGO'
    );
    while not Qr_Crud.Eof do
    Begin
      SetLength(LcSubs, Length(LcSubs) + 1);
      with LcSubs[High(LcSubs)] do
      Begin
        Codigo    := Qr_Crud.FieldByName('SBG_CODIGO').AsInteger;
        GrupoCod  := Qr_Crud.FieldByName('SBG_CODGRP').AsInteger;
        Descricao := Trim(Qr_Crud.FieldByName('SBG_DESCRICAO').AsString);
        Ativo     := Trim(Qr_Crud.FieldByName('SBG_ATIVO').AsString);
        Deleted   := Trim(Qr_Crud.FieldByName('DELETED').AsString);
        CatId     := 0;
        CatPath   := '';
      End;
      Qr_Crud.Next;
    End;
  End;

  { Passo 0 - limpeza previa (Valdo, 2026-08-04): a conversao so confia em
    TB_CATEGORY que ELA mesma produziu. Qualquer linha que a conversao nao
    geraria - raiz que nao e grupo, filha que nao e subgrupo do seu grupo,
    3+ niveis, duplicata, POSIT_LEVEL vazio (restos da rotina antiga do
    tas_config, testes ou grupo renomeado no legado) - zera a tabela, o
    PRO_CODCAT e o generator e reconverte do zero. Tabela ja conforme passa
    ILESA: limpar a cada start trocaria os ids e reencheria a fila (mesmo
    principio do <> dos UPDATEs). O DELETE nao dispara trigger (TG_SRC_*
    nao captura DELETE) - quem viaja para a web e a reconversao. }
  SetLength(LcCats, 0);
  ExecConsulta('SELECT DESCRIPTION, POSIT_LEVEL FROM TB_CATEGORY');
  while not Qr_Crud.Eof do
  Begin
    SetLength(LcCats, Length(LcCats) + 1);
    with LcCats[High(LcCats)] do
    Begin
      Descricao := Trim(Qr_Crud.FieldByName('DESCRIPTION').AsString);
      Nivel     := Trim(Qr_Crud.FieldByName('POSIT_LEVEL').AsString);
    End;
    Qr_Crud.Next;
  End;

  LcSujeira := False;
  for I := 0 to High(LcCats) do
  Begin
    if (LcCats[I].Descricao = '') or (LcCats[I].Nivel = '') or
       (ContaPontos(LcCats[I].Nivel) > 1) then
      LcSujeira := True
    else if ContaPontos(LcCats[I].Nivel) = 0 then
    Begin
      // Raiz: precisa corresponder a um grupo e nao ter duplicata
      LcAchou := False;
      for J := 0 to High(LcGrupos) do
        if UpperCase(LcGrupos[J].Descricao) = UpperCase(LcCats[I].Descricao) then
        Begin
          LcAchou := True;
          Break;
        End;
      if not LcAchou then LcSujeira := True;
      for K := 0 to I - 1 do
        if (ContaPontos(LcCats[K].Nivel) = 0) and
           (UpperCase(LcCats[K].Descricao) = UpperCase(LcCats[I].Descricao)) then
          LcSujeira := True;
    End
    else
    Begin
      // Filha: o pai (path antes do ponto) tem que ser uma raiz existente
      // cujo grupo tenha subgrupo com esta descricao; sem duplicata sob o pai
      LcPath    := Copy(LcCats[I].Nivel, 1, Pos('.', LcCats[I].Nivel) - 1);
      LcPaiDesc := '';
      for K := 0 to High(LcCats) do
        if LcCats[K].Nivel = LcPath then
        Begin
          LcPaiDesc := LcCats[K].Descricao;
          Break;
        End;
      LcPaiIdx := -1;
      for J := 0 to High(LcGrupos) do
        if (LcPaiDesc <> '') and
           (UpperCase(LcGrupos[J].Descricao) = UpperCase(LcPaiDesc)) then
        Begin
          LcPaiIdx := J;
          Break;
        End;
      LcAchou := False;
      if LcPaiIdx >= 0 then
        for J := 0 to High(LcSubs) do
          if (LcSubs[J].GrupoCod = LcGrupos[LcPaiIdx].Codigo) and
             (UpperCase(LcSubs[J].Descricao) = UpperCase(LcCats[I].Descricao)) then
          Begin
            LcAchou := True;
            Break;
          End;
      if not LcAchou then LcSujeira := True;
      for K := 0 to I - 1 do
        if (ContaPontos(LcCats[K].Nivel) = 1) and
           (Copy(LcCats[K].Nivel, 1, Pos('.', LcCats[K].Nivel) - 1) = LcPath) and
           (UpperCase(LcCats[K].Descricao) = UpperCase(LcCats[I].Descricao)) then
          LcSujeira := True;
    End;
    if LcSujeira then Break;
  End;

  if LcSujeira then
  Begin
    // PRO_CODCAT zera ANTES (o UPDATE dispara TG_SRC_PRODUTO - produto sem
    // grupo/subgrupo precisa levar o NULL a web; os demais sao regravados
    // nos Passos 2/3). Generator volta a 0 - ids novos e compactos.
    ExecComando('UPDATE TB_PRODUTO SET PRO_CODCAT = NULL WHERE PRO_CODCAT IS NOT NULL');
    ExecComando('DELETE FROM TB_CATEGORY');
    ExecComando('SET GENERATOR GN_CATEGORY TO 0');
  End;

  // Passo 1 - grupo vira (ou reencontra) categoria RAIZ
  for I := 0 to High(LcGrupos) do
  Begin
    ExecConsulta(
      'SELECT ID, POSIT_LEVEL FROM TB_CATEGORY ' +
      'WHERE UPPER(DESCRIPTION) = ' + QuotedStr(UpperCase(LcGrupos[I].Descricao)) + ' ' +
      'AND POSIT_LEVEL NOT LIKE ''%.%'' ' +
      'ORDER BY ID'
    );
    if not Qr_Crud.Eof then
    Begin
      LcGrupos[I].CatId   := Qr_Crud.FieldByName('ID').AsInteger;
      LcGrupos[I].CatPath := Trim(Qr_Crud.FieldByName('POSIT_LEVEL').AsString);
    End
    else
    Begin
      LcCatId := ProximoId;
      LcPath  := StrZero(LcCatId, 3, 0);
      InsereCategoria(LcCatId, LcGrupos[I].Descricao, LcPath,
                      LcGrupos[I].Ativo, LcGrupos[I].Deleted);
      LcGrupos[I].CatId   := LcCatId;
      LcGrupos[I].CatPath := LcPath;
    End;
  End;

  // Passo 2 - subgrupo vira filha do seu grupo + preenche PRO_CODCAT
  for J := 0 to High(LcSubs) do
  Begin
    LcPaiIdx := -1;
    for I := 0 to High(LcGrupos) do
      if LcGrupos[I].Codigo = LcSubs[J].GrupoCod then
      Begin
        LcPaiIdx := I;
        Break;
      End;
    if LcPaiIdx < 0 then Continue; // grupo pai sem descricao valida

    ExecConsulta(
      'SELECT ID FROM TB_CATEGORY ' +
      'WHERE UPPER(DESCRIPTION) = ' + QuotedStr(UpperCase(LcSubs[J].Descricao)) + ' ' +
      'AND POSIT_LEVEL LIKE ' + QuotedStr(LcGrupos[LcPaiIdx].CatPath + '.%') + ' ' +
      'ORDER BY ID'
    );
    if not Qr_Crud.Eof then
      LcCatId := Qr_Crud.FieldByName('ID').AsInteger
    else
    Begin
      LcCatId := ProximoId;
      LcPath  := LcGrupos[LcPaiIdx].CatPath + '.' + StrZero(LcCatId, 3, 0);
      InsereCategoria(LcCatId, LcSubs[J].Descricao, LcPath,
                      LcSubs[J].Ativo, LcSubs[J].Deleted);
    End;
    LcSubs[J].CatId := LcCatId;

    // PRO_CODCAT = categoria de NIVEL 2 (substituicao livre - campo nao
    // estava em uso); o <> evita UPDATE de linha ja certa (trigger)
    ExecComando(
      'UPDATE TB_PRODUTO SET PRO_CODCAT = ' + IntToStr(LcCatId) + ' ' +
      'WHERE PRO_CODSBG = ' + IntToStr(LcSubs[J].Codigo) + ' ' +
      'AND COALESCE(PRO_CODCAT, 0) <> ' + IntToStr(LcCatId)
    );
  End;

  // Passo 3 - produto SO com grupo (sem subgrupo) cai na categoria raiz
  for I := 0 to High(LcGrupos) do
    ExecComando(
      'UPDATE TB_PRODUTO SET PRO_CODCAT = ' + IntToStr(LcGrupos[I].CatId) + ' ' +
      'WHERE PRO_CODGRP = ' + IntToStr(LcGrupos[I].Codigo) + ' ' +
      'AND COALESCE(PRO_CODSBG, 0) = 0 ' +
      'AND COALESCE(PRO_CODCAT, 0) <> ' + IntToStr(LcGrupos[I].CatId)
    );
end;

procedure TDM.LimpaFilaSincroniaDoBootstrap;
begin
  // Roda por ULTIMO, sempre - independente do que a preparacao do banco
  // tenha enfileirado como efeito colateral (conversao de categoria,
  // qualquer futuro passo que grave em tabela com TG_SRC_*). Zera a fila
  // E o generator, para o proximo registro legitimo (Primeira Carga ou
  // alteracao real feita depois deste ponto) nascer com SRC_CODIGO=1.
  ExecComando('DELETE FROM TB_SINCRONIA');
  ExecComando('SET GENERATOR GN_SINCRONIA TO 0');
end;

procedure TDM.EnsureSincronia(pLimparFila: Boolean = False);
begin
  BootstrapOk := False;
  EnsureSincroniaTable;        // passo 1 - fila + generator + trigger da PK
  // passo 2 (DropSyncTable) REMOVIDO - decisao 4 do indexador terminal:
  // TB_SYNC_TABLE pertence a retaguarda do Gestao2016 e fica intocada
  EnsureListaSincroniaTable;   // passo 3 - catalogo + LAST_UPDATE
  SeedListaSincroniaIfEmpty;
  EnsureCategoryTable;         // TB_CATEGORY + GN + PRO_CODCAT (antes das triggers)
  EnsureDeletedColumns;        // passo 5 - decisao 8
  EnsureExternalCode;
  EnsureTriggers;              // passo 6 - decisoes 5/6/7
  // Passos CONDICIONAIS (Valdo, 2026-08-09 - 2a correcao no mesmo dia):
  // conversao de categoria E limpeza da fila SO rodam no clique manual de
  // "Preparar o banco" (MnuPreparaLocalClick, pLimparFila=True). O start
  // automatico (DataModuleCreate, todo open do Sincronizador) chama
  // EnsureSincronia SEM esse parametro (default False) e NAO deve tocar
  // em TB_CATEGORY/PRO_CODCAT nem na fila - MigraGruposParaCategoria
  // sozinha ja e capaz de enfileirar todo o catalogo de produto/categoria
  // (Passo 0 "sujeira"), e abrir o app nao pode ter esse efeito colateral.
  if pLimparFila then
  Begin
    MigraGruposParaCategoria;    // conversao grupo/subgrupo -> categoria (na fila)
    LimpaFilaSincroniaDoBootstrap; // por ultimo - zera o que a conversao enfileirou
  End;
  BootstrapOk := True;
end;

function TDM.GetDeletedFlag(const pTabela, pCampoChave: String; pCodigo: Integer): String;
begin
  Result := 'N';
  if pCodigo <= 0 then Exit;
  try
    ExecConsulta(
      'SELECT DELETED FROM ' + pTabela +
      ' WHERE ' + pCampoChave + ' = ' + IntToStr(pCodigo)
    );
    if (not Qr_Crud.Eof) and (Trim(Qr_Crud.FieldByName('DELETED').AsString) = 'S') then
      Result := 'S';
  except
    // coluna/tabela ausente (banco ainda nao preparado): trata como ativo
    Result := 'N';
  end;
end;

function TDM.GetDocumentByEmpCodigo(pCodigoEmpresa: Integer): String;
begin
  Result := '';
  if pCodigoEmpresa <= 0 then Exit;
  ExecConsulta(
    'SELECT EMP_CNPJ FROM TB_EMPRESA WHERE EMP_CODIGO = ' + IntToStr(pCodigoEmpresa)
  );
  if not Qr_Crud.Eof then
    Result := Trim(Qr_Crud.FieldByName('EMP_CNPJ').AsString);
  // Documento INVALIDO = SEM documento (2026-08-01, precedente da decisao 2
  // da revisao de entidades): CPF zerado/sentinela na referencia
  // (salesmanDocument/carrierDocument/...) fazia o vinculo falhar PARA
  // SEMPRE na web (409 *_NOT_SYNCED eterno) — sem documento, o movimento
  // viaja sem o vinculo, igual ao fallback do bloco user.
  if (Result <> '') and (not ValidaCPF_CNPJ(Result)) then
    Result := '';
end;

function TDM.GetNfsNumero(pCodNfl: Integer): String;
begin
  Result := '';
  if pCodNfl <= 0 then Exit;
  try
    ExecConsulta(
      'SELECT NFS_NUMERO FROM TB_RETORNO_NFS WHERE NFS_CODNFL = ' + IntToStr(pCodNfl)
    );
    if not Qr_Crud.Eof then
      Result := Trim(Qr_Crud.FieldByName('NFS_NUMERO').AsString);
  except
    // Tabela ausente (banco sem NFS-e - ex.: Pipoteca): segue vazio
    Result := '';
  end;
end;

function TDM.GetUserSyncRef(pUsuCodigo: Integer; var pDocumento, pExternalCode: String): Boolean;
Var
  LcDoc : String;
  LcExt : String;
begin
  Result := False;
  pDocumento := '';
  pExternalCode := '';
  if pUsuCodigo <= 0 then Exit;
  try
    // 1. Colaborador vinculado (TB_COLABORADOR.CLB_CODUSU)
    ExecConsulta(
      'SELECT CLB_CPF, EXTERNALCODE FROM TB_COLABORADOR ' +
      'WHERE CLB_CODUSU = ' + IntToStr(pUsuCodigo)
    );
    if not Qr_Crud.Eof then
    Begin
      LcDoc := unMaskField(Trim(Qr_Crud.FieldByName('CLB_CPF').AsString));
      if ((Length(LcDoc) = 11) and CalculoCpf(LcDoc)) or
         ((Length(LcDoc) = 14) and CalculoCnpj(LcDoc)) then
      Begin
        pDocumento := LcDoc;
        Exit(True);
      End;
      // Decisao 8 (PDV): EXTERNALCODE nao replica - so documento resolve la
      if GbTerminal <> 0 then Exit(False);
      LcExt := Trim(Qr_Crud.FieldByName('EXTERNALCODE').AsString);
      if LcExt <> '' then
      Begin
        pExternalCode := LcExt;
        Exit(True);
      End;
      // colaborador sem doc e ainda sem externalCode: segura o bloco ate o
      // /salesman sincronizar (auto-heal - decisao 2)
      Exit(False);
    End;
    // 2. Sem colaborador: EXTERNALCODE do proprio usuario (so no servidor)
    if GbTerminal <> 0 then Exit(False);
    ExecConsulta(
      'SELECT EXTERNALCODE FROM TB_USUARIO WHERE USU_CODIGO = ' + IntToStr(pUsuCodigo)
    );
    if not Qr_Crud.Eof then
    Begin
      LcExt := Trim(Qr_Crud.FieldByName('EXTERNALCODE').AsString);
      if LcExt <> '' then
      Begin
        pExternalCode := LcExt;
        Result := True;
      End;
    End;
  except
    // coluna/tabela ausente (banco ainda nao preparado): sem referencia
    Result := False;
  end;
end;

procedure TDM.setBDCrud(BD: TIBDatabase);
begin
  with Qr_Crud do
  Begin
    Active := False;
    Database := BD;
    Transaction := Bd.DefaultTransaction;
  End;
  with Qr_Acao do
  Begin
    Active := False;
    Database := BD;
    Transaction := Bd.DefaultTransaction;
  End;
  with IBSQL do
  Begin
    Database := BD;
    Transaction := Bd.DefaultTransaction;
  End;

end;

end.
