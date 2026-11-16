unit tas_config;

interface

{$WARN UNIT_PLATFORM OFF}

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,   StdCtrls, Spin, ComCtrls, ExtCtrls, DB, ADODB, IniFiles,
  Mask, DBCtrls, Grids, Buttons, ShellAPI, Menus, registry, OleCtrls,
  SHDocVw,   TabNotBk, jpeg, DBGrids, FileCtrl, ImgList, base_form,
  StrUtils, Gauges, IBDatabase, IBServices, System.ImageList,  Un_Msg,
  ControllerUsuario,
  ControllerDskCategory,ControllerMarcaProduto,ControllerMedida,
  ControllerEmbalagem,ControllerEstoques,ControllerEstoque,ControllerTabelaPreco,
  ControllerPreco,ControllerCliente,ControllerFornecedor,ControllerColaborador,
  ControllerFormaPagamento,ControllerProduto,Vcl.CheckLst, ControllerMovimentoFinanceiro,
  ControllerDskCashier,ControllerREtornoNfe,ControllerREtornoNFCe,ControllerArquivo,
  ControllerFinanceiro,controllerCartaCorrecao,
  IBX.IBQuery,ControllerPedido,ControllerNotaFiscal,ControllerDskPromotion,
  ControllerContaBancaria,ControllerHistoricoBancario,ControllerCrpItens,ControllerGrupos,
  ControllerSubGrupos,ControllerCtrlEstoque,ControllerRetornoNFS,
  ControllerTransportadora,ControllerPlanoContas;


type

  TTasConfig = class(TBaseForm)
    pnl_rodape: TPanel;
    Sb_primeira_carga: TSpeedButton;
    Sb_Close: TSpeedButton;
    pg_Principal: TPageControl;
    tbs_conexao: TTabSheet;
    pnl_config: TPanel;
    Label4: TLabel;
    ChBx_IniciarWindows: TCheckBox;
    Label2: TLabel;
    E_Path_BD_Local: TEdit;
    Label3: TLabel;
    E_Intervalo: TEdit;
    E_NoMinuto: TEdit;
    UpD_Intervalor: TUpDown;
    tbs_sistema_web: TTabSheet;
    GG_Web_Process: TGauge;
    Pg_Sistema_web: TPageControl;
    tbs_sistema_web_send: TTabSheet;
    tbs_ExcecoesEnvio: TTabSheet;
    Lb_Web_Process: TLabel;
    ChLBx_First_Charge: TCheckListBox;
    ChLBx_Excecoes_Envio: TCheckListBox;
    Sb_IntoQuue: TSpeedButton;
    PageControl1: TPageControl;
    TabSheet2: TTabSheet;
    Panel2: TPanel;
    tbs_process_export: TTabSheet;
    Lst_Process_Export: TListBox;
    tbs_ExcecoesReceber: TTabSheet;
    ChLBx_Excecoes_Recebo: TCheckListBox;
    TabSheet3: TTabSheet;
    pnl_valida: TPanel;
    Cb_Validacao: TComboBox;
    Label8: TLabel;
    Sb_Valida_Inicia: TSpeedButton;
    Chbx_AutoMinimize: TCheckBox;
    tbs_SistemaWeb_Geral: TTabSheet;
    Panel4: TPanel;
    Chbx_ReceiveWebServer: TCheckBox;
    Chbx_SendToWebServer: TCheckBox;
    tbs_primeira_carga_periodo: TTabSheet;
    Panel6: TPanel;
    Dtp_Data_Inicial: TDateTimePicker;
    Dtp_Data_Final: TDateTimePicker;
    ChBx_Periodo: TCheckBox;
    Label7: TLabel;
    E_Path_url: TEdit;
    Label11: TLabel;
    E_Terminal: TEdit;
    // D12 (revisao do sincronizador): chave de instalacao por cliente,
    // enviada como header X-Api-Key (lida em un_sincroniza: SISWEB\FApiKey)
    Lb_ApiKey: TLabel;
    E_ApiKey: TEdit;
    procedure Sb_CloseClick(Sender: TObject);
    procedure Sb_primeira_cargaClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormatScreen;Override;
    procedure Chbx_ReceiveLocalServerClick(Sender: TObject);
    procedure Sb_IntoQuueClick(Sender: TObject);
  private
    { Private declarations }
    // ---- contexto da PRIMEIRA CARGA (roda em THREAD - ver Sb_IntoQuueClick) ----
    FResumoCarga    : String;   // acumulado "tabela: N registro(s)"
    FCargaPeriodo   : Boolean;  // ChBx_Periodo capturado no clique
    FCargaDataIni   : TDateTime; // periodo capturado dos Dtp_* (BETWEEN inclusivo,
    FCargaDataFim   : TDateTime; // mesmo formato do exemplo Fc_Usuario)
    FCargaDtIniTela : String;   // datas dd/mm/yyyy para a mensagem final
    FCargaDtFimTela : String;
    FCargaEtapa     : Integer;  // tabela corrente (1..FCargaTotal)
    FCargaTotal     : Integer;  // total de tabelas marcadas
    FCargaRegAtual  : Integer;  // registro corrente DENTRO da tabela em curso
    FCargaRegTotal  : Integer;  // total de registros da tabela em curso (Lista.Count)
    FCargaDB        : TIBDatabase;    // conexao PROPRIA da thread da carga -
    FCargaTx        : TIBTransaction; // nao compartilha o Qr_Crud do DM com o
    FCargaQry       : TIBQuery;       // ciclo de envio (IBX nao e thread-safe)
    function validaConfig:Boolean;
    procedure ExecStartWin;

    procedure SaveConfig;
    procedure ShowConfig;

    //Lista de Tabelas
    procedure preencheListaTabelas(Lista:TCheckListBox);
    procedure ShowExcecoes;
    procedure SalvaExcecoes;
    procedure preencheListaPrimeiraCarga;
    { ========== PRIMEIRA CARGA por procedure NOMEADA (Valdo, 2026-08-04) ==========
      Padrao Fc_Usuario (exemplo do Valdo): a LISTA nasce no CONTROLLER da
      tabela (getList honra Periodo/DataInicial/DataFinal do ControllerBase,
      vinculando a NOTA do periodo ou a propria data de movimento) e a Fc_*
      so itera a Lista chamando Fc_InsertSicronia - individualizado, sem SQL
      empilhado aqui. Um check da lista = uma Fc_* (indice 1:1 com
      preencheListaPrimeiraCarga - alterou uma, altera a outra).
      THREAD: as Fc_* rodam numa thread anonima; cada controller recebe
      DataBase := FCargaDB (conexao PROPRIA da carga - o DM segue livre para
      o ciclo de envio) e a UI atualiza via TThread.Queue (InicioEtapa/
      FimEtapa). Contexto de UI capturado ANTES da thread (FCarga*).
      Vao COMPLETOS os cadastros que sao REFERENCIA dos movimentos
      (colaborador, transportadora, forma de pagamento, plano de contas,
      conta bancaria, promocao) - filtra-los causaria 409 *_NOT_SYNCED. }
    procedure Fc_InsertSicronia(pTable,pField: String; pCodigo:Integer);
    procedure InicioEtapa(const pRotulo: String);
    procedure IniciaProgressoRegistros(pTotal: Integer);
    procedure AtualizaProgressoRegistros;
    procedure FimEtapa(const pRotulo: String; pQuantidade: Integer);
    procedure AbreConexaoCarga;
    procedure FechaConexaoCarga;
    function ExecCargaRet(const pSql: String): Integer;
    // cadastros (Seqs 1-19 do catalogo)
    procedure Fc_Usuario;
    procedure Fc_Marca;
    procedure Fc_Categoria;
    procedure Fc_Medida;
    procedure Fc_Embalagem;
    procedure Fc_Produto;          // mercadoria E servico (Seqs 6/19) - 1 linha por produto
    procedure Fc_TabelaPreco;
    procedure Fc_Preco;
    procedure Fc_Estoques;
    procedure Fc_Estoque;
    procedure Fc_Promotion;
    procedure Fc_PlanoContas;
    procedure Fc_FormaPagto;
    procedure Fc_Cliente;
    procedure Fc_fornecedor;
    procedure Fc_Colaborador;
    procedure Fc_ContaBancaria;
    procedure Fc_Transportadora;
    // movimento (Seqs 20-33)
    procedure Fc_NotaFiscal;       // avulsa + processos servico/venda/compra/ajuste (Seqs 20-24)
    procedure FC_MovimentoEstoque;
    procedure Fc_Financeiro;       // periodo pela NOTA vinculada (FIN_CODNFL)
    procedure FC_MovimentoFinanceiro;
    procedure FC_ControleCaixa;
    procedure FC_RetornoNFe;
    procedure FC_RetornoNFCe;
    procedure FC_RetornoNFSe;
    procedure FC_Arquivos;

  protected
    // Sem chamada hoje, mas guardados de proposito (protected nao gera H2219):
    procedure FC_CartaCorrecao;    // Seq 33 - SET_ON 'N' ate a Rodada 4 (fora da checklist)
    // conversao grupo/subgrupo -> categoria (delegate do motor do bootstrap, nao enfileira)
    procedure Fc_GrupoToCategoria;

  public
    { Public declarations }
  end;

