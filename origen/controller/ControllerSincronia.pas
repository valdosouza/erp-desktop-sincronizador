unit ControllerSincronia;

interface
uses IBX.IBDatabase,Classes, Vcl.Grids,IBQuery, SysUtils,ControllerBase,
      Un_sistema,Un_funcoes,Un_Regra_Negocio, tblSincronia ,ControllerDskRestMenu,
      Generics.Collections, ControllerEstoque;


Type
  // Renomeado de TListaSincronia (decisao 4): o nome agora pertence ao model
  // do catalogo TB_LISTA_SINCRONIA (tblListaSincronia.pas).
  TListaFilaSincronia = TObjectList<TSincronia>;

  TControllerSincronia = Class(TControllerBase)
  private
    FTipo: String;
    function getSqlAtualiza:String;
    function getSqlDeleta:String;

    function SqlPadraoAtualiza:String;
    function SqlPadraoDeleta:String;

    // Rodada 2 (D8 de prompt_notas_mercadoria_servico.md): TB_PEDIDO saiu
    // da fila de sincronia — SqlTBPedidoAtualiza/Deleta APOSENTADAS (a
    // NOTA e o unico fato gerador dos processos; Seqs 17/18/19/41 mortas).

    function SqlTBNotaFiscalAtualiza(Tipo:String):String;
    function SqlTBNotaFiscalDeleta(Tipo:String):String;

    function SqlTBProdutoAtualiza(Tipo:String):String;
    function SqlTBProdutoDeleta(Tipo:String):String;

    // D8/D11 (Rodada 2): KIND de NOTA do catalogo -> PED_TIPO numerico do
    // pedido conjugado (NOTA_VENDA/NOTA_SERVICO=1, NOTA_COMPRA=2,
    // NOTA_AJUSTE=3).
    function KindToPedTipo(const Kind:String):String;
    // D8/D11/D13: KINDs de nota que exigem o join com TB_PEDIDO (processo).
    function KindNotaProcesso(const Kind:String):Boolean;
    // D13 (Rodada 3): filtro DISJUNTO do conjugado no catch-up —
    // NOTA_SERVICO exige item de servico na nota; NOTA_VENDA exige a
    // ausencia dele (venda PURA). Demais KINDs: vazio.
    function SqlItemServico(const Kind:String):String;

    procedure setFTipo(const Value: String);


  protected

  public
    Registro : TSincronia;
    Lista :TListaFilaSincronia;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function save:boolean;
    function saveReturn:boolean;
    function insert:boolean;
    function update:boolean;
    procedure Clear;
    procedure getById;
    procedure getList;
    procedure getListProduto;
    procedure deleteAfterSyncProdutos;
    procedure deleteBeforeSyncProdutos;
    procedure deleteByTable;
    procedure deleteByTableRegistro;
    procedure getListTrayImage;
    procedure getListForRetaguarda;
    Function delete:boolean;
    function deleteAll:Boolean;
    procedure DeleteAfterRestMenu;
    // Limpeza automatica da fila (decisao 9; revisao do Valdo 2026-07-27):
    // remove SOMENTE registro com mais de 48 horas E envio OK (SRC_LOG='OK').
    // QUALQUER outra coisa PERMANECE para verificacao — erro, pendente e
    // orfao que nenhuma classe reivindica (ex.: PRO_TIPO='A', SRC_LOG null).
    // Disparada 1x por dia pelo loop do Sincronizador (ver uMain).
    procedure DeleteProcessadosAntigos;
    property Tipo : String read FTipo write setFTipo;
  End;

implementation

{ TControllerEmpresa }

procedure TControllerSincronia.Clear;
begin
  clearObj(Registro);
end;

constructor TControllerSincronia.Create(AOwner: TComponent);
begin
  inherited;
  Registro := TSincronia.Create;
  Lista := TListaFilaSincronia.Create;
end;

function TControllerSincronia.delete: boolean;
var
  Lc_Qry : TIBQuery;
begin
  Result := True;
  //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                    'DELETE ',
                    'FROM tb_sincronia ',
                    'WHERE ( SRC_TABELA   =:SRC_TABELA ) ',
                    ' AND  ( SRC_CHAVE    =:SRC_CHAVE ) ',
                    ' AND  ( SRC_REGISTRO =:SRC_REGISTRO ) '
      ));
      ParamByName('SRC_TABELA').AsString    := Registro.Tabela;
      ParamByName('SRC_CHAVE').AsString     := Registro.Chave;
      ParamByName('SRC_REGISTRO').AsInteger  := Registro.Registro;
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

