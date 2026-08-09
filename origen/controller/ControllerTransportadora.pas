unit ControllerTransportadora;

interface
uses IBX.IBDatabase,Classes, Vcl.Grids,IBQuery, SysUtils,ControllerBase,
      Un_sistema,Un_funcoes,Un_Regra_Negocio, tbltransportadora,
      ControllerFornecedor, tblPhone,tblAddress,System.Generics.Collections;


Type
  TListaTransportadora = TObjectList<TTransportadora>;

  TControllerTransportadora = Class(TControllerBase)
  private

  public
    Registro : TTransportadora;
    Lista : TListaTransportadora;
    Fornecedor : TControllerFornecedor;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function salva:boolean;
    procedure getById;
    procedure clear;
    // Primeira carga (padrao Fc_Usuario, Valdo 2026-08-04): transportadora
    // vai COMPLETA - e referencia do customer (409 CARRIER_NOT_SYNCED se faltar)
    function getList:Boolean;
  End;

implementation


procedure TControllerTransportadora.clear;
begin
  ClearObj(registro);
end;

constructor TControllerTransportadora.Create(AOwner: TComponent);
begin
  inherited;
  Registro  := TTransportadora.Create;
  Lista     := TListaTransportadora.Create;
  Fornecedor   := TControllerFornecedor.create(Self);
end;

destructor TControllerTransportadora.Destroy;
begin
  Fornecedor.DisposeOf;
  Lista.DisposeOf;
  Registro.DisposeOf;
  inherited;
end;

function TControllerTransportadora.getList: Boolean;
var
  Lc_Qry : TIBQuery;
  LcLista : TTransportadora;
begin
  Result := True;
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add('SELECT * FROM TB_TRANSPORTADORA ');
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TTransportadora.Create;
        get(Lc_qry,LcLista);
        Lista.add(LcLista);
        next;
      end;
    end;
  Finally
    FinalizaQuery(Lc_Qry);
  End;
end;


procedure TControllerTransportadora.getById;
begin
  _getByKey(Registro);
end;

function TControllerTransportadora.salva: boolean;
begin
  try
    SaveObj(Registro);
    Result := true;
  Except
    Result := False;
  end;
end;

end.