var
  TasConfig: TTasConfig;

implementation

{$R *.dfm}

uses un_dm, uMain, un_sistema, un_funcoes;



procedure TTasConfig.Chbx_ReceiveLocalServerClick(Sender: TObject);
begin
  if TCheckBox(Sender).Checked then
  Begin
    Chbx_ReceiveWebServer.Checked := False;
    Chbx_ReceiveWebServer.Enabled := False;
  End
  else
  Begin
    Chbx_ReceiveWebServer.Enabled := True;
  End;
end;

procedure TTasConfig.ExecStartWin;
var
  Reg: TRegistry;
  S: string;
begin
  if ChBx_IniciarWindows.Checked then
  Begin
    Reg := TRegistry.Create;
    S:=ExtractFileDir(Application.ExeName)+'\'+ExtractFileName(Application.ExeName);
    Reg.rootkey:=HKEY_LOCAL_MACHINE;
    Reg.Openkey('SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\RUN',false);
    Reg.WriteString('ProgramaInicia',S);
    Reg.closekey;
    Reg.Free;
  End
  else
  Begin
    Reg := TRegistry.Create;
    S:=ExtractFileDir(Application.ExeName)+'\'+ExtractFileName(Application.ExeName);
    Reg.rootkey:=HKEY_LOCAL_MACHINE;
    Reg.Openkey('SOFTWARE\MICROSOFT\WINDOWS\CURRENTVERSION\RUN',false);
    Reg.DeleteValue('ProgramaInicia');
    Reg.closekey;
    Reg.Free;
  End;
end;

{ ========== PRIMEIRA CARGA (padrao Fc_Usuario do Valdo, 2026-08-04) ==========
  A LISTA nasce no CONTROLLER da tabela (getList honra Periodo/DataInicial/
  DataFinal, vinculando a NOTA do periodo ou a propria data de movimento) e
  a Fc_* so itera a Lista chamando Fc_InsertSicronia. Tudo roda na THREAD da
  carga: cada controller recebe DataBase := FCargaDB (conexao propria) e a
  UI atualiza via TThread.Queue (InicioEtapa/FimEtapa).
  GAUGE (Valdo, 2026-08-09): GG_Web_Process deixou de marcar "tabela X de N"
  (passo unico por tabela, parado demais em tabela com muito registro - ex.
  TB_ITENS_NFL/TB_PRODUTO na Pipoteca) e passa a marcar o progresso DENTRO
  da tabela em curso (registro X de N daquela tabela). O "X de N tabelas"
  continua so no rotulo (Lb_Web_Process), via InicioEtapa. }