procedure TControllerSincronia.deleteAfterSyncProdutos;
var
  Lc_Qry : TIBQuery;
begin
  //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                'DELETE FROM tb_sincronia ',
                'WHERE SRC_CODIGO IN( ',
                'select src_codigo ',
                'FROM tb_sincronia S ',
                'WHERE S.src_registro =:PRO_CODIGO ',
                'UNION ',
                'select src_codigo ',
                'FROM tb_sincronia S ',
                '   INNER JOIN tb_estoque E ',
                '   ON (E.est_codigo = S.src_registro) ',
                'WHERE e.est_codpro =:PRO_CODIGO ',
                'UNION ',
                'select src_codigo ',
                'FROM tb_sincronia S ',
                '   INNER JOIN tb_preco p ',
                '   ON (p.prc_codigo = S.src_registro) ',
                'WHERE p.prc_codpro =:PRO_CODIGO ',
                ')'
      ));
      ParamByName('PRO_CODIGO').AsInteger:= Registro.Registro;
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

function TControllerSincronia.deleteAll: Boolean;
var
  Lc_Qry : TIBQuery;
begin
  Result := True;
  //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                    'DELETE ',
                    'FROM tb_sincronia '
      ));
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;

end;

procedure TControllerSincronia.DeleteAfterRestMenu;
var
  I : Integer;
  Lc_RestMenu : TControllerDskRestMenu;
begin
  Lc_RestMenu := TControllerDskRestMenu.Create(nil);
  TRy
    Lc_RestMenu.Registro.Codigo := Self.Registro.Registro;
    Lc_RestMenu.getbyId;
    Lc_RestMenu.getListbyDescription;
    for I := 0 to Lc_RestMenu.Lista.Count -1 do
    Begin
      Self.registro.Tabela:= 'TB_PRODUTO';
      Self.registro.Registro := Lc_RestMenu.Lista[I].Codigo;
      self.deleteByTableRegistro;
    End;
  Finally
    Lc_RestMenu.DisposeOf;
  End;

end;

procedure TControllerSincronia.DeleteProcessadosAntigos;
var
  Lc_Qry : TIBQuery;
begin
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      // DATEADD funciona igual no Firebird 2.5 e 5.0 (decisao 10)
      // Revisao do Valdo (2026-07-27, pos-patch 08): apaga SO o que tem mais
      // de 48h E envio OK. Erro, pendente e orfao (ex.: PRO_TIPO='A',
      // SRC_LOG null) PERMANECEM na fila para verificacao.
      sql.add( concat(
                  'DELETE FROM tb_sincronia ',
                  'WHERE ( SRC_TIME < DATEADD(-48 HOUR TO CURRENT_TIMESTAMP) ) ',
                  'AND ( SRC_LOG = ''OK'' ) '
      ));
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

procedure TControllerSincronia.deleteBeforeSyncProdutos;
var
  Lc_Qry : TIBQuery;
begin
  //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                  'delete from tb_sincronia where src_codigo in ( ',
                  'select s.src_codigo ', //--, S.src_tabela, S.src_registro, s.src_time,LT.id
                  'FROM tb_sincronia s ',
                  '    inner join tb_produto pd ',
                  '    on (pd.pro_codigo = s.src_registro) ',
                  '    left outer join tb_loja_tray lt ',
                  '    on (lt.id = s.src_registro)and (lt.tabela  =''TB_PRODUTO'') ',
                  'WHERE s.src_tabela =''TB_PRODUTO'' ',
                  'and pd.pro_internet = ''N''  ',
                  'and lt.ID is null ',
                  'UNION ',
                  'select s.src_codigo ', //--, S.src_tabela, e.est_codpro src_registro, s.src_time ,LT.id
                  'FROM tb_sincronia s ',
                  '   INNER JOIN tb_estoque e ',
                  '   ON (e.est_codigo = s.src_registro) ',
                  '   inner join tb_produto pd ',
                  '    on (pd.pro_codigo = e.est_codpro) ',
                  '    left outer join tb_loja_tray lt ',
                  '    on (lt.id = s.src_registro) and (lt.tabela  =''TB_ESTOQUE'') ',
                  'WHERE s.src_tabela =''TB_ESTOQUE'' ',
                  'and pd.pro_internet = ''N'' ',
                  'and lt.ID is null ',
                  'UNION ',
                  'select s.src_codigo ', //--, S.src_tabela, pc.prc_codpro src_registro, s.src_time,LT.id
                  'FROM tb_sincronia s ',
                  '   INNER JOIN tb_preco pc ',
                  '   ON (pc.prc_codigo = s.src_registro) ',
                  '   inner join tb_produto pd ',
                  '   on (pd.pro_codigo = pc.prc_codpro) ',
                  '    left outer join tb_loja_tray lt ',
                  '    on (lt.id = s.src_registro) and (lt.tabela  =''TB_PRECO'') ',
                  'WHERE s.src_tabela = ''TB_PRECO'' ',
                  'and pd.pro_internet = ''N'' ',
                  'and lt.ID is null ',
                  ') '
      ));
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

