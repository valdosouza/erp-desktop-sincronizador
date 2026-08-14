unit tblEmbalagem;

interface

Uses TEntity,CAtribEntity;

Type
  //nome da classe de entidade
  [TableName('tb_embalagem')]
  TEmbalagem = Class(TGenericEntity)
  private
    FEMB_DESCRICAO: String;
    FEMB_CODIGO: Integer;
    FEMB_ABREVIATURA: String;
    FDELETED: String;
    function getDeleted: String;
    procedure setFDELETED(const Value: String);
    procedure setFEMB_ABREVIATURA(const Value: String);
    procedure setFEMB_CODIGO(const Value: Integer);
    procedure setFEMB_DESCRICAO(const Value: String);

  public

    [KeyField('EMB_CODIGO')]
    [FieldName('EMB_CODIGO')]
    property Codigo: Integer read FEMB_CODIGO write setFEMB_CODIGO;

    [FieldName('EMB_DESCRICAO')]
    property Descricao: String read FEMB_DESCRICAO write setFEMB_DESCRICAO;

    [FieldName('EMB_ABREVIATURA')]
    property Abreviatura: String read FEMB_ABREVIATURA write setFEMB_ABREVIATURA;

    // Soft delete universal (decisao 8): getter normalizado - 'S' apagado,
    // qualquer outra coisa (inclusive NULL/vazio) = 'N'. Substitui o antigo
    // DM.GetDeletedFlag nas classes *_send_web (Valdo, 2026-08-10).
    [FieldName('DELETED')]
    property Deleted: String read getDeleted write setFDELETED;

  End;

implementation


{ TEmbalagem }

function TEmbalagem.getDeleted: String;
begin
  if (FDELETED) = 'S' then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TEmbalagem.setFDELETED(const Value: String);
begin
  FDELETED := Value;
end;

procedure TEmbalagem.setFEMB_ABREVIATURA(const Value: String);
begin
  FEMB_ABREVIATURA := Value;
end;

procedure TEmbalagem.setFEMB_CODIGO(const Value: Integer);
begin
  FEMB_CODIGO := Value;
end;

procedure TEmbalagem.setFEMB_DESCRICAO(const Value: String);
begin
  FEMB_DESCRICAO := Value;
end;

end.