procedure TTasConfig.InicioEtapa(const pRotulo: String);
Var
  LcEtapa : String;
begin
  Inc(FCargaEtapa);
  LcEtapa := concat('Colocando na fila (', IntToStr(FCargaEtapa), ' de ',
    IntToStr(FCargaTotal), '): ', pRotulo, '...');
  TThread.Queue(nil,
    procedure
    begin
      Lb_Web_Process.Caption := LcEtapa;
      Lb_Web_Process.Update;
    end);
end;

procedure TTasConfig.IniciaProgressoRegistros(pTotal: Integer);
begin
  // Chamada 1x por Fc_*, logo apos o getList (quando o total de registros da
  // tabela em curso ja e conhecido) e ANTES do loop que chama
  // Fc_InsertSicronia. Reseta o gauge para acompanhar ESTA tabela.
  FCargaRegAtual := 0;
  FCargaRegTotal := pTotal;
  TThread.Queue(nil,
    procedure
    begin
      GG_Web_Process.MinValue := 0;
      if pTotal > 0 then
        GG_Web_Process.MaxValue := pTotal
      else
        GG_Web_Process.MaxValue := 1;
      GG_Web_Process.Progress := 0;
      GG_Web_Process.Update;
    end);
end;

procedure TTasConfig.AtualizaProgressoRegistros;
Var
  LcAtual : Integer;
begin
  // Throttle: em tabela com centenas de milhares de linhas (ex.:
  // TB_ITENS_NFL/TB_PRODUTO movimentado), atualizar a UI a CADA registro
  // inundaria a fila de mensagens (TThread.Queue) e derrubaria a
  // performance da carga. Atualiza a cada 200 registros e sempre no
  // ultimo - FimEtapa ainda garante o fechamento em 100%.
  if FCargaRegTotal <= 0 then Exit;
  if (FCargaRegAtual <> FCargaRegTotal) and (FCargaRegAtual mod 200 <> 0) then Exit;
  LcAtual := FCargaRegAtual;
  TThread.Queue(nil,
    procedure
    begin
      GG_Web_Process.Progress := LcAtual;
      GG_Web_Process.Update;
    end);
end;

procedure TTasConfig.FimEtapa(const pRotulo: String; pQuantidade: Integer);
begin
  FResumoCarga := concat(FResumoCarga,
    '  - ', pRotulo, ': ', IntToStr(pQuantidade), ' registro(s)', sLineBreak);
  // Garante o gauge fechado em 100% da tabela que terminou, mesmo que o
  // throttle de AtualizaProgressoRegistros tenha pulado o ultimo registro.
  TThread.Queue(nil,
    procedure
    begin
      GG_Web_Process.Progress := GG_Web_Process.MaxValue;
      GG_Web_Process.Update;
    end);
end;

procedure TTasConfig.AbreConexaoCarga;
begin
  // Conexao PROPRIA da thread da primeira carga (mesmos parametros do banco
  // local do DM) - o Qr_Crud do DM segue livre para o ciclo de envio.
  FCargaDB := TIBDatabase.Create(nil);
  FCargaDB.DatabaseName := DM.IBD_Gestao.DatabaseName;
  FCargaDB.Params.Assign(DM.IBD_Gestao.Params);
  FCargaDB.LoginPrompt  := False;
  FCargaDB.SQLDialect   := DM.IBD_Gestao.SQLDialect;
  FCargaTx := TIBTransaction.Create(nil);
  FCargaTx.DefaultDatabase    := FCargaDB;
  FCargaDB.DefaultTransaction := FCargaTx;
  FCargaQry := TIBQuery.Create(nil);
  FCargaQry.Database    := FCargaDB;
  FCargaQry.Transaction := FCargaTx;
  FCargaDB.Connected := True;
end;

procedure TTasConfig.FechaConexaoCarga;
begin
  try
    if Assigned(FCargaTx) and FCargaTx.InTransaction then
      FCargaTx.Rollback;
    if Assigned(FCargaDB) then
      FCargaDB.Connected := False;
  except
    // desconexao falhou: os Free abaixo ainda liberam os componentes
  end;
  FreeAndNil(FCargaQry);
  FreeAndNil(FCargaTx);
  FreeAndNil(FCargaDB);
end;

function TTasConfig.ExecCargaRet(const pSql: String): Integer;
begin
  // Commit por tabela: cada Fc_* que termina ja esta segura na fila.
  FCargaQry.Close;
  if not FCargaTx.InTransaction then
    FCargaTx.StartTransaction;
  FCargaQry.SQL.Text := pSql;
  FCargaQry.ExecSQL;
  Result := FCargaQry.RowsAffected;
  FCargaTx.Commit;
end;

// ---- cadastros (Seqs 1-19 do catalogo) ----

procedure TTasConfig.Fc_Usuario;
Var
  Lc_User : TControllerUsuario;
  I : Integer;
begin
  InicioEtapa('Usuarios');
  Lc_User := TControllerUsuario.Create(nil);
  try
    Lc_User.DataBase    := FCargaDB;
    Lc_User.Periodo     := FCargaPeriodo;
    Lc_User.DataInicial := FCargaDataIni;
    Lc_User.DataFinal   := FCargaDataFim;
    Lc_User.getList;
    IniciaProgressoRegistros(Lc_User.Lista.Count);
    for I := 0 to Lc_User.Lista.Count -1 do
      Fc_InsertSicronia('TB_USUARIO','USU_CODIGO',Lc_User.Lista[I].Codigo);
    FimEtapa('Usuarios', Lc_User.Lista.Count);
  finally
    FreeAndNil(Lc_User);
  end;
end;

procedure TTasConfig.Fc_Marca;
Var
  Lc_Ctrl : TControllerMarcaProduto;
  I : Integer;