procedure TControllerSincronia.deleteByTable;
var
  Lc_Qry : TIBQuery;
begin
  //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                  'delete from tb_sincronia  ',
                  'WHERE (src_tabela = :src_tabela) '
      ));
      ParamByName('src_tabela').AsString := Registro.Tabela;
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

procedure TControllerSincronia.deleteByTableRegistro;
var
  Lc_Qry : TIBQuery;
begin
  //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                  'delete from tb_sincronia  ',
                  'WHERE (src_tabela = :src_tabela) ',
                  ' and (SRC_REGISTRO=:SRC_REGISTRO) '
      ));
      ParamByName('src_tabela').AsString := Registro.Tabela;
      ParamByName('src_registro').AsInteger := Registro.Registro;
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;


end;

destructor TControllerSincronia.Destroy;
begin
  Lista.Clear;
  FreeAndNil(Lista);
  FreeAndNil(Registro);
  inherited;
end;



function TControllerSincronia.save: boolean;
begin
  Result := True;
  SaveObj(Registro);
end;

function TControllerSincronia.saveReturn: boolean;
var
  Lc_Qry : TIBQuery;
begin
  Result := True;
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin
      // D13 (Rodada 3 de prompt_notas_mercadoria_servico.md): a mecanica
      // '[KIND]' do patch 06 foi REMOVIDA (erro de entendimento) — a marca
      // no SRC_LOG e UNICA por registro e SO de quem ENVIA. Classe cujo
      // filtro nao casa NEM chega aqui (Skip no motor); os filtros
      // DISJUNTOS das classes/fila garantem que exatamente uma reivindica
      // cada registro (a conjugada viaja INTEIRA pela NOTA_SERVICO).
      sql.add( concat(
                'UPDATE TB_SINCRONIA s SET ',
                's.src_log =:src_log ',
                'WHERE s.src_registro=:src_registro ',
                'and s.SRC_TABELA =:SRC_TABELA '
          ));
      ParamByName('src_log').AsString := Registro.LogResult;
      ParamByName('SRC_TABELA').AsString := Registro.Tabela;
      ParamByName('src_registro').AsInteger := Registro.Registro;
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;

end;


procedure TControllerSincronia.setFTipo(const Value: String);
begin
  FTipo := Value;
end;

function TControllerSincronia.SqlPadraoAtualiza: String;
begin
  Result := concat(
              'SELECT ',
              '    SRC_REGISTRO, ',
              '    SRC_TABELA, ',
              '    SRC_CHAVE, ',
              '    MAX(SRC_TIME) SRC_TIME ',
              'FROM tb_sincronia s ',
//              'WHERE ( cast (substring( (cast (SRC_TIME as varchar(25))) from 1 for 19) as timeStamp) >=:SRC_TIME ) ',
              '  WHERE ( src_tabela =:SRC_TABELA ) ',
              '  and (SRC_OPER <> ''D'' ) ',
              '  and  ((SRC_LOG is null) or (SRC_LOG = ''''))  ',
              'GROUP BY 1,2,3 ',
              'ORDER BY 4 ASC '
      );
end;

function TControllerSincronia.SqlPadraoDeleta: String;
begin
  Result := concat(
              'SELECT ',
              '    SRC_REGISTRO, ',
              '    SRC_TABELA, ',
              '    SRC_CHAVE, ',
              '    MAX(SRC_TIME) SRC_TIME ',
              'FROM tb_sincronia s ',
//              'WHERE ( cast (substring( (cast (SRC_TIME as varchar(25))) from 1 for 19) as timeStamp) >=:SRC_TIME ) ',
              '  WHERE ( src_tabela =:SRC_TABELA ) ',
              '  and (SRC_OPER = ''D'' ) ',
              '  and  ((SRC_LOG is null) or (SRC_LOG = ''''))  ',
              'GROUP BY 1,2,3 ',
              'ORDER BY 4 ASC '
           );

