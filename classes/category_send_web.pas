unit category_send_web;

interface

uses System.SysUtils,general_web,REST.Json, ControllerDskCategory, System.JSON;

Type
  TCategorySendWeb = class(TGeneralWeb)
    private
      FCtrl: TControllerDskCategory;
    protected
      procedure GenerateJson;Override;
    public
    constructor Create;override;
    destructor Destroy;override;
  end;

implementation

uses un_dm;

{ TGeneralWeb }

constructor TCategorySendWeb.Create;
begin
  inherited;
  FCtrl := TControllerDskCategory.Create(nil);
end;

destructor TCategorySendWeb.Destroy;
begin
  FreeAndNil(FCtrl);
  inherited;
end;

procedure TCategorySendWeb.GenerateJson;
Var
  LcJson   : TJSONObject;
  LcPath   : String;
  LcParent : Integer;
begin
  inherited;
  FCtrl.Registro.Codigo := FCodigo;
  FCtrl.getByKey;
  if FCtrl.exist then
  Begin
    // Contrato /category/sincronize: id = CAT_CODIGO local ✅; tb_institution_id
    // NÃO viaja (D12); posit_level NUNCA viaja — o servidor recalcula a árvore.
    LcJson := TJSONObject.Create;
    try
      LcJson.AddPair('id', TJSONNumber.Create(FCtrl.Registro.Codigo));
      LcJson.AddPair('description', FCtrl.Registro.Descricao);
      LcJson.AddPair('kind', FCtrl.Registro.Tipo);
      // parentId derivado do POSIT_LEVEL (caminho materializado '001.005':
      // cada segmento e o ID do no com 3 digitos — mesma matematica do
      // @shared/tree-path da web): o PENULTIMO segmento e o pai; sem ponto
      // = raiz (0). Pai ainda nao sincronizado devolve 409 PARENT_NOT_SYNCED
      // e a fila reprocessa no proximo ciclo.
      LcPath   := Trim(FCtrl.Registro.NivelPosicao);
      LcParent := 0;
      if Pos('.', LcPath) > 0 then
      Begin
        LcPath   := Copy(LcPath, 1, LastDelimiter('.', LcPath) - 1);
        LcParent := StrToIntDef(Copy(LcPath, LastDelimiter('.', LcPath) + 1, MaxInt), 0);
      End;
      LcJson.AddPair('parentId', TJSONNumber.Create(LcParent));
      LcJson.AddPair('active', FCtrl.Registro.Ativo);
      // decisao 8: le o DELETED real da tabela
      LcJson.AddPair('deleted', DM.GetDeletedFlag('TB_CATEGORY', 'ID', FCodigo));
      FStrJson := LcJson.ToJSON;
    finally
      LcJson.Free;
    end;
  End;
end;


end.

