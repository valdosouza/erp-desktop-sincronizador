unit tblFornecedor;

interface

Uses TEntity,CAtribEntity;

Type
  //nome da classe de entidade
  [TableName('tb_fornecedor')]
  TFornecedor = Class(TGenericEntity)
  private
    FFOR_ATIVO: String;
    FFOR_CODEMP: Integer;
    FDELETED: String;
    function getDeleted: String;
    procedure setFDELETED(const Value: String);

    procedure setFFOR_CODEMP( Value : INTEGER);
    procedure setFFOR_ATIVO( Value : String);
  public

    [KeyField('FOR_CODEMP')]
    [FieldName('FOR_CODEMP')]
    property Codigo: Integer read FFOR_CODEMP write setFFOR_CODEMP;

    [FieldName('FOR_ATIVO')]
    property Ativo: String read FFOR_ATIVO write setFFOR_ATIVO;

    // Soft delete universal (decisao 8): getter normalizado - 'S' apagado,
    // qualquer outra coisa (inclusive NULL/vazio) = 'N'. Substitui o antigo
    // DM.GetDeletedFlag nas classes *_send_web (Valdo, 2026-08-10).
    [FieldName('DELETED')]
    property Deleted: String read getDeleted write setFDELETED;


  End;

implementation


{ TFornecedor }

function TFornecedor.getDeleted: String;
begin
  if (FDELETED) = 'S' then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TFornecedor.setFDELETED(const Value: String);
begin
  FDELETED := Value;
end;

procedure TFornecedor.setFFOR_ATIVO(Value: String);
begin
  FFOR_ATIVO := Value;
end;

procedure TFornecedor.setFFOR_CODEMP(Value: INTEGER);
begin
  FFOR_CODEMP := Value;
end;

end.