end;



// Rodada 2 (D8/D11 de prompt_notas_mercadoria_servico.md): o catalogo grava
// o KIND de NOTA e o processo filtra pelo PED_TIPO do pedido conjugado
// (join por NFL_CODPED). D13: NOTA_SERVICO tambem e PED_TIPO=1 (dominio do
// legado — pedido de servico E venda).
function TControllerSincronia.KindToPedTipo(const Kind: String): String;
begin
  if Kind = 'NOTA_COMPRA' then
    Result := '2'
  else if Kind = 'NOTA_AJUSTE' then
    Result := '3'
  else
    Result := '1'; // NOTA_VENDA / NOTA_SERVICO
end;

// Rodada 2 (D8/D11) + Rodada 3 (D13): NOTA_VENDA/NOTA_COMPRA/NOTA_AJUSTE/
// NOTA_SERVICO sao processos por PED_TIPO — precisam do join com TB_PEDIDO
// no catch-up. So a NOTA_AVULSA (EM) fica de fora.
function TControllerSincronia.KindNotaProcesso(const Kind: String): Boolean;
begin
  Result := (Kind = 'NOTA_VENDA') or (Kind = 'NOTA_COMPRA') or
            (Kind = 'NOTA_AJUSTE') or (Kind = 'NOTA_SERVICO');
end;

// D13 (Rodada 3): o catch-up usa o MESMO filtro disjunto das classes —
// NOTA_SERVICO = nota COM item de servico (espelho do VerificaServico);
// NOTA_VENDA = nota SEM item de servico (venda PURA). EXISTS com subselect
// funciona igual no Firebird 2.5 e 5.0 (decisao 10 do bootstrap).
function TControllerSincronia.SqlItemServico(const Kind: String): String;
Const
  SQL_EXISTS = 'EXISTS (SELECT 1 FROM TB_ITENS_NFL IT ' +
               'INNER JOIN TB_PRODUTO PR ON (PR.PRO_CODIGO = IT.ITF_CODPRO) ' +
               'WHERE (IT.ITF_CODNFL = N.NFL_CODIGO) AND (PR.PRO_TIPO = ''S''))';
begin
  if Kind = 'NOTA_SERVICO' then
    Result := concat('  AND (', SQL_EXISTS, ') ')
  else if Kind = 'NOTA_VENDA' then
    Result := concat('  AND (NOT ', SQL_EXISTS, ') ')
  else
    Result := '';
end;