begin
  InicioEtapa('Marcas de produto');
  Lc_Ctrl := TControllerMarcaProduto.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_MARCA_PRODUTO','MRC_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Marcas de produto', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Categoria;
Var
  Lc_Ctrl : TControllerDskCategory;
  I : Integer;
begin
  InicioEtapa('Categorias');
  Lc_Ctrl := TControllerDskCategory.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_CATEGORY','ID',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Categorias', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Medida;
Var
  Lc_Ctrl : TControllerMedida;
  I : Integer;
begin
  InicioEtapa('Medidas/Unidades');
  Lc_Ctrl := TControllerMedida.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_MEDIDA','MED_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Medidas/Unidades', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Embalagem;
Var
  Lc_Ctrl : TControllerEmbalagem;
  I : Integer;
begin
  InicioEtapa('Embalagens');
  Lc_Ctrl := TControllerEmbalagem.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_EMBALAGEM','EMB_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Embalagens', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Produto;
Var
  Lc_Ctrl : TControllerProduto;
  I : Integer;
begin
  // Cobre mercadoria E servico (Seqs 6/19): a fila tem UMA linha por
  // produto; o KIND roteia no envio (P/M merchandise, S service).
  InicioEtapa('Produtos');
  Lc_Ctrl := TControllerProduto.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList('');
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_PRODUTO','PRO_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Produtos', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_TabelaPreco;
Var
  Lc_Ctrl : TControllerTabelaPreco;
  I : Integer;
begin
  InicioEtapa('Tabelas de preco');
  Lc_Ctrl := TControllerTabelaPreco.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_TABELA_PRECO','TPR_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Tabelas de preco', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Preco;
Var
  Lc_Ctrl : TControllerPreco;
  I : Integer;
begin
  InicioEtapa('Precos');
  Lc_Ctrl := TControllerPreco.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_PRECO','PRC_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Precos', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Estoques;
Var
  Lc_Ctrl : TControllerEstoques;
  I : Integer;
begin
  InicioEtapa('Estoques (depositos)');
  Lc_Ctrl := TControllerEstoques.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.Registro.Estabelecimento := 1;
    Lc_Ctrl.GetList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_ESTOQUES','ETS_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Estoques (depositos)', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Estoque;
Var
  Lc_Ctrl : TControllerEstoque;
  I : Integer;
begin
  InicioEtapa('Saldos de estoque');
  Lc_Ctrl := TControllerEstoque.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_ESTOQUE','EST_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Saldos de estoque', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Promotion;
Var
  Lc_Ctrl : TControllerDskPromotion;
  I : Integer;
begin
  // Completa: promocao e configuracao vigente, nao movimento.
  InicioEtapa('Promocoes');
  Lc_Ctrl := TControllerDskPromotion.Create(nil);
  try
    Lc_Ctrl.DataBase := FCargaDB;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_PROMOTION','ID',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Promocoes', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_PlanoContas;
Var
  Lc_Ctrl : TControllerPlanoContas;
  I : Integer;
begin
  // Completa: referencia do payment do financeiro (financialPlansId).
  InicioEtapa('Plano de contas');
  Lc_Ctrl := TControllerPlanoContas.Create(nil);
  try
    Lc_Ctrl.DataBase := FCargaDB;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_PLANOCONTAS','PLC_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Plano de contas', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_FormaPagto;
Var
  Lc_Ctrl : TControllerFormaPagamento;
  I : Integer;
begin
  // Completa: referencia do billing e do financeiro (paymentTypeDescription).
  InicioEtapa('Formas de pagamento');
  Lc_Ctrl := TControllerFormaPagamento.Create(nil);
  try
    Lc_Ctrl.DataBase := FCargaDB;
    Lc_Ctrl.getlist;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_FORMAPAGTO','FPT_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Formas de pagamento', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Cliente;
Var
  Lc_Ctrl : TControllerCliente;
  I : Integer;
begin
  InicioEtapa('Clientes');
  Lc_Ctrl := TControllerCliente.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_CLIENTE','CLI_CODEMP',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Clientes', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_fornecedor;
Var
  Lc_Ctrl : TControllerFornecedor;
  I : Integer;
begin
  InicioEtapa('Fornecedores');
  Lc_Ctrl := TControllerFornecedor.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_FORNECEDOR','FOR_CODEMP',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Fornecedores', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Colaborador;
Var
  Lc_Ctrl : TControllerColaborador;
  I : Integer;
begin
  // Completa: referencia de vendedor do customer e dos movimentos (409 se faltar).
  InicioEtapa('Colaboradores/Vendedores');
  Lc_Ctrl := TControllerColaborador.Create(nil);
  try
    Lc_Ctrl.DataBase := FCargaDB;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_COLABORADOR','CLB_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Colaboradores/Vendedores', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_ContaBancaria;
Var
  Lc_Ctrl : TControllerContaBancaria;
  I : Integer;
begin
  // Completa: referencia do extrato (bankAccountId).
  InicioEtapa('Contas bancarias');
  Lc_Ctrl := TControllerContaBancaria.Create(nil);
  try
    Lc_Ctrl.DataBase := FCargaDB;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_CONTABANCARIA','CTB_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Contas bancarias', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Transportadora;
Var
  Lc_Ctrl : TControllerTransportadora;
  I : Integer;
begin
  // Completa: referencia de transportadora do customer (409 se faltar).
  InicioEtapa('Transportadoras');
  Lc_Ctrl := TControllerTransportadora.Create(nil);
  try
    Lc_Ctrl.DataBase := FCargaDB;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_TRANSPORTADORA','TRP_CODEMP',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Transportadoras', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

// ---- movimento (Seqs 20-33) ----

procedure TTasConfig.Fc_NotaFiscal;
Var
  Lc_Ctrl : TControllerNotaFiscal;
  I : Integer;
