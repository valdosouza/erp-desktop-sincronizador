unit ControllerRetornoNFS;

interface
uses Classes, IBX.IBQuery, SysUtils, ControllerBase, tblRetornoNFS,
     System.Generics.Collections;

Type
  TListaRetornoNFS = TObjectList<TRetornoNFS>;

  // Patch 04 (C3): controller minimo para a sincronia da NFS-e — a
  // TB_RETORNO_NFS e gravada pelo Gestao2016; o Sincronizador so LE
  // (getSincronia) para montar o payload do /invoice-return-service.
  TControllerRetornoNFS = Class(TControllerBase)
  public
    Registro : TRetornoNFS;
    Lista : TListaRetornoNFS;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    procedure getSincronia;
    // Primeira carga (padrao Fc_Usuario, Valdo 2026-08-04): com Periodo
    // filtra pela NOTA vinculada (NFS_CODNFL)
    function getList:Boolean;
  End;

implementation

{ TControllerRetornoNFS }

constructor TControllerRetornoNFS.Create(AOwner: TComponent);
begin
  inherited;
  Registro := TRetornoNFS.Create;
  Lista := TListaRetornoNFS.Create;
end;

destructor TControllerRetornoNFS.Destroy;
begin
  Lista.DisposeOf;
  Registro.DisposeOf;
  inherited;
end;

function TControllerRetornoNFS.getList: Boolean;
var
  Lc_Qry : TIBQuery;
  LcLista : TRetornoNFS;
begin
  Result := True;
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin
      active := False;
      sql.Clear;
      sql.add('SELECT R.* FROM TB_RETORNO_NFS R WHERE (R.NFS_CODNFL IS NOT NULL) ');
      // Primeira carga por periodo: retorno da NOTA do periodo (NFS_CODNFL)
      if Periodo then
      Begin
        sql.add(concat(
          ' AND EXISTS (SELECT 1 FROM TB_NOTA_FISCAL NF ',
          'WHERE (NF.NFL_CODIGO = R.NFS_CODNFL) ',
          'AND (NF.NFL_DT_EMISSAO BETWEEN :DATAINICIAL AND :DATAFINAL)) '));
        ParamByName('DATAINICIAL').AsDateTime := DataInicial;
        ParamByName('DATAFINAL').AsDateTime  := DataFinal;
      End;
      Active := True;
      FetchAll;
      First;
      Lista.Clear;
      while not eof do
      Begin
        LcLista := TRetornoNFS.Create;
        get(Lc_qry,LcLista);
        Lista.add(LcLista);
        next;
      end;
    end;
  Finally
    FinalizaQuery(Lc_Qry);
  End;
end;

procedure TControllerRetornoNFS.Clear;
begin
  clearObj(Registro);
end;

procedure TControllerRetornoNFS.getSincronia;
var
  Lc_Qry : TIBQuery;
begin
  Lc_Qry := GeraQuery;
  Try
    with Lc_Qry do
    Begin
      sql.add(concat('SELECT * ',
                     'FROM TB_RETORNO_NFS ',
                     'WHERE NFS_CODNFL=:NFS_CODNFL '
                    ));
      ParamByName('NFS_CODNFL').AsInteger := Registro.CodigoNotaFiscal;
      Active := True;
      FetchAll;
      exist := (RecordCount > 0);
      if exist then get(Lc_Qry,Registro);
    end;
  Finally
    FinalizaQuery(Lc_Qry);
  End;
end;

end.
