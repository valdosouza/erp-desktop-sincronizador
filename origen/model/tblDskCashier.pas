unit tblDskCashier;

interface

Uses TEntity,CAtribEntity, IBQuery;

Type
  //nome da classe de entidade
  [TableName('tb_cashier')]
  TDskCashier = Class(TGenericEntity)
  private
    FID: Integer;
    FDTRECORD: TDate;
    FUSERID : Integer;
    FHRBEGIN: TDateTime;
    FHREND: TDateTime;
    FDELETED: String;
    function getDeleted: String;
    procedure setFDELETED(const Value: String);

    procedure setFID(value: Integer);
    procedure setFDTRECORD(value: TDate);
    procedure setFUSERID(value: Integer );
    procedure setFHRBEGIN(value: TDateTime);
    procedure setFHREND(value: TDateTime);

  public
    [KeyField('id')]
    [FieldName('id')]
    property Codigo: Integer read FID write setFID;

    [FieldName('dt_record')]
    property Data: TDate read FDTRECORD write setFDTRECORD;

    [FieldName('tb_user_id')]
    property Usuario: Integer read FUSERID write setFUSERID;

    [FieldName('hr_begin')]
    property Abertura: TDateTime read FHRBEGIN write setFHRBEGIN;

    [FieldName('hr_end')]
    property Fechamento: TDateTime read FHREND write setFHREND;

    // Soft delete universal (decisao 8): getter normalizado - 'S' apagado,
    // qualquer outra coisa (inclusive NULL/vazio) = 'N'. Substitui o antigo
    // DM.GetDeletedFlag nas classes *_send_web (Valdo, 2026-08-10).
    [FieldName('DELETED')]
    property Deleted: String read getDeleted write setFDELETED;

  End;

implementation

uses Un_DM;

function TDskCashier.getDeleted: String;
begin
  if (FDELETED) = 'S' then
    Result := 'S'
  else
    Result := 'N';
end;

procedure TDskCashier.setFDELETED(const Value: String);
begin
  FDELETED := Value;
end;

procedure TDskCashier.setFDTRECORD(value: TDAte);
begin
  FDTRECORD := value;
end;

procedure TDskCashier.setFHRBEGIN(value: TDateTime);
begin
  FHRBEGIN := value;
end;

procedure TDskCashier.setFHREND(value: TDateTime);
begin
  FHREND :=value;
end;

procedure TDskCashier.setFID(value: Integer);
begin
  FID := Value;
end;

procedure TDskCashier.setFUSERID(value: Integer);
begin
  FUSERID := value;
end;

end.