begin
  // UMA linha na fila por nota (Seqs 20-24): avulsa + processos de
  // servico/venda/compra/ajuste ('TODAS' - os filtros DISJUNTOS das
  // classes roteiam no envio, Rodada 3/D13).
  InicioEtapa('Notas fiscais (todos os fluxos)');
  Lc_Ctrl := TControllerNotaFiscal.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.TipoNota    := 'TODAS';
    Lc_Ctrl.TipoPedido  := 0;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_NOTA_FISCAL','NFL_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Notas fiscais (todos os fluxos)', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_MovimentoEstoque;
Var
  Lc_Ctrl : TControllerCtrlEstoque;
  I : Integer;
begin
  InicioEtapa('Movimentacao de estoque');
  Lc_Ctrl := TControllerCtrlEstoque.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_CTRL_ESTOQUE','CET_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Movimentacao de estoque', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_Financeiro;
Var
  Lc_Ctrl : TControllerFinanceiro;
  I : Integer;
begin
  // Periodo pela NOTA vinculada (FIN_CODNFL = orderId do espelho).
  InicioEtapa('Financeiro');
  Lc_Ctrl := TControllerFinanceiro.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getlist;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_FINANCEIRO','FIN_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Financeiro', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_MovimentoFinanceiro;
Var
  Lc_Ctrl : TControllerMovimentoFinanceiro;
  I : Integer;
begin
  InicioEtapa('Movimento financeiro (extrato)');
  Lc_Ctrl := TControllerMovimentoFinanceiro.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_MOVIM_FINANCEIRO','MVF_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Movimento financeiro (extrato)', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_ControleCaixa;
Var
  Lc_Ctrl : TControllerDskCashier;
  I : Integer;
begin
  InicioEtapa('Controle de caixa');
  Lc_Ctrl := TControllerDskCashier.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_CASHIER','ID',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Controle de caixa', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_RetornoNFe;
Var
  Lc_Ctrl : TControllerREtornoNfe;
  I : Integer;
begin
  InicioEtapa('Retornos NF-e');
  Lc_Ctrl := TControllerREtornoNfe.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_RETORNO_NFE','NFE_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Retornos NF-e', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_RetornoNFCe;
Var
  Lc_Ctrl : TControllerREtornoNFCe;
  I : Integer;
begin
  InicioEtapa('Retornos NFC-e');
  Lc_Ctrl := TControllerREtornoNFCe.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_RETORNO_NFC','NFC_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Retornos NFC-e', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_RetornoNFSe;
Var
  Lc_Ctrl : TControllerRetornoNFS;
  I : Integer;
