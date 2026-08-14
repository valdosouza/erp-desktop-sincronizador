unit tblmarcaproduto;

interface

Uses TEntity,CAtribEntity;

Type
  //nome da classe de entidade
  [TableName('TB_MARCA_PRODUTO')]
  TMarcaProduto = Class(TGenericEntity)
  private
    FMRC_ABAS: Integer;
    FMRC_DESCRICAO: String;
    FMRC_CODIGO: Integer;
    FDELETED: String;
    function getDeleted: String;
    procedure setFDELETED(const Value: String);
    procedure setFMRC_ABAS(const Value: Integer);
    procedure setFMRC_CODIGO(const Value: Integer);
    procedure setFMRC_DESCRICAO(const Value: String);

  public

    [KeyField('MRC_CODIGO')]
    [FieldName('MRC_CODIGO')]
    property Codigo: Integer read FMRC_CODIGO write setFMRC_CODIGO;

    [FieldName('MRC_DESCRICAO')]
    property Descricao: String read FMRC_DESCRICAO write setFMRC_DESCRICAO;

    [FieldName('MRC_CODFAB')]
    property Fabrica: Integer read FMRC_ABAS write setFMRC_ABAS;

    // Soft delete universal (decisao 8): getter normalizado - 'S' apagado,
    // qualquer outra coisa (inclusive NULL/vazio) = 'N'. Substitui o antigo
    // DM.GetDeletedFlag nas classes *_send_web (Valdo, 2026-08-10).
    [FieldName('DELETED')]
    property Deleted: String read getDeleted write setFDELETED;

  End;

implementation



{ TMarcaProduto }

function TMarcaProduto.getDeleted: String;
begin
  if (FDELETED) = 'S' then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TMarcaProduto.setFDELETED(const Value: String);
begin
  FDELETED := Value;
end;

procedure TMarcaProduto.setFMRC_ABAS(const Value: Integer);
begin
  FMRC_ABAS := Value;
end;

procedure TMarcaProduto.setFMRC_CODIGO(const Value: Integer);
begin
  FMRC_CODIGO := Value;
end;

procedure TMarcaProduto.setFMRC_DESCRICAO(const Value: String);
begin
  FMRC_DESCRICAO := Value;
end;

end.
