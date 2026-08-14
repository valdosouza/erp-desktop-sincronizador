unit tblDskPromotion;

interface

Uses GenericEntity,CAtribEntity, Classes, SysUtils;

Type
  //nome da classe de entidade
  [TableName('TB_PROMOTION')]
  TDskPromotion = Class(TGenericEntity)
  private
    FAtivo: String;
    Fprice_tag: Real;
    FDescricao: String;
    FId: Integer;
    Fquantity: Real;
    FEstabelecimento: Integer;
    FDELETED: String;
    function getDeleted: String;
    procedure setFDELETED(const Value: String);
    procedure setFAtivo(const Value: String);
    procedure setFDescricao(const Value: String);
    procedure setFEstabelecimento(const Value: Integer);
    procedure setFId(const Value: Integer);
    procedure setFprice_tag(const Value: Real);
    procedure setFquantity(const Value: Real);


  public

    [KeyField('ID')]
    [FieldName('ID')]
    property Codigo: Integer read FId write setFId;

    [KeyField('TB_INSTITUTION_ID')]
    [FieldName('TB_INSTITUTION_ID')]
    property Estabelecimento: Integer read FEstabelecimento write setFEstabelecimento;

    [FieldName('DESCRIPTION')]
    property Descricao: String read FDescricao write setFDescricao;


    [FieldName('PRICE_TAG')]
    property Preco: Real read Fprice_tag write setFprice_tag;

    [FieldName('QUANTITY')]
    property Quantidade: Real read Fquantity write setFquantity;

    [FieldName('REG_ACTIVE')]
    property Ativo: String read FAtivo write setFAtivo;

    // Soft delete universal (decisao 8): getter normalizado - 'S' apagado,
    // qualquer outra coisa (inclusive NULL/vazio) = 'N'. Substitui o antigo
    // DM.GetDeletedFlag nas classes *_send_web (Valdo, 2026-08-10).
    [FieldName('DELETED')]
    property Deleted: String read getDeleted write setFDELETED;

  End;


implementation


{ TDskPromotion }

function TDskPromotion.getDeleted: String;
begin
  if (FDELETED) = 'S' then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TDskPromotion.setFDELETED(const Value: String);
begin
  FDELETED := Value;
end;

procedure TDskPromotion.setFAtivo(const Value: String);
begin
  FAtivo := Value;
end;

procedure TDskPromotion.setFDescricao(const Value: String);
begin
  FDescricao := Value;
end;

procedure TDskPromotion.setFEstabelecimento(const Value: Integer);
begin
  FEstabelecimento := Value;
end;

procedure TDskPromotion.setFId(const Value: Integer);
begin
  FId := Value;
end;

procedure TDskPromotion.setFprice_tag(const Value: Real);
begin
  Fprice_tag := Value;
end;

procedure TDskPromotion.setFquantity(const Value: Real);
begin
  Fquantity := Value;
end;

end.