begin
  InicioEtapa('Retornos NFS-e');
  Lc_Ctrl := TControllerRetornoNFS.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_RETORNO_NFS','NFS_CODNFL',Lc_Ctrl.Lista[I].CodigoNotaFiscal);
    FimEtapa('Retornos NFS-e', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_Arquivos;
Var
  Lc_Ctrl : TControllerArquivo;
  I : Integer;
begin
  InicioEtapa('Arquivos XML');
  Lc_Ctrl := TControllerArquivo.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Estabel     := 0;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getlistForSincronia;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_ARQUIVOS','ARQ_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Arquivos XML', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.FC_CartaCorrecao;
Var
  Lc_Ctrl : TcontrollerCartaCorrecao;
  I : Integer;
begin
  // Seq 33 - SET_ON 'N' ate a Rodada 4 (endpoint /invoice-rectification
  // ainda nao existe); nao aparece na checklist enquanto desligada.
  InicioEtapa('Cartas de correcao');
  Lc_Ctrl := TcontrollerCartaCorrecao.Create(nil);
  try
    Lc_Ctrl.DataBase    := FCargaDB;
    Lc_Ctrl.Periodo     := FCargaPeriodo;
    Lc_Ctrl.DataInicial := FCargaDataIni;
    Lc_Ctrl.DataFinal   := FCargaDataFim;
    Lc_Ctrl.getList;
    IniciaProgressoRegistros(Lc_Ctrl.Lista.Count);
    for I := 0 to Lc_Ctrl.Lista.Count -1 do
      Fc_InsertSicronia('TB_CARTA_CORRECAO','CCE_CODIGO',Lc_Ctrl.Lista[I].Codigo);
    FimEtapa('Cartas de correcao', Lc_Ctrl.Lista.Count);
  finally
    FreeAndNil(Lc_Ctrl);
  end;
end;

procedure TTasConfig.Fc_GrupoToCategoria;
begin
  // Conversao PROMOVIDA ao bootstrap (DM.MigraGruposParaCategoria,
  // 2026-08-01) - roda sozinha a cada start; este botao vira reexecucao
  // manual do MESMO motor (precedente: MnuPreparaLocal -> EnsureSincronia).
  // A versao antiga daqui so cobria produto com grupo E subgrupo - o motor
  // novo cobre tambem produto so com grupo e e idempotente (nao reenche a
  // fila com UPDATE de linha ja correta).
  Lb_Web_Process.Caption := 'Convertendo Grupos/Subgrupos em Categorias...';
  Lb_Web_Process.Update;
  DM.MigraGruposParaCategoria;
  Lb_Web_Process.Caption := 'Conversao de Categorias concluida';
  Lb_Web_Process.Update;
end;


procedure TTasConfig.Fc_InsertSicronia(pTable,pField: String; pCodigo:Integer);
begin
  ExecCargaRet(Format(
    'INSERT INTO TB_SINCRONIA ' +
    '(SRC_CODIGO, SRC_TABELA, SRC_CHAVE, SRC_OPER, SRC_REGISTRO, SRC_TIME) ' +
    'VALUES (0, ''%s'', ''%s'', ''I'', %d, CURRENT_TIMESTAMP)',
    [pTable, pField, pCodigo]
  ));
  Inc(FCargaRegAtual);
  AtualizaProgressoRegistros;
end;

procedure TTasConfig.FormatScreen;
begin
  pg_Principal.ActivePage := tbs_conexao;
end;

procedure TTasConfig.FormShow(Sender: TObject);
begin
  pg_Principal.ActivePage := tbs_conexao;
  // Primeira carga: lista fixa, indice 1:1 com os IFs do Sb_IntoQuueClick
  preencheListaPrimeiraCarga;
  preencheListaTabelas(ChLBx_Excecoes_Envio);
  preencheListaTabelas(ChLBx_Excecoes_Recebo);
  ShowConfig;
end;

procedure TTasConfig.preencheListaPrimeiraCarga;
begin
  // Lista FIXA na ordem do catalogo (Seqs 1-33). ATENCAO: o indice de cada
  // item casa 1:1 com os IFs do Sb_IntoQuueClick - alterou aqui, altera la.
  // Carta de Correcao fica FORA ate a Rodada 4 (Seq 33, SET_ON='N' -
  // enfileirar sem endpoint deixaria a fila presa).
  with ChLBx_First_Charge.Items do
  Begin
    Clear;
    Add('Usuario');                          // 0  - Fc_Usuario
    Add('Marca de Produto');                 // 1  - Fc_Marca
    Add('Categoria');                        // 2  - Fc_Categoria
    Add('Medida');                           // 3  - Fc_Medida
    Add('Embalagem');                        // 4  - Fc_Embalagem
    Add('Produto (mercadoria e servico)');   // 5  - Fc_Produto
    Add('Tabela de Preco');                  // 6  - Fc_TabelaPreco
    Add('Preco');                            // 7  - Fc_Preco
    Add('Estoques (depositos)');             // 8  - Fc_Estoques
    Add('Estoque (saldo)');                  // 9  - Fc_Estoque
    Add('Promocao');                         // 10 - Fc_Promotion
    Add('Plano de Contas');                  // 11 - Fc_PlanoContas
    Add('Forma de Pagamento');               // 12 - Fc_FormaPagto
    Add('Cliente');                          // 13 - Fc_Cliente
    Add('Fornecedor');                       // 14 - Fc_fornecedor
    Add('Colaborador/Vendedor');             // 15 - Fc_Colaborador
    Add('Conta Bancaria');                   // 16 - Fc_ContaBancaria
    Add('Transportadora');                   // 17 - Fc_Transportadora
    Add('Nota Fiscal (todos os fluxos)');    // 18 - Fc_NotaFiscal
    Add('Movimento de Estoque');             // 19 - FC_MovimentoEstoque
    Add('Financeiro');                       // 20 - Fc_Financeiro
    Add('Movimento Financeiro (extrato)');   // 21 - FC_MovimentoFinanceiro
    Add('Controle de Caixa');                // 22 - FC_ControleCaixa
    Add('Retorno NF-e');                     // 23 - FC_RetornoNFe
    Add('Retorno NFC-e');                    // 24 - FC_RetornoNFCe
    Add('Retorno NFS-e');                    // 25 - FC_RetornoNFSe
    Add('Arquivos XML');                     // 26 - FC_Arquivos
  End;
end;


procedure TTasConfig.preencheListaTabelas(Lista: TCheckListBox);
begin
  lista.Clear;
  lista.Items.Add('USUARIO');
  lista.Items.Add('CARGO');
  lista.Items.Add('COLABORADOR/VENDEDOR');
  lista.Items.Add('FORMAPAGTO');
  lista.Items.Add('GRUPOS');
  lista.Items.Add('SUBGRUPOS');
  lista.Items.Add('MARCA_PRODUTO');
  lista.Items.Add('MEDIDA');
  lista.Items.Add('EMBALAGEM');
  lista.Items.Add('PRODUTO');
  lista.Items.Add('ESTOQUES');
  lista.Items.Add('ESTOQUE');
  lista.Items.Add('TABELA_PRECO');
  lista.Items.Add('PRECO');
  lista.Items.Add('CLIENTE');
  lista.Items.Add('CONTABANCARIA');
  lista.Items.Add('FORNECEDOR');
  lista.Items.Add('CATEGORIAS');
  lista.Items.Add('IMAGEM DE PRODUTOS');
  lista.Items.Add('PROMO??O');
  lista.Items.Add('PLANOCONTAS');
  lista.Items.Add('PEDIDO COMPRA');
  lista.Items.Add('PEDIDO VENDA');
  lista.Items.Add('PEDIDO AJUSTE');
  lista.Items.Add('NOTA FISCAL MERCADORIA');
  lista.Items.Add('NOTA FISCAL AVULSA');
  lista.Items.Add('MOVIMENTO ESTOQUE');
  lista.Items.Add('FINANCEIRO');
  lista.Items.Add('MOVIMENTO FINANCEIRO');
  lista.Items.Add('CONTROLE DE CAIXA');
  lista.Items.Add('RETORNO NF-E');
  lista.Items.Add('RETORNO NFC-E');
  lista.Items.Add('RETORNO NFS-E');
  lista.Items.Add('CARTA DE CORRE??O');
  lista.Items.Add('ARQUIVOS');
  lista.Items.Add('CONSIGNA??O');
  lista.Items.Add('MENU CARDAPIO');
  lista.Items.Add('INGREDIENTES MENU');
  lista.Items.Add('GRUPO RESTAURANTE');
  lista.Items.Add('SUBGRUPO RESTAURANTE');
  lista.Items.Add('MEDIDAS GRUPO RESTAURANTE');
  lista.Items.Add('OPCIONAIS GRUPO RESTAURANTE');
  lista.Items.Add('OPCIONAIS BORDA - TESTE');
  lista.Items.Add('HISTBANCARIO');
  lista.Items.Add('CASHIER');
end;


procedure TTasConfig.ShowConfig;
begin
  E_Path_BD_Local.Text            := Fc_Aq_Geral('L','SISWEB', 'BDPathBDLocal','');

  E_Intervalo.Text                := Fc_Aq_Geral('L','SISWEB', 'intervalo','0') ;

  E_NoMinuto.Text                 := Fc_Aq_Geral('L','SISWEB', 'nominuto','5');


  Chbx_AutoMinimize.Checked       := (Fc_Aq_Geral('L','SISWEB', 'AutoMinimize','S') = 'S');

  ChBx_IniciarWindows.Checked     := (Fc_Aq_Geral('L','SISWEB', 'startWind','S') = 'S' );


  E_Path_url.Text                 := Fc_Aq_Geral('L', 'SISWEB', 'FPathURL','0');

  E_ApiKey.Text                   := Fc_Aq_Geral('L', 'SISWEB', 'FApiKey','');


  E_Terminal.Text                 := Fc_Aq_Geral('L', 'SISWEB', 'TERMINAL','0');

  Chbx_ReceiveWebServer.Checked   := ( Fc_Aq_Geral('L','SISWEB', 'ReceiveWebServer','S') = 'S');

  Chbx_SendToWebServer.Checked    := ( Fc_Aq_Geral('L','SISWEB', 'SendToWebServer','S') = 'S');

  ShowExcecoes;
end;





procedure TTasConfig.ShowExcecoes;
Var
  I:Integer;
begin
  //Envio
  for I := 0 to ChLBx_Excecoes_Envio.Count -1 do
  Begin
    ChLBx_Excecoes_Envio.Checked[I] := ( Fc_Aq_Geral('L','SISWEB_EXC_ENVI', ChLBx_Excecoes_Envio.Items[I],'N') = 'S' );
  End;
  //Recebimento
  for I := 0 to ChLBx_Excecoes_Recebo.Count -1 do
  Begin
    ChLBx_Excecoes_Recebo.Checked[I] := ( Fc_Aq_Geral('L','SISWEB_EXC_RECE', ChLBx_Excecoes_Recebo.Items[I],'N') = 'S' );
  End;

end;

procedure TTasConfig.SalvaExcecoes;
Var
  I:Integer;
begin
  //Envio
  for I := 0 to ChLBx_Excecoes_Envio.Count -1 do
  Begin
    if ChLBx_Excecoes_Envio.Checked[I] then
      Fc_Aq_Geral('G','SISWEB_EXC_ENVI', ChLBx_Excecoes_Envio.Items[I],'S')
    else
      Fc_Aq_Geral('G','SISWEB_EXC_ENVI', ChLBx_Excecoes_Envio.Items[I],'N');
  End;
  //Recebimento
  for I := 0 to ChLBx_Excecoes_Recebo.Count -1 do
  Begin
    if ChLBx_Excecoes_Recebo.Checked[I] then
      Fc_Aq_Geral('G','SISWEB_EXC_RECE', ChLBx_Excecoes_Recebo.Items[I],'S')
    else
      Fc_Aq_Geral('G','SISWEB_EXC_RECE', ChLBx_Excecoes_Recebo.Items[I],'N');
  End;


end;

procedure TTasConfig.SaveConfig;
begin
  Fc_Aq_Geral('G','SISWEB', 'BDPathBDLocal',E_Path_BD_Local.Text);

  Fc_Aq_Geral('G', 'SISWEB', 'intervalo',E_Intervalo.Text);

  Fc_Aq_Geral('G', 'SISWEB', 'nominuto',E_NoMinuto.Text);

  if Chbx_AutoMinimize.Checked then
    Fc_Aq_Geral('G', 'SISWEB', 'AutoMinimize','S')
  else
    Fc_Aq_Geral('G', 'SISWEB', 'AutoMinimize','N');


  if ChBx_IniciarWindows.Checked then
    Fc_Aq_Geral('G', 'SISWEB', 'startWind','S')
  else
    Fc_Aq_Geral('G', 'SISWEB', 'startWind','N');



  if Chbx_ReceiveWebServer.Checked then
    Fc_Aq_Geral('G', 'SISWEB', 'ReceiveWebServer','S')
  else
    Fc_Aq_Geral('G', 'SISWEB', 'ReceiveWebServer','N');

  if Chbx_SendToWebServer.Checked then
    Fc_Aq_Geral('G', 'SISWEB', 'SendToWebServer','S')
  else
    Fc_Aq_Geral('G', 'SISWEB', 'SendToWebServer','N');

  Fc_Aq_Geral('G', 'SISWEB', 'FPathURL',E_Path_url.Text);

  Fc_Aq_Geral('G', 'SISWEB', 'FApiKey',Trim(E_ApiKey.Text));


  Fc_Aq_Geral('G', 'SISWEB', 'TERMINAL',E_Terminal.Text);

  SalvaExcecoes;

end;



procedure TTasConfig.Sb_CloseClick(Sender: TObject);
begin
  Close;
end;

procedure TTasConfig.Sb_primeira_cargaClick(Sender: TObject);
begin
  if validaConfig then
  Begin
    ExecStartWin;
    SaveConfig;
    Close;
  End;
end;

procedure TTasConfig.Sb_IntoQuueClick(Sender: TObject);
Var
  I          : Integer;
  LcMarcadas : Integer;
  LcMarc     : TArray<Boolean>;
begin
  // Primeira carga por procedure NOMEADA (Valdo, 2026-08-04): cada tabela
  // marcada executa a SUA Fc_* "colocar na fila". As Fc_* rodam numa THREAD
  // com conexao propria (a tela NAO congela em tabela grande); label e gauge
  // atualizam via TThread.Queue e todo o contexto de UI e capturado AQUI,
  // antes de iniciar a thread.
  if ChBx_Periodo.Checked and
     (Trunc(Dtp_Data_Inicial.Date) > Trunc(Dtp_Data_Final.Date)) then
  Begin
    ShowMessage('Periodo invalido: a data inicial deve ser menor ou igual a data final.');
    Exit;
  End;

  // Captura os checks (indice 1:1 com preencheListaPrimeiraCarga e com os
  // IFs da thread abaixo); nada marcado = aviso claro
  SetLength(LcMarc, 27);
  LcMarcadas := 0;
  for I := 0 to High(LcMarc) do
  Begin
    LcMarc[I] := (I < ChLBx_First_Charge.Items.Count) and
                 ChLBx_First_Charge.Checked[I];
    if LcMarc[I] then Inc(LcMarcadas);
  End;
  if LcMarcadas = 0 then
  Begin
    ShowMessage('Nenhuma tabela marcada na lista da primeira carga.');
    Exit;
  End;

  // Contexto para a thread (controle de UI nao se le fora da main thread)
  FCargaPeriodo   := ChBx_Periodo.Checked;
  FCargaDataIni   := Dtp_Data_Inicial.DateTime;
  FCargaDataFim   := Dtp_Data_Final.DateTime;
  FCargaDtIniTela := FormatDateTime('dd/mm/yyyy', Dtp_Data_Inicial.Date);
  FCargaDtFimTela := FormatDateTime('dd/mm/yyyy', Dtp_Data_Final.Date);
  FResumoCarga    := '';
  FCargaEtapa     := 0;
  FCargaTotal     := LcMarcadas;

  // Janela desabilitada mas VIVA: a thread trabalha e a UI segue repintando
  // Gauge (2026-08-09): valor placeholder ate a primeira Fc_* chamar
  // IniciaProgressoRegistros com o total REAL de registros da tabela -
  // GG_Web_Process acompanha registro a registro, nao mais tabela a tabela.
  Self.Enabled := False;
  GG_Web_Process.MinValue := 0;
  GG_Web_Process.MaxValue := 1;
  GG_Web_Process.Progress := 0;
  GG_Web_Process.Update;
  Lb_Web_Process.Caption := 'Preparando primeira carga...';

  TThread.CreateAnonymousThread(
    procedure
    Var
      LcErro : String;
    begin
      LcErro := '';
      try
        try
          AbreConexaoCarga;
          // cadastros
          if LcMarc[0]  then Fc_Usuario;
          if LcMarc[1]  then Fc_Marca;
          if LcMarc[2]  then Fc_Categoria;
          if LcMarc[3]  then Fc_Medida;
          if LcMarc[4]  then Fc_Embalagem;
          if LcMarc[5]  then Fc_Produto;
          if LcMarc[6]  then Fc_TabelaPreco;
          if LcMarc[7]  then Fc_Preco;
          if LcMarc[8]  then Fc_Estoques;
          if LcMarc[9]  then Fc_Estoque;
          if LcMarc[10] then Fc_Promotion;
          if LcMarc[11] then Fc_PlanoContas;
          if LcMarc[12] then Fc_FormaPagto;
          if LcMarc[13] then Fc_Cliente;
          if LcMarc[14] then Fc_fornecedor;
          if LcMarc[15] then Fc_Colaborador;
          if LcMarc[16] then Fc_ContaBancaria;
          if LcMarc[17] then Fc_Transportadora;
          // movimento
          if LcMarc[18] then Fc_NotaFiscal;
          if LcMarc[19] then FC_MovimentoEstoque;
          if LcMarc[20] then Fc_Financeiro;
          if LcMarc[21] then FC_MovimentoFinanceiro;
          if LcMarc[22] then FC_ControleCaixa;
          if LcMarc[23] then FC_RetornoNFe;
          if LcMarc[24] then FC_RetornoNFCe;
          if LcMarc[25] then FC_RetornoNFSe;
          if LcMarc[26] then FC_Arquivos;
        except
          on E: Exception do
            LcErro := E.Message;
        end;
      finally
        FechaConexaoCarga;
        TThread.Queue(nil,
          procedure
          begin
            Self.Enabled := True;
            GG_Web_Process.Progress := 0;
            GG_Web_Process.Update;
            if LcErro <> '' then
            Begin
              Lb_Web_Process.Caption := 'Primeira carga interrompida por erro.';
              ShowMessage(concat(
                'Primeira carga interrompida: ', LcErro, sLineBreak, sLineBreak,
                'O que ja tinha entrado na fila permanece valido:', sLineBreak,
                FResumoCarga));
            End
            else
            Begin
              Lb_Web_Process.Caption := 'Primeira carga concluida.';
              if FCargaPeriodo then
                ShowMessage(concat(
                  'Primeira carga concluida: ', IntToStr(FCargaEtapa),
                  ' tabela(s) na fila de sincronia.', sLineBreak,
                  'Periodo aplicado: ', FCargaDtIniTela, ' a ', FCargaDtFimTela,
                  ' (enviar somente o que for do periodo).', sLineBreak, sLineBreak,
                  'Registros colocados na fila:', sLineBreak, FResumoCarga, sLineBreak,
                  'O envio acontece no proximo ciclo do sincronizador.'))
              else
                ShowMessage(concat(
                  'Primeira carga concluida: ', IntToStr(FCargaEtapa),
                  ' tabela(s) na fila de sincronia.', sLineBreak, sLineBreak,
                  'Registros colocados na fila:', sLineBreak, FResumoCarga, sLineBreak,
                  'O envio acontece no proximo ciclo do sincronizador.'));
            End;
          end);
      end;
    end).Start;
end;

function TTasConfig.validaConfig: Boolean;
begin
  Result := True;
  if (StrToIntDef(E_Intervalo.Text,0) < 1 ) and (StrToIntDef(E_Intervalo.Text,0) >0 ) then
  BEgin
    ShowMessage(concat(
                  'O Intervalo deve ser maior do que 1 minuto.',#13,
                  'Caso não deseje usar o temporizador preencha com 0(zero)',#13,
                  'Impossível continuar. '
                  ));
    Result := FAlse;
    exit;
  End;
  if not VerificaConectaBanco(True,E_Path_BD_Local.Text) then
  Begin
    ShowMessage(concat(
                  'O Banco de dados local não está disponível.',#13,
                  'Verifique antes de continuar. '
                  ));
    Result := False;
    exit;
  End;

end;



end.
