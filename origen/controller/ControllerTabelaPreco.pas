unit ControllerTabelaPreco;

interface

uses IBX.IBDatabase,Classes, IBX.IBQuery, SysUtils,ControllerBase,
      tblTabelaPreco,Un_MSg, Generics.Collections,
  ControllerPreco, ControllerTabelaPrecoHasFormaPagto;

Type

  TListapreco  = TObjectList<TTabelaPreco>;

  TControllerTabelaPreco = Class(TControllerBase)
  private

  public
    Registro : TTabelapreco;
    Lista : TListapreco;
    ListaSplFormaPAgto : TLsitaSplFormaPAgto;
    Preco : TControllerPreco;
    HasFormaPAgto : TControllerTabelaPrecoHasFormaPagto;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure getbyId;
    function save:boolean;
    function migra:Boolean;
    function insert:boolean;
    function replace:boolean;
    function update:boolean;
    Function delete:boolean;
    procedure DeleteItens;
    procedure getList;
    function getPrincipal:Integer;
    function DefinePrincipal:Boolean;
    procedure clear;
    procedure getListByScale;
  End;

implementation

uses Un_sistema, Un_funcoes,Un_Regra_Negocio;

procedure TControllerTabelaPreco.clear;
begin
  ClearObj(registro);
end;

constructor TControllerTabelaPreco.Create(AOwner: TComponent);
begin
  inherited;
  Registro := TTabelaPreco.Create;
  Lista := TListapreco.Create;
  Preco := TControllerPreco.Create(Self);
  HasFormaPAgto := TControllerTabelaPrecoHasFormaPagto.Create(Self);
  ListaSplFormaPAgto := TLsitaSplFormaPAgto.Create;
end;

function TControllerTabelaPreco.DefinePrincipal: Boolean;
Var
  Lc_Qry : TIbQuery;
Begin
  Result := True;
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      SQL.Add('UPDATE TB_TABELA_PRECO SET '+
              'TPR_PRINCIPAL = ''N'' '+
              'WHERE TPR_CODIGO <>:TPR_CODIGO');
      ParamByName('TPR_CODIGO').AsInteger := Registro.Codigo;
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;
end;

function TControllerTabelaPreco.delete: boolean;
begin
  Try
    DeleteItens;
    DeleteObj(Registro);
    Result := True;
  Except
    Result := False;
  End;
end;

procedure TControllerTabelaPreco.DeleteItens;
Var
  Lc_Qry : TIbQuery;
Begin
  Lc_Qry := GeraQuery;
  try
    with Lc_Qry do
    Begin
      SQL.Clear;
      SQL.Add('DELETE FROM TB_PRECO WHERE PRC_CODTPR=:TPR_CODIGO');
      ParamByName('TPR_CODIGO').AsInteger := Registro.Codigo;
      ExecSQL;
    end;
  finally
    FinalizaQuery(Lc_Qry);
  end;

end;

destructor TControllerTabelaPreco.Destroy;
begin
  Lista.DisposeOf;
  ListaSplFormaPAgto.DisposeOf;
  HasFormaPAgto.DisposeOf;
  Preco.DisposeOf;
  Registro.DisposeOf;
  inherited;
end;

function TControllerTabelaPreco.insert: boolean;
begin
  if Registro.Codigo = 0 then
    Registro.Codigo := Generator('GN_TABELA_PRECO');
  Try
    InsertObj(Registro);
    Result := True;
  Except
    Result := False;
  End;
end;


function TControllerTabelaPreco.migra: Boolean;
begin
  Result := True;
  SaveObj(Registro);
end;

function TControllerTabelaPreco.replace: boolean;
begin
  Try
    replaceObj(Registro);
    Result := True;
  Except
    Result := False;
  End;
end;

function TControllerTabelaPreco.save: boolean;
begin
  Try
    if Registro.Codigo = 0 then
      Registro.Codigo := Generator('GN_TABELA_PRECO');
    SaveObj(Registro);
    Result := True;
  Except
    Result := False;
  End;
end;

function TControllerTabelaPreco.update: boolean;
begin
  Try
    UpdateObj(Registro);
    Result := True;
  Except
    Result := False;
  End;
end;

procedure TControllerTabelaPreco.getById;
begin
  _getByKey(Registro);
end;


procedure TControllerTabelaPreco.getList;
var
  Lc_Qry : TIBQuery;
  LcLista : TTabelaPreco;
begin
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add(concat(
                'SELECT * ',
                'FROM tb_tabela_preco ',
                'WHERE TPR_CODIGO IS NOT NULL '
                ));
      if Registro.Ativa <> '' then
        sql.add('TPR_ATIVA=:TPR_ATIVA ');

      sql.add('ORDER BY TPR_CODIGO ');

      if Registro.Ativa <> '' then
        ParamByName('TPR_ATIVA').AsString := Registro.Ativa;
      // Primeira carga por periodo (padrao Fc_Usuario, Valdo 2026-08-04):
      // tabela com preco de produto movimentado em nota do periodo
      if Periodo then
      Begin
        sql.Clear;
        sql.add(concat(
                'SELECT DISTINCT TP.* ',
                'FROM TB_PEDIDO PD ',
                '   INNER JOIN TB_NOTA_FISCAL NF ',
                '   ON (NF.NFL_CODPED = PD.PED_CODIGO) ',
                '   INNER JOIN TB_ITENS_NFL IT ',
                '   ON (IT.ITF_CODPED = PD.PED_CODIGO) ',
                '   INNER JOIN TB_PRECO PR ',
                '   ON (PR.PRC_CODPRO = IT.ITF_CODPRO) ',
                '   INNER JOIN TB_TABELA_PRECO TP ',
                '   ON (TP.TPR_CODIGO = PR.PRC_CODTPR) ',
                'WHERE NF.NFL_DT_EMISSAO BETWEEN :DATAINICIAL AND :DATAFINAL'
        ));
        ParamByName('DATAINICIAL').AsDateTime := DataInicial;
        ParamByName('DATAFINAL').AsDateTime  := DataFinal;
      End;
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TTabelaPreco.Create;
        get(Lc_qry,LcLista);
        Lista.add(LcLista);
        next;
      end;
    end;
  Finally
    FinalizaQuery(Lc_Qry);
  End;

end;

procedure TControllerTabelaPreco.getListByScale;
var
  Lc_Qry : TIBQuery;
  LcLista : TTabelaPreco;
begin
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add(concat(
                'SELECT * ',
                'FROM tb_tabela_preco ',
                'WHERE ( ( tpr_mar_via_escala > 0 ) or (tpr_modalidade = ''V'') ) ',
                ' AND ( TPR_ATIVA = ''S'' ) ',
                ' ORDER BY tpr_modalidade desc,  tpr_mar_via_escala ASC '
                ));
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TTabelaPreco.Create;
        get(Lc_qry,LcLista);
        Lista.add(LcLista);
        next;
      end;
    end;
  Finally
    FinalizaQuery(Lc_Qry);
  End;
end;

function TControllerTabelaPreco.getPrincipal: Integer;
var
  Lc_Qry : TIBQuery;
begin
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add(concat(
                  'SELECT TPR_CODIGO ',
                  'FROM tb_tabela_preco ',
                  'WHERE TPR_PRINCIPAL = ''S'' '
                  ));
      Active := True;
      FetchAll;
      Result := FieldByName('TPR_CODIGO').asinteger;
    end;
  Finally
    FinalizaQuery(Lc_Qry);
  End;
end;


end.