function TControllerSincronia.SqlTBNotaFiscalAtualiza(Tipo: String): String;
begin
  Result := concat(
              'SELECT ',
              '    SRC_REGISTRO, ',
              '    SRC_TABELA, ',
              '    SRC_CHAVE, ',
              '    MAX(SRC_TIME) SRC_TIME ',
              'FROM tb_sincronia s ',
              '    inner join TB_NOTA_FISCAL N ',
              '    on (N.NFL_codigo = s.src_registro) ');
  // Rodada 2 (D8/D11): NOTA_VENDA/NOTA_COMPRA/NOTA_AJUSTE diferenciam-se
  // pelo PED_TIPO do pedido conjugado — join por NFL_CODPED.
  if KindNotaProcesso(Tipo) then
    Result := concat(Result,
              '    inner join TB_PEDIDO P ',
              '    on (P.ped_codigo = N.nfl_codped) ');
  Result := concat(Result,
              '  WHERE ( src_tabela =:SRC_TABELA ) ',
              '  and (SRC_OPER <> ''D'' ) ',
              '  and  ((SRC_LOG is null) or (SRC_LOG = '''')) ');
  // D7 (prompt_notas_mercadoria_servico.md): o seed grava 'NOTA_AVULSA'
  // (nao 'AVULSA') — a comparacao antiga nunca casava e TODA nota caia no
  // ramo <> 'EM'. D13: os filtros por KIND abaixo sao DISJUNTOS (exatamente
  // uma classe reivindica cada registro — pendencia volta a ser simples).
  if ( Tipo = 'NOTA_AVULSA') then
  Begin
    Result := concat(Result,
                    '  AND (n.nfl_tipo = ''EM'') ');
  End
  else
  Begin
    Result := concat(Result,
                    '  AND (n.nfl_tipo <> ''EM'') ');
  End;
  if KindNotaProcesso(Tipo) then
    Result := concat(Result,
                    '  AND (p.ped_tipo = ', KindToPedTipo(Tipo), ') ');
  // D13: NOTA_SERVICO = COM item de servico x NOTA_VENDA = SEM (venda pura)
  Result := concat(Result, SqlItemServico(Tipo));
  Result := concat(Result,
                  'GROUP BY 1,2,3 ',
                  'ORDER BY 4 ASC ');

end;

function TControllerSincronia.SqlTBNotaFiscalDeleta(Tipo: String): String;
begin
  Result := concat(
              'SELECT ',
              '    SRC_REGISTRO, ',
              '    SRC_TABELA, ',
              '    SRC_CHAVE, ',
              '    MAX(SRC_TIME) SRC_TIME ',
              'FROM tb_sincronia s ',
              '    inner join TB_NOTA_FISCAL N ',
              '    on (N.NFL_codigo = s.src_registro) ');
  // Rodada 2 (D8/D11): mesma diferenciacao por PED_TIPO do Atualiza.
  if KindNotaProcesso(Tipo) then
    Result := concat(Result,
              '    inner join TB_PEDIDO P ',
              '    on (P.ped_codigo = N.nfl_codped) ');
  Result := concat(Result,
              '  WHERE ( src_tabela =:SRC_TABELA ) ',
              '  and (SRC_OPER = ''D'' ) ',
              '  and  ((SRC_LOG is null) or (SRC_LOG = '''')) ');
  // D7: o parametro e o KIND do catalogo (NOTA_AVULSA/NOTA_VENDA/
  // NOTA_COMPRA/NOTA_AJUSTE/NOTA_SERVICO), nao o NFL_TIPO.
  if ( Tipo = 'NOTA_AVULSA') then
  Begin
    Result := concat(Result,
                    '  AND (n.nfl_tipo = ''EM'') ');
  End
  else
  Begin
    Result := concat(Result,
                    '  AND (n.nfl_tipo <> ''EM'') ');
  End;
  if KindNotaProcesso(Tipo) then
    Result := concat(Result,
                    '  AND (p.ped_tipo = ', KindToPedTipo(Tipo), ') ');
  // D13: mesmo filtro disjunto do Atualiza (soft delete D2 — a linha da
  // nota continua no Firebird com DELETED='S', os joins seguem validos)
  Result := concat(Result, SqlItemServico(Tipo));
  Result := concat(Result,
                  'GROUP BY 1,2,3 ',
                  'ORDER BY 4 ASC ');

end;

// Rodada 2 (D8): SqlTBPedidoAtualiza/SqlTBPedidoDeleta APOSENTADAS —
// TB_PEDIDO saiu da fila (trigger TG_SRC_PEDIDO dropada pelo bootstrap;
// Seqs 17/18/19/41 deletadas do catalogo). Pedido editado apos o
// faturamento sem tocar a nota NAO reenvia — perda aceita (Q4).

function TControllerSincronia.SqlTBProdutoAtualiza(Tipo: String): String;
begin
  // Notas Mercadoria x Servico (D2): TB_PRODUTO passou a ter 2 KINDs no
  // catalogo (CADASTRO = P/M x SERVICO = S) — filtro DISJUNTO por PRO_TIPO
  // no molde do TB_PEDIDO, para uma classe nao consumir a fila da outra.
  // PRO_TIPO 'A' (cardapio, restaurante APOSENTADO) nao entra em nenhum KIND.
  Result := concat(
              'SELECT ',
              '    SRC_REGISTRO, ',
              '    SRC_TABELA, ',
              '    SRC_CHAVE, ',
              '    MAX(SRC_TIME) SRC_TIME ',
              'FROM tb_sincronia s ',
              '    inner join tb_produto p ',
              '    on (p.pro_codigo = s.src_registro) ',
              '  WHERE ( src_tabela =:SRC_TABELA ) ',
              '  and (SRC_OPER <> ''D'' ) ',
              '  and  ((SRC_LOG is null) or (SRC_LOG = '''')) ');
  if ( Tipo = 'SERVICO') then
    Result := concat(Result, '  AND (p.PRO_TIPO = ''S'') ')
  else
    Result := concat(Result, '  AND (p.PRO_TIPO IN (''P'',''M'')) ');
  Result := concat(Result,
                  'GROUP BY 1,2,3 ',
                  'ORDER BY 4 ASC ');
end;

function TControllerSincronia.SqlTBProdutoDeleta(Tipo: String): String;
begin
  // Mesma logica do SqlTBProdutoAtualiza (D2), para operacao 'D'.
  Result := concat(
              'SELECT ',
              '    SRC_REGISTRO, ',
              '    SRC_TABELA, ',
              '    SRC_CHAVE, ',
              '    MAX(SRC_TIME) SRC_TIME ',
              'FROM tb_sincronia s ',
              '    inner join tb_produto p ',
              '    on (p.pro_codigo = s.src_registro) ',
              '  WHERE ( src_tabela =:SRC_TABELA ) ',
              '  and (SRC_OPER = ''D'' ) ',
              '  and  ((SRC_LOG is null) or (SRC_LOG = '''')) ');
  if ( Tipo = 'SERVICO') then
    Result := concat(Result, '  AND (p.PRO_TIPO = ''S'') ')
  else
    Result := concat(Result, '  AND (p.PRO_TIPO IN (''P'',''M'')) ');
  Result := concat(Result,
                  'GROUP BY 1,2,3 ',
                  'ORDER BY 4 ASC ');
