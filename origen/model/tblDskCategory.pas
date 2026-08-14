unit tblDskCategory;

interface

Uses GenericEntity,CAtribEntity, System.Classes, System.SysUtils;
Type
  //nome da classe de entidade
  [TableName('TB_CATEGORY')]
  TDskCategory = Class(TGenericEntity)
  private
    Fposit_level: String;
    Fenabled: String;
    Fdescription: String;
    FId: Integer;
    Ftb_institution_id: Integer;
    Fkind: String;
    FDELETED: String;
    function getDeleted: String;
    procedure setFDELETED(const Value: String);
    procedure setFdescription(const Value: String);
    procedure setFenabled(const Value: String);
    procedure setFId(const Value: Integer);
    procedure setFkind(const Value: String);
    procedure setFposit_level(const Value: String);
    procedure setFtb_institution_id(const Value: Integer);


  public
    [KeyField('id')]
    [FieldName('id')]
    property Codigo: Integer read FId write setFId;

    [FieldName('TB_INSTITUTE_ID')]
    property Estabelecimento: Integer read Ftb_institution_id write setFtb_institution_id;

    [FieldName('description')]
    property Descricao: String read Fdescription write setFdescription;

    [FieldName('posit_level')]
    property NivelPosicao: String read Fposit_level write setFposit_level;

    [FieldName('kind')]
    property Tipo: String read Fkind write setFkind;

    [FieldName('ENABLED')]
    property Ativo: String read Fenabled write setFenabled;

    // Soft delete universal (decisao 8): getter normalizado - 'S' apagado,
    // qualquer outra coisa (inclusive NULL/vazio) = 'N'. Substitui o antigo
    // DM.GetDeletedFlag nas classes *_send_web (Valdo, 2026-08-10).
    [FieldName('DELETED')]
    property Deleted: String read getDeleted write setFDELETED;

  End;


implementation

{ TDskCategory }

function TDskCategory.getDeleted: String;
begin
  if (FDELETED) = 'S' then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TDskCategory.setFDELETED(const Value: String);
begin
  FDELETED := Value;
end;

procedure TDskCategory.setFdescription(const Value: String);
begin
  Fdescription := Value;
end;

procedure TDskCategory.setFenabled(const Value: String);
begin
  Fenabled := Value;
end;

procedure TDskCategory.setFId(const Value: Integer);
begin
  FId := Value;
end;

procedure TDskCategory.setFkind(const Value: String);
begin
  Fkind := Value;
end;

procedure TDskCategory.setFposit_level(const Value: String);
begin
  Fposit_level := Value;
end;

procedure TDskCategory.setFtb_institution_id(const Value: Integer);
begin
  Ftb_institution_id := Value;
end;

end.
