unit tbltransportadora;

interface

Uses TEntity,CAtribEntity;

Type
  //nome da classe de entidade
  [TableName('TB_TRANSPORTADORA ')]
  TTransportadora = Class(TGenericEntity)
  private
    FTRP_ATIVO: String;
    FTRP_CODEMP: Integer;
    FDELETED: String;
    function getDeleted: String;
    procedure setFDELETED(const Value: String);
    procedure setFTRP_ATIVO(const Value: String);
    procedure setFTRP_CODEMP(const Value: Integer);
  public

    [KeyField('TRP_CODEMP')]
    [FieldName('TRP_CODEMP')]
    property Codigo: Integer read FTRP_CODEMP write setFTRP_CODEMP;

    [FieldName('TRP_ATIVO')]
    property Ativo: String read FTRP_ATIVO write setFTRP_ATIVO;

    // Soft delete universal (decisao 8): getter normalizado - 'S' apagado,
    // qualquer outra coisa (inclusive NULL/vazio) = 'N'. Substitui o antigo
    // DM.GetDeletedFlag nas classes *_send_web (Valdo, 2026-08-10).
    [FieldName('DELETED')]
    property Deleted: String read getDeleted write setFDELETED;


  End;

implementation

{ TTransportadora }

function TTransportadora.getDeleted: String;
begin
  if (FDELETED) = 'S' then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TTransportadora.setFDELETED(const Value: String);
begin
  FDELETED := Value;
end;

procedure TTransportadora.setFTRP_ATIVO(const Value: String);
begin
  FTRP_ATIVO := Value;
end;

procedure TTransportadora.setFTRP_CODEMP(const Value: Integer);
begin
  FTRP_CODEMP := Value;
end;

end.