end;

function TControllerSincronia.update: boolean;
begin
  Result := True;
  UpdateObj(Registro);
end;


procedure TControllerSincronia.getById;
begin
  _getByKey(Registro);
end;

procedure TControllerSincronia.getList;
var
  Lc_Qry : TIBQuery;
  LcLista : TSincronia;
begin
  //Pegar os itens Para Deletar
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add(getSqlDeleta);
      //ParamByName('SRC_TIME').AsDateTime := Registro.Tempo;
      ParamByName('SRC_TABELA').AsString := Registro.Tabela;
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TSincronia.Create;
        LcLista.Codigo   := 0;
        LcLista.Tabela   := FieldByNAme('SRC_TABELA').AsString;
        LcLista.Chave    := FieldByNAme('SRC_CHAVE').AsString;
        LcLista.Operacao := 'D';
        LcLista.Tempo    := FieldByNAme('SRC_TIME').AsDateTime;
        LcLista.Registro := FieldByNAme('SRC_REGISTRO').AsInteger;
        Lista.add(LcLista);
        next;
      end;
      //Pegar os itens Para Atualizar
      Active := False;
      sql.Clear;
      sql.add( getSqlAtualiza);
      //ParamByName('SRC_TIME').AsDateTime := Registro.Tempo;
      ParamByName('SRC_TABELA').AsString := Registro.Tabela;
      Active := True;
      FetchAll;
      First;
      while not eof do
      Begin
        LcLista := TSincronia.Create;
        LcLista.Codigo   := 0;
        LcLista.Tabela   := FieldByNAme('SRC_TABELA').AsString;
        LcLista.Chave    := FieldByNAme('SRC_CHAVE').AsString;
        LcLista.Operacao := 'U';
        LcLista.Tempo    := FieldByNAme('SRC_TIME').AsDateTime;
        LcLista.Registro := FieldByNAme('SRC_REGISTRO').AsInteger;
        Lista.add(LcLista);
        next
      End;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

procedure TControllerSincronia.getListForRetaguarda;
var
  Lc_Qry : TIBQuery;
  LcLista : TSincronia;
begin
 //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                    'SELECT ',
                    '    SRC_REGISTRO, ',
                    '    SRC_TABELA, ',
                    '    SRC_CHAVE, ',
                    '    MAX(SRC_TIME) SRC_TIME ',
                    'FROM tb_sincronia s ',
                    'WHERE ( SRC_TIME > :SRC_TIME ) ',
                    '  and ( src_tabela =:SRC_TABELA ) ',
                    '  and ( SRC_OPER <> ''D'' ) ',
                    'GROUP BY 1,2,3 ',
                    'ORDER BY 4 ASC '
      ));

      ParamByName('SRC_TIME').AsDateTime := Registro.Tempo;
      ParamByName('SRC_TABELA').AsString := Registro.Tabela;
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TSincronia.Create;
        LcLista.Codigo   := 0;
        LcLista.Tabela   := FieldByNAme('SRC_TABELA').AsString;
        LcLista.Chave    := FieldByNAme('SRC_CHAVE').AsString;
        LcLista.Operacao := 'U';
        LcLista.Tempo    := FieldByNAme('SRC_TIME').AsDateTime;
        LcLista.Registro := FieldByNAme('SRC_REGISTRO').AsInteger;
        Lista.add(LcLista);
        next;
      end;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

procedure TControllerSincronia.getListProduto;
var
  Lc_Qry : TIBQuery;
  LcLista : TSincronia;
begin
  //Seleciona REgistros do Servidor
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add( concat(
                'select src_registro, MAX(SRC_TIME) SRC_TIME ',
                'FROM ( ',
                'select s.src_registro, s.src_time ',
                'FROM tb_sincronia s ',
                'WHERE s.src_tabela =''TB_PRODUTO'' ',
                'UNION ',
                'select e.est_codpro src_registro, s.src_time ',
                'FROM tb_sincronia s ',
                '   INNER JOIN tb_estoque e ',
                '   ON (e.est_codigo = s.src_registro) ',
                'WHERE s.src_tabela =''TB_ESTOQUE'' ',
                'UNION ',
                'select p.prc_codpro src_registro, s.src_time ',
                'FROM tb_sincronia s ',
                '   INNER JOIN tb_preco p ',
                '   ON (p.prc_codigo = s.src_registro) ',
                'WHERE s.src_tabela = ''TB_PRECO'' ',
                ') ',
                'GROUP BY 1 '
      ));
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TSincronia.Create;
        LcLista.Codigo   := 0;
        LcLista.Tabela   := 'TB_PRODUTO';
        LcLista.Chave    := 'PRO_CODIGO';
        LcLista.Operacao := 'U';
        LcLista.Tempo    := FieldByNAme('SRC_TIME').AsDateTime;
        LcLista.Registro := FieldByNAme('SRC_REGISTRO').AsInteger;
        Lista.add(LcLista);
        next;
      end;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

procedure TControllerSincronia.getListTrayImage;
var
  Lc_Qry : TIBQuery;
  LcLista : TSincronia;
begin
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin  //Seleciona REgistros do Servidor
      sql.add( concat(
                  'SELECT DISTINCT i.table_id, max(s.src_time) src_time ',
                  'FROM tb_images i ',
                  '  inner join tb_sincronia s ',
                  '  on (i.id = s.src_registro) ',
                  'where ( s.src_tabela =:src_tabela) ',
                  ' and ( s.src_time >= :src_time ) ',
                  'group by 1 '
          ));

      ParamByName('SRC_TABELA').AsString := Registro.Tabela;
      ParamByName('src_time').AsDateTime := Registro.Tempo;
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TSincronia.Create;
        with LcLista do
        Begin
          Codigo := 0;
          Tabela := 'TB_IMAGES';
          Chave := 'PRO_CODIGO';
          Operacao := 'U';
          Tempo := fieldByName('SRC_TIME').asDateTime;
          Registro := fieldByName('table_id').asInteger;
        end;
        Lista.add(LcLista);
        next;
      end;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

function TControllerSincronia.getSqlAtualiza: String;
begin
  // Rodada 2 (D8): ramo TB_PEDIDO removido — a tabela saiu do catalogo.
  if (Registro.Tabela = 'TB_NOTA_FISCAL') THEN
  Begin
    Result := SqlTBNotaFiscalAtualiza(FTipo);
  End
  else
  if (Registro.Tabela = 'TB_PRODUTO') THEN
  Begin
    // D2: CADASTRO (P/M) x SERVICO (S) — fila disjunta por PRO_TIPO
    Result := SqlTBProdutoAtualiza(FTipo);
  End
  else
  Begin
    Result := SqlPadraoAtualiza();
  End;
end;

function TControllerSincronia.getSqlDeleta: String;
begin
  // Rodada 2 (D8): ramo TB_PEDIDO removido — a tabela saiu do catalogo.
  if (Registro.Tabela = 'TB_NOTA_FISCAL') THEN
  Begin
    Result := SqlTBNotaFiscalDeleta(FTipo);
  End
  else
  if (Registro.Tabela = 'TB_PRODUTO') THEN
  Begin
    // D2: CADASTRO (P/M) x SERVICO (S) — fila disjunta por PRO_TIPO
    Result := SqlTBProdutoDeleta(FTipo);
  End
  else
  Begin
    Result := SqlPadraoDeleta();
  End;
end;

function TControllerSincronia.insert: boolean;
begin
  Result := True;
  InsertObj(Registro);
end;

end.
