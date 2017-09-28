unit KM_TerrainPainter;
{$I KaM_Remake.inc}
interface
uses
  Classes, KromUtils, Math, SysUtils,
  KM_CommonClasses, KM_Defaults, KM_Points,
  KM_Terrain, KM_ResTileset;

const
  MAX_UNDO = 50;

type
  //Tile data that we store in undo checkpoints
  TKMUndoTile = packed record
    BaseLayer: TKMTerrainLayer;
    LayersCnt: Byte;
    Layer: array [0..2] of TKMTerrainLayer;
    Height: Byte;
    Obj: Byte;
    TerKind: TKMTerrainKind;
  end;

  TKMPainterTile = packed record
    TerKind: TKMTerrainKind; //Stores terrain type per node
    Tiles: SmallInt;  //Stores kind of transition tile used, no need to save into MAP footer
    HeightAdd: Byte; //Fraction part of height, for smooth height editing
  end;

  TKMTerrainKindsArray = array of TKMTerrainKind;

  //Terrain helper that is used to paint terrain types in Map Editor
  TKMTerrainPainter = class
  private
    fUndoPos: Byte;
    fUndos: array [0..MAX_UNDO-1] of record
      HasData: Boolean;
      Data: array of array of TKMUndoTile;
    end;
    fTime: array[0..12] of record
      Desc: String;
      Data: Cardinal;
    end;

    TempLand: array of array of TKMTerrainTileBasic;

    MapXn, MapYn: Integer; //Cursor position node
    MapXc, MapYc: Integer; //Cursor position cell
    MapXn2, MapYn2: Integer; //keeps previous node position
    MapXc2, MapYc2: Integer; //keeps previous cell position

    function GetTileCornersTerrainKinds(aTile: TKMTerrainTileBasic): TKMTerrainKindsArray;
    procedure CheckpointToTerrain;
    procedure BrushTerrainTile(X, Y: SmallInt; aTerrainKind: TKMTerrainKind);
    procedure MagicBrush(const aLocation: TKMPoint; aOnlyCell: Boolean = True; aUseTempLand: Boolean = True);
    procedure UseMagicBrush(X,Y,Rad: Integer; aSquare: Boolean);
    procedure UpdateTempLand;
    procedure EditBrush(const aLoc: TKMPoint);
    procedure EditHeight;
    procedure EditTile(const aLoc: TKMPoint; aTile: Word; aRotation: Byte);
    procedure GenerateAddnData;
    procedure InitSize(X,Y: Word);
    function PickRandomTile(aTerrainKind: TKMTerrainKind): Word;
  public
    LandTerKind: array of array of TKMPainterTile;
    RandomizeTiling: Boolean;
    procedure InitEmpty;
    procedure LoadFromFile(const aFileName: UnicodeString);
    procedure SaveToFile(const aFileName: UnicodeString); overload;
    procedure SaveToFile(const aFileName: UnicodeString; const aInsetRect: TKMRect); overload;
    procedure Eyedropper(const aLoc: TKMPoint);
    procedure RebuildMap(X,Y,Rad: Integer; aSquare: Boolean); overload;
    procedure RebuildMap(const aRect: TKMRect); overload;
    procedure RotateTile(const aLoc: TKMPoint);
    procedure RebuildTile(X,Y: Integer);

    procedure MagicWater(const aLoc: TKMPoint);

    function CanUndo: Boolean;
    function CanRedo: Boolean;

    procedure MakeCheckpoint;
    procedure Undo;
    procedure Redo;

    procedure UpdateStateIdle;
    procedure UpdateState;
  end;


  function GetCombo(aTerKindFrom, aTerKindTo: TKMTerrainKind; aTransition: Byte; var aFound: Boolean): SmallInt;

const
  //Table of combinations between terrain types (0-based)
  //1 - no transition
  //2 - in half
  //3 - one corner
  //"-" means flip before use
  Combo: array [TKMTerrainKind, TKMTerrainKind, 1..3] of SmallInt = (
  //             Custom    Grass         Moss   PaleGrass        CoastSand      GrassSand1  GrassSand2      GrassSand3          Sand    GrassDirt     Dirt           Cobblest        GrassyWater   Swamp        Ice          ShallowSnow    Snow           DeepSnow     StoneMount       GoldMount        IronMount         Abyss          Gravel        Coal               Gold             Iron           Water           FastWater    Lava
  {Custom}     ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Custom
  {Grass}      ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Grass
  {Moss}       ((0,0,0),(-19, -18,  9),(8,8,8),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Moss
  {PaleGrass}  ((0,0,0),( 66,  67, 68),(0,0,0),( 17, 17, 17),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //PaleGrass
  {CoastSand}  ((0,0,0),( 69,  70, 71),(0,0,0),(  0,  0,  0),(   32,  32,  32),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //CoastSand
  {GrassSand1} ((0,0,0),( 72,  73, 74),(0,0,0),(  0,  0,  0),(    0,   0,   0),(26,26,26),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //GrassSand1
  {GrassSand2} ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(  102, 103, 104),(75,76,77),(  27,  27,  27),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //GrassSand2
  {GrassSand3} ((0,0,0),( 93,  94, 95),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(  78,  79,  80),( 28, 28, 28),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //GrassSand3
  {Sand}       ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(   99, 100, 101),( 0, 0, 0),(  81,  82,  83),( 81, 82, 83),( 29, 29, 29),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Sand
  {GrassDirt}  ((0,0,0),( 84,  85, 86),(0,0,0),(-98,-97,-96),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),(34,34,34),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //GrassDirt
  {Dirt}       ((0,0,0),( 56,  57, 58),(0,0,0),(  0,  0,  0),( -113,-112,-111),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),(87,88,89),(  35,  35,  35),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Dirt
  {Cobblest}   ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(  38,  39, 215),( 215, 215, 215),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Cobblestone
  {GrassyWater}((0,0,0),(120, 121,122),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),( 48, 48, 48),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //GrassyWater
  {Swamp}      ((0,0,0),( 90,  91, 92),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),(40,40,40),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Swamp
  {Ice}        ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),( 44, 44, 44),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Ice
  {ShallowSnow}((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),( 247,  64,  65),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),( 47, 47,  47),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //ShallowSnow
  {Snow}       ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),( 44, -4,-10),(220,212, 213),( 46, 46,   46),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Snow
  {DeepSnow}   ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(203,204,  205),(45,45,45),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //DeepSnow
  {StoneMount} ((0,0,0),(  0, 139,138),(0,0,0),(  0,  0,  0),(  276, 272, 271),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),( 132, 132, 132),(   0,   0,   0),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Stone Mountain
  {GoldMount}  ((0,0,0),(180, 172,176),(0,0,0),(  0,  0,  0),(  181, 173, 177),( 0, 0, 0),( 182, 174, 178),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),( 183, 175, 179),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),( 49,171,  51),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),( 159, 159, 159),(   0,   0,   0),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Gold Mountains
  {IronMount}  ((0,0,0),(188, 168,184),(0,0,0),(  0,  0,  0),(  189, 169, 185),( 0, 0, 0),( 190, 170, 186),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),( 191, 167, 187),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),( 52,166,   54),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),( 164, 164, 164),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Iron Mountains
  {Abyss}      ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),( -53, -50,-165),(245, 0,    0),(  0,  0,  0),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Abyss
  {Gravel}     ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),( -113,-112,-111),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(  21,  21,  20),( -38, -39, -38),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(-65,-64,-247),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(-179,-175,-183),(-187,-167,-191),(  0, 0,    0),( 20, 20, 20),(  0,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Gravel
  {Coal}       ((0,0,0),( 56,  57, 58),(0,0,0),(  0,  0,  0),( -113,-112,-111),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),(87,88,89),( 152, 153, 154),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(-65,-64,-247),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),(-179,-175,-183),(-187,-167,-191),(  0,  0,   0),(  0,  0,  0),(155,    0,    0),(   0,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Coal
  {Gold}       ((0,0,0),(180, 172,176),(0,0,0),(  0,  0,  0),(  181, 173, 177),( 0, 0, 0),( 182, 174, 178),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),( 183, 175, 179),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),( 49,171,  51),(261,262,{*}46),( 0, 0, 0),(   0,   0,   0),( 144, 145, 146),(   0,   0,   0),(  0,  0,   0),(183,175,179),(183,  175,  179),( 147,   0,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Gold
  {Iron}       ((0,0,0),(188, 168,184),(0,0,0),(  0,  0,  0),(  189, 169, 185),( 0, 0, 0),( 190, 170, 186),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),( 191, 167, 187),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(256,257, 258),( 52,166,   54),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),( 148, 149, 150),(-53,-50,-165),(191,167,187),(191,	167,	187),(   0,   0,   0),( 151,   0,   0),(   0,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Iron
  {Water}      ((0,0,0),(123,-125,127),(0,0,0),(  0,  0,  0),(  116,-117, 118),( 0, 0, 0),(-243,-242,-241),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(-107,-106,-105),(-107,-106,-105),(114,115,119),( 0, 0, 0),(-22,-12,-23),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(-143,-200,-236),(-237,-200,-236),(-239,-200,-236),(245, 0,    0),(  0,  0,  0),(-107,-106, -105),(-237,-200,-236),(-239,-200,-236),( 192,   0,   0),(   0, 0, 0),(   0, 0, 0)), //Water
  {FastWater}  ((0,0,0),(123,-125,127),(0,0,0),(  0,  0,  0),(  116,-117, 118),( 0, 0, 0),(-243,-242,-241),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(-107,-106,-105),(-107,-106,-105),(114,115,119),( 0, 0, 0),(-22,-12,-23),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(-143,-200,-236),(-237,-200,-236),(-239,-200,-236),(245, 0,    0),(  0,  0,  0),(-107,-106, -105),(-237,-200,-236),(-239,-200,-236),( 192, 192, 209),( 209, 0, 0),(   0, 0, 0)), //FastWater
  {Lava}       ((0,0,0),(  0,   0,  0),(0,0,0),(  0,  0,  0),(    0,   0,   0),( 0, 0, 0),(   0,   0,   0),(  0,  0,  0),(  0,  0,  0),( 0, 0, 0),(   0,   0,   0),(   0,   0,   0),(  0,  0,  0),( 0, 0, 0),(  0,  0,  0),(  0,  0,   0),(  0,  0,    0),( 0, 0, 0),(   0,   0,   0),( 159, 159, -15),( 164, 164,   7),(  0, 0,    0),(  0,  0,  0),(  0,    0,    0),( 147, 147,   0),(   0,   0,   0),(   0,   0,   0),(   0, 0, 0),(   7, 7, 7))  //Lava
               );

  //0     number of variants (1..X)
  //1..X  tile variants
  //
  RandomTiling: array [tkCustom..tkLava, 0..15] of Word = (
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (15,1,1,1,2,2,2,3,3,3,5,5,5,11,13,14), // Grass - reduced chance for "eye-catching" tiles
    (2,9,11,0,0,0,0,0,0,0,0,0,0,0,0,0),    // Moss
    (1,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0),    // PaleGrass
    (2,31,33,0,0,0,0,0,0,0,0,0,0,0,0,0),   // CoastSand
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // GrassSand1
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // GrassSand2
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // GrassSand3
    (1,30,0,0,0,0,0,0,0,0,0,0,0,0,0,0),    // Sand
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // GrassDirt
    (2,36,37,0,0,0,0,0,0,0,0,0,0,0,0,0),   // Dirt
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // Cobblestone
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // GrassyWater
    (3,41,42,43,0,0,0,0,0,0,0,0,0,0,0,0),  // Swamp
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // Ice
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // ShallowSnow
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // Sbow
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),     // DeepSnow
    (8,129,130,131,132,134,135,136,137,0,0,0,0,0,0,0),    // StoneMount
    (5,156,157,158,159,201{?},0,0,0,0,0,0,0,0,0,0),       // GoldMount
    (5,160,161,162,163,164,0,0,0,0,0,0,0,0,0,0),          // IronMount
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),                    // Abyss
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),                    // Gravel
    (9,152,153,154,154,154,155,155,155,155,0,0,0,0,0,0),  // Coal (enriched pattern)
    (9,144,145,146,146,146,147,147,147,147,0,0,0,0,0,0),  // Gold
    (13,148,149,150,150,151,151,151,151,259,259,260,260,260,0,0),//259,260,260,260,0,0),  // Iron
    (2,193,193,0,0,0,0,0,0,0,0,0,0,0,0,0),  // Water
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),      // FastWater
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)       // Lava
  );


implementation
uses
  KM_GameCursor, KM_Resource, KM_Log, KM_CommonUtils, KM_Utils, KM_CommonTypes, KM_ResSprites;


function GetCombo(aTerKindFrom, aTerKindTo: TKMTerrainKind; aTransition: Byte; var aFound: Boolean): SmallInt;
begin
  aFound := True;
  Result := Combo[aTerKindFrom, aTerKindTo, aTransition];
  if (Result = 0)
    and not ((aTerKindFrom = tkGrass) and (aTerKindTo = tkGrass))
    and (aTerKindTo <> tkCustom)
    and (aTerKindFrom <> tkCustom) then
  begin
    //We have no direct transition
    aFound := False;

  end;


end;


{ TKMTerrainPainter }
procedure TKMTerrainPainter.BrushTerrainTile(X, Y: SmallInt; aTerrainKind: TKMTerrainKind);
begin
  if not gTerrain.TileInMapCoords(X, Y) then
    Exit;

  LandTerKind[Y, X].TerKind := aTerrainKind;
  LandTerKind[Y, X + 1].TerKind := aTerrainKind;
  LandTerKind[Y + 1, X + 1].TerKind := aTerrainKind;
  LandTerKind[Y + 1, X].TerKind := aTerrainKind;

  gTerrain.Land[Y, X].BaseLayer.Terrain := PickRandomTile(TKMTerrainKind(gGameCursor.Tag1));
  gTerrain.Land[Y, X].BaseLayer.Rotation := Random(4); //Random direction for all plain tiles
end;


function TKMTerrainPainter.PickRandomTile(aTerrainKind: TKMTerrainKind): Word;
begin
  Result := Abs(Combo[aTerrainKind, aTerrainKind, 1]);
  if not RandomizeTiling or (RandomTiling[aTerrainKind, 0] = 0) then Exit;

  if aTerrainKind in [tkStone..tkIronMount, tkCoal..tkIron] then
    //Equal chance
    Result := RandomTiling[aTerrainKind, Random(RandomTiling[aTerrainKind, 0]) + 1]
  else
  if Random(6) = 1 then
    //Chance reduced to 1/6
    Result := RandomTiling[aTerrainKind, Random(RandomTiling[aTerrainKind, 0]) + 1];
end;


procedure TKMTerrainPainter.RebuildTile(X,Y: Integer);
var
  pY, pX, Nodes, Rot, T: Integer;
  Tmp, Ter1, Ter2, A, B, C, D: TKMTerrainKind;
  Found: Boolean;
begin
  pX := EnsureRange(X, 1, gTerrain.MapX - 1);
  pY := EnsureRange(Y, 1, gTerrain.MapY - 1);

  //don't touch custom placed tiles (tkCustom type)
  if (LandTerKind[pY  ,pX].TerKind <> tkCustom)
    and (LandTerKind[pY  ,pX+1].TerKind <> tkCustom)
    and (LandTerKind[pY+1,pX].TerKind <> tkCustom)
    and (LandTerKind[pY+1,pX+1].TerKind <> tkCustom) then
  begin
    A := (LandTerKind[pY    , pX    ].TerKind);
    B := (LandTerKind[pY    , pX + 1].TerKind);
    C := (LandTerKind[pY + 1, pX    ].TerKind);
    D := (LandTerKind[pY + 1, pX + 1].TerKind);
    Rot := 0;
    Nodes := 1;

    //A-B
    //C-D
    Ter1 := tkCustom;
    Ter2 := tkCustom;

    if (A=B)or(C=D)  then begin Ter1:=A; Ter2:=C; Nodes:=2; if A<C then Rot:=2 else Rot:=0; end;
    if (A=C)or(B=D)  then begin Ter1:=A; Ter2:=B; Nodes:=2; if A<B then Rot:=1 else Rot:=3; end;

    //special case \ and /
    if A=D then begin Ter1:=A; Ter2:=B; Nodes:=4+1; Rot:=1; end;
    if B=C then begin Ter1:=A; Ter2:=B; Nodes:=4+2; Rot:=0; end;

    if (A=B)and(C=D) then begin Ter1:=A; Ter2:=C; Nodes:=2; if A<C then Rot:=2 else Rot:=0; end;
    if (A=C)and(B=D) then begin Ter1:=A; Ter2:=B; Nodes:=2; if A<B then Rot:=1 else Rot:=3; end;

    if (B=C)and(C=D) then begin Ter1:=C; Ter2:=A; Nodes:=3; if C<A then Rot:=3 else Rot:=1; end;
    if (A=C)and(C=D) then begin Ter1:=A; Ter2:=B; Nodes:=3; if A<B then Rot:=0 else Rot:=2; end;
    if (A=B)and(B=D) then begin Ter1:=A; Ter2:=C; Nodes:=3; if A<C then Rot:=2 else Rot:=0; end;
    if (A=B)and(B=C) then begin Ter1:=A; Ter2:=D; Nodes:=3; if A<D then Rot:=1 else Rot:=3; end;

    if (A=B)and(B=C)and(C=D) then begin Ter1:=A; Ter2:=A; Nodes:=4; Rot:=0; end;

    //Terrain table has only half filled, so make sure first comes bigger ID
    if Ter1 < Ter2 then
    begin
     Tmp := Ter1;
     Ter1 := Ter2;
     Ter2 := Tmp;
     case Nodes of
        1..3: Nodes := 4 - Nodes;  //invert nodes count
        5..6: Rot := 1;
      end;
    end;

    //Some tiles placed upside down or need other special treatment
    if Nodes < 4 then
    begin
      //Flip direction
      if Combo[Ter1, Ter2, Nodes] < 0 then
        Rot := (Rot + 2) mod 4;
      //For some weird reason lava needs to be rotated 90`
      if Ter1 = tkLava then
        Rot := (Rot + 1) mod 4;
    end;

    T := 0;
    if Nodes < 4 then T := Abs(GetCombo(Ter1, Ter2, Nodes, Found));     //transition tiles
    if Nodes = 4 then T := Abs(GetCombo(Ter1, Ter2, 1, Found));         //no transition
    if Nodes > 4 then T := Abs(GetCombo(Ter1, Ter2, 3, Found));         //transition use 1 or 3

    //for plain tiles only
    if Ter1 = Ter2 then
    begin
      T := PickRandomTile(Ter1);

      Rot := Random(4); //random direction for all plain tiles
    end;

    //Need to check if this tile was already smart-painted, "4-Nodes" hence default value is 0
    if (LandTerKind[pY,pX].Tiles <> Byte(Ter1)*Byte(Ter2)*(4-Nodes))
      or (gTerrain.Land[pY,pX].LayersCnt > 0) then
    begin
      LandTerKind[pY,pX].Tiles := Byte(Ter1)*Byte(Ter2)*(4-Nodes);//store not only nodes info, but also terrain type used
      if Found then
      begin
        gTerrain.Land[pY,pX].BaseLayer.Terrain := T;
        gTerrain.Land[pY,pX].BaseLayer.Corners := [0,1,2,3];
        gTerrain.Land[pY,pX].LayersCnt := 0;
        gTerrain.Land[pY,pX].BaseLayer.Rotation := Rot mod 4;
      end
    end;
  end;
end;


procedure TKMTerrainPainter.RebuildMap(const aRect: TKMRect);
var
  I, K: Integer;
begin
  for I := aRect.Top to aRect.Bottom do
    for K := aRect.Left to aRect.Right do
      RebuildTile(K,I);
end;


procedure TKMTerrainPainter.RebuildMap(X,Y,Rad: Integer; aSquare: Boolean);
var
  I, K: Integer;
begin
  for I := -Rad to Rad do
    for K := -Rad to Rad do
      if aSquare or (Sqr(I) + Sqr(K) < Sqr(Rad)) then
        RebuildTile(X+K,Y+I);
end;


function TKMTerrainPainter.GetTileCornersTerrainKinds(aTile: TKMTerrainTileBasic): TKMTerrainKindsArray;
  function GetBaseLayerTerKinds: TKMTerrainKindsArray;
  var I: Integer;
  begin
    SetLength(Result, 4);
    for I := 0 to 3 do
      if I in aTile.BaseLayer.Corners then
        Result[I] := TILE_CORNERS_TERRAIN_KINDS[aTile.BaseLayer.Terrain, (I + 4 - aTile.BaseLayer.Rotation) mod 4]
      else
        Result[I] := tkCustom;
  end;

var
  I,L: Integer;
  TerKind: TKMTerrainKind;
begin
  Result := GetBaseLayerTerKinds;

  if aTile.LayersCnt > 0 then
  begin
    for L := 0 to aTile.LayersCnt - 1 do
    begin
      for I := 0 to 3 do
      begin
        if I in aTile.Layer[L].Corners then
        begin
          TerKind := gRes.Sprites.GetGenTerrainKindByTerrain(aTile.Layer[L].Terrain);
          if TerKind <> tkCustom then
            Result[I] := TerKind;
        end;
      end;
    end;
  end;
end;


procedure TKMTerrainPainter.MagicBrush(const aLocation: TKMPoint; aOnlyCell: Boolean = True; aUseTempLand: Boolean = True);

type
  TMaskInfo = record
    TerKind: TKMTerrainKind;
    Rotation: Integer;
    SubType: Integer;
    Corners: set of Byte;
  end;

  //This method tries to find the best appropriate TerKind for target cell (aCell) and for specified corner (aCorner)
  //1. We get cells next to aCell aCorner, and within map sizes
  //2. get TerKind from that cells, from corners, which are 'connected' to aCell aCorner, which are jointed
  //3. there could be several possibilities:
  // - no cells were found around aCell (map corner) - return aFound = False
  // - Found several Cells, Get several TerKinds, then
  //   - choose most popular one first
  //   - if all are different (1 occurences for each) then choose from diagonal cell
  //   - else take first one clockwise
  function GetCornerTerKind(aCorner: Byte; aCell: TKMPoint; var aFound: Boolean): TKMTerrainKind;
  var
    I, J, K: Integer;
    Rect: TKMRect;
    Dir: TKMDirection;
    RectCorners: TKMPointArray;
    DiagTerKind: TKMTerrainKind;
    HasCornerTiles: Boolean;
    TerKinds: array [0..2] of TKMTerrainKind;
  begin
    Result := tkCustom;
    case aCorner of
      0: Dir := dir_NW;
      1: Dir := dir_NE;
      2: Dir := dir_SE;
      3: Dir := dir_SW;
      else raise Exception.Create('Unknown direction'); // Makes compiler happy
    end;
    //get 4 tiles around corner within map borders
    Rect := KMRect(aCell);                                            // x x  - we will get these x Tiles for corner 0, f.e.
    Rect := KMRectGrow(Rect, Dir);                                    // x o
    Rect := KMClipRect(Rect, 1, 1, gTerrain.MapX, gTerrain.MapY);     //
    RectCorners := KMRectCorners(Rect);                               //
    //after this preparation we will get 4 points (rect corners)

    K := 0;
    //DiagTerKind := tkNone;
    DiagTerKind := tkCustom;
    HasCornerTiles := False;
    for I := 0 to Length(RectCorners) - 1 do
    begin
      J := (I + aCorner) mod 4;
      if not KMSamePoint(aCell, RectCorners[J]) then //If rect was clipped due to map sizes restriction, then its corner will be same as our target cell (aCell)
      begin
        HasCornerTiles := True;
        //From all tile terkinds get corner we need.
        //we used that fact, that corner formula can be obtained as (I + aCorner + 2).
        //so f.e. for 0 corner, and tile 'above' (tile to the top from tasrget cell(aCell)) we have to get terrainKind from corner 3
        //3 = 1 (I, start from top left alwaysm top tile is the 2nd tile) + 0 (aCorner) + 2
        //and so on
        if aUseTempLand then
          TerKinds[K] := GetTileCornersTerrainKinds(TempLand[RectCorners[J].Y,RectCorners[J].X])[(I+aCorner+2) mod 4]
        else
          TerKinds[K] := GetTileCornersTerrainKinds(GetTerrainTileBasic(gTerrain.Land[RectCorners[J].Y,RectCorners[J].X]))[(I+aCorner+2) mod 4];
        // Find diagTerKind, as its preferrable over other cells
        if (aCell.X <> RectCorners[J].X) and (aCell.Y <> RectCorners[J].Y) then
          DiagTerKind := TerKinds[K];
        Inc(K);
      end;
    end;

    aFound := False;

    if not HasCornerTiles then Exit;

    //Find most popular TerKind
    //choose most popular one TerKind first
    if (TerKinds[0] = TerKinds[1])
      or (TerKinds[0] = TerKinds[2]) then
    begin
      Result := TerKinds[0];
      aFound := True;
    end else if (TerKinds[1] = TerKinds[2]) then
    begin
      Result := TerKinds[1];
      aFound := True;
    end else if DiagTerKind <> tkCustom then
    begin
      Result := DiagTerKind; //if all are different (1 occurences for each) then choose from diagonal cell
      aFound := True;
    end;
  end;

  function GetTerKindsAround(aCell: TKMPoint): TKMTerrainKindsArray;
  var
    I: Integer;
    TerKind: TKMTerrainKind;
    TerKindFound: array[0..3] of Boolean;
  begin
    SetLength(Result, 4);

    //get all 4 terkind for corners
    for I := 0 to 3 do
    begin
      TerKind := GetCornerTerKind(I, aCell, TerKindFound[I]);
      if TerKindFound[I] then
        Result[I] := TerKind;
    end;

    //For corner, where no terkind from around tiles were found - replace it with neighbour corner terkind (there can't be 2 missed terkinds in a row)
    for I := 0 to 3 do
      if not TerKindFound[I] then
        Result[I] := Result[(I+1) mod 4];

  end;

  function GetMaskType(aCornerTerKinds: TKMTerrainKindsArray; var aLayerOrder: array of TMaskInfo): TKMTileMaskType;
  var
    A,B,C,D,TK: TKMTerrainKind;
    I, J, Tmp: Integer;
    CornerI: array[0..3] of Integer;
  begin
    Result := mt_None;
    // A B
    // D C
    A := aCornerTerKinds[0];
    B := aCornerTerKinds[1];
    C := aCornerTerKinds[2];
    D := aCornerTerKinds[3];

    // A A
    // A A
    if (A = B) and (A = C) and (A = D) then
    begin
      Result := mt_None;
      aLayerOrder[0].TerKind := aCornerTerKinds[0];
      aLayerOrder[0].Corners := [0,1,2,3];
      aLayerOrder[0].Rotation := 0;
      Exit;
    end;

    // A A
    // D A
    if ((A = B) and (A = C)) then
    begin
      if TER_KIND_ORDER[B] < TER_KIND_ORDER[D] then
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[1];
        aLayerOrder[0].Corners := [0,1,2];
        aLayerOrder[1].TerKind := aCornerTerKinds[3];
        aLayerOrder[1].Rotation := 3;
        aLayerOrder[1].Corners := [3];
        Result := mt_2Corner;
      end else
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[3];
        aLayerOrder[0].Corners := [3];
        aLayerOrder[1].TerKind := aCornerTerKinds[1];
        aLayerOrder[1].Rotation := 1;
        aLayerOrder[1].Corners := [0,1,2];
        Result := mt_2Diagonal;
      end;
      Exit;
    end;

    // A A
    // A C
    if ((A = B) and (A = D)) then
    begin
      if TER_KIND_ORDER[A] < TER_KIND_ORDER[C] then
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[0];
        aLayerOrder[0].Corners := [0,1,3];
        aLayerOrder[1].TerKind := aCornerTerKinds[2];
        aLayerOrder[1].Rotation := 2;
        aLayerOrder[1].Corners := [2];
        Result := mt_2Corner;
      end else
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[2];
        aLayerOrder[0].Corners := [2];
        aLayerOrder[1].TerKind := aCornerTerKinds[0];
        aLayerOrder[1].Rotation := 0;
        aLayerOrder[1].Corners := [0,1,3];
        Result := mt_2Diagonal;
      end;
      Exit;
    end;

    // A B
    // B B
    if ((B = C) and (B = D)) then
    begin
      if TER_KIND_ORDER[A] < TER_KIND_ORDER[C] then
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[0];
        aLayerOrder[0].Corners := [0];
        aLayerOrder[1].TerKind := aCornerTerKinds[2];
        aLayerOrder[1].Rotation := 2;
        aLayerOrder[1].Corners := [1,2,3];
        Result := mt_2Diagonal;
      end else
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[2];
        aLayerOrder[0].Corners := [1,2,3];
        aLayerOrder[1].TerKind := aCornerTerKinds[0];
        aLayerOrder[1].Rotation := 0;
        aLayerOrder[1].Corners := [0];
        Result := mt_2Corner;
      end;
      Exit;
    end;

    // A B
    // A A
    if ((A = C) and (A = D)) then
    begin
      if TER_KIND_ORDER[D] < TER_KIND_ORDER[B] then
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[3];
        aLayerOrder[0].Corners := [0,2,3];
        aLayerOrder[1].TerKind := aCornerTerKinds[1];
        aLayerOrder[1].Rotation := 1;
        aLayerOrder[1].Corners := [1];
        Result := mt_2Corner;
      end else
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[1];
        aLayerOrder[0].Corners := [1];
        aLayerOrder[1].TerKind := aCornerTerKinds[3];
        aLayerOrder[1].Rotation := 3;
        aLayerOrder[1].Corners := [0,2,3];
        Result := mt_2Diagonal;
      end;
      Exit;
    end;

    // A A
    // C C
    if (A = B) and (C = D) then
    begin
      Result := mt_2Straight;
      if TER_KIND_ORDER[A] < TER_KIND_ORDER[C] then
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[0];
        aLayerOrder[0].Corners := [0,1];
        aLayerOrder[1].TerKind := aCornerTerKinds[2];
        aLayerOrder[1].Rotation := 2;
        aLayerOrder[1].Corners := [2,3];
      end else
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[2];
        aLayerOrder[0].Corners := [2,3];
        aLayerOrder[1].TerKind := aCornerTerKinds[0];
        aLayerOrder[1].Rotation := 0;
        aLayerOrder[1].Corners := [0,1];
      end;
      Exit;
    end;

    // A B
    // A B
    if (A = D) and (B = C) then
    begin
      Result := mt_2Straight;
      if TER_KIND_ORDER[A] < TER_KIND_ORDER[B] then
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[0];
        aLayerOrder[0].Corners := [0,3];
        aLayerOrder[1].TerKind := aCornerTerKinds[1];
        aLayerOrder[1].Rotation := 1;
        aLayerOrder[1].Corners := [1,2];
      end else
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[1];
        aLayerOrder[0].Corners := [1,2];
        aLayerOrder[1].TerKind := aCornerTerKinds[0];
        aLayerOrder[1].Rotation := 3;
        aLayerOrder[1].Corners := [0,3];
      end;
      Exit;
    end;


    // A B
    // B A
    if (A = C) and (B = D) then
    begin
      Result := mt_2Opposite;
      if TER_KIND_ORDER[A] < TER_KIND_ORDER[B] then
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[0];
        aLayerOrder[0].Corners := [0,2];
        aLayerOrder[1].TerKind := aCornerTerKinds[1];
        aLayerOrder[1].Rotation := 1;
        aLayerOrder[1].Corners := [1,3];
      end else
      begin
        aLayerOrder[0].TerKind := aCornerTerKinds[1];
        aLayerOrder[0].Corners := [1,3];
        aLayerOrder[1].TerKind := aCornerTerKinds[0];
        aLayerOrder[1].Rotation := 0;
        aLayerOrder[1].Corners := [0,2];
      end;
      Exit;
    end;

    for I := 0 to 3 do
     CornerI[I] := I;

    for I := 0 to 3 do
      for J := I to 3 do
        if TER_KIND_ORDER[aCornerTerKinds[CornerI[I]]] > TER_KIND_ORDER[aCornerTerKinds[CornerI[J]]] then
        begin
          Tmp := CornerI[I];
          CornerI[I] := CornerI[J];
          CornerI[J] := Tmp;
        end;

    // A A
    // C D
    J := 0;
    for I := 0 to 3 do // go up to '4' corner, need to cycle all around to find A = D situation
    begin
      if (I = 0)
        or ((I < 4) and (aCornerTerKinds[CornerI[I]] <> aCornerTerKinds[CornerI[I-1]])) then
      begin
        aLayerOrder[J].TerKind := aCornerTerKinds[CornerI[I]];
        aLayerOrder[J].Rotation := CornerI[I];
        aLayerOrder[J].Corners := [CornerI[I]];
        Inc(J);
      end else
      if (aCornerTerKinds[CornerI[I]] = aCornerTerKinds[CornerI[I-1]]) then
      begin
        // CornerI was not sorted with stable sort, so it could be possible we will find first not the minimum rotation
        if ((CornerI[I] = 0) and (CornerI[I-1] = 3))
          or ((CornerI[I] = 3) and (CornerI[I-1] = 0)) then // use 3rd rotation for A-D situation (choose 3 between 0 and 3)
          aLayerOrder[J-1].Rotation := 3
        else
          aLayerOrder[J-1].Rotation := Min(CornerI[I], CornerI[I-1]);
        aLayerOrder[J-1].SubType := 1;
        if Abs(CornerI[I] - CornerI[I-1]) = 2 then
          Result := mt_3Opposite
        else
          Result := mt_3Straight;
        Include(aLayerOrder[J-1].Corners, CornerI[I]);
      end;
    end;

    case J of
      3:      Exit;
      4:      begin
                Result := mt_4Square;
                Exit;
              end
      else    raise Exception.Create('Wrong number of corners with different TerKind: ' + IntToStr(J));
    end;


    aLayerOrder[0].TerKind := aCornerTerKinds[0];
    aLayerOrder[0].Rotation := 0;
    aLayerOrder[0].Corners := [0,1,2,3];

    Result := mt_None;
  end;

  function HasCollision(aTerKind1, aTerKind2: TKMTerrainKind): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    if aTerKind1 = aTerKind2 then Exit;

    Result := True;
    for I := Low(TERRAIN_EQUALITY_PAIRS) to High(TERRAIN_EQUALITY_PAIRS) do
    begin
      if (TERRAIN_EQUALITY_PAIRS[I].TK1 in [aTerKind1, aTerKind2]) 
        and (TERRAIN_EQUALITY_PAIRS[I].TK2 in [aTerKind1, aTerKind2]) then
      begin
        Result := False;
        Exit;
      end;
    end;
  end;

  procedure ApplyMagicBrush(aCell: TKMPoint);
  var
    I: Integer;
    TileTerKinds: TKMTerrainKindsArray;
    AroundTerKinds: TKMTerrainKindsArray;
    CollisionFound: Boolean;
    LayerOrder: array of TMaskInfo;
    MaskType: TKMTileMaskType;
  begin
    if not gTerrain.TileInMapCoords(aCell.X, aCell.Y) then Exit;

    if aUseTempLand then
      TileTerKinds := GetTileCornersTerrainKinds(TempLand[aCell.Y, aCell.X])
    else
      TileTerKinds := GetTileCornersTerrainKinds(GetTerrainTileBasic(gTerrain.Land[aCell.Y, aCell.X]));

    AroundTerKinds := GetTerKindsAround(aCell);

    CollisionFound := False;
    Inc(fTime[7].Data);
    for I := 0 to 3 do
      if HasCollision(TileTerKinds[I], AroundTerKinds[I]) then
      begin
        CollisionFound := True;
        Break;
      end;

    if CollisionFound then  //Need to apply MagicBrush
      with gTerrain.Land[aCell.Y,aCell.X] do
      begin
        Inc(fTime[8].Data);
        SetLength(LayerOrder, 4);

        MaskType := GetMaskType(AroundTerKinds, LayerOrder);

        BaseLayer.Terrain := BASE_TERRAIN[LayerOrder[0].TerKind];
        BaseLayer.Rotation := 0;
        BaseLayer.Corners := LayerOrder[0].Corners;
        LayersCnt := TILE_MASKS_LAYERS_CNT[MaskType] - 1;

        if MaskType = mt_None then Exit;

        for I := 1 to LayersCnt do
        begin
          Layer[I-1].Terrain := gGenTerrainTransitions[LayerOrder[I].TerKind, MaskType, LayerOrder[I].SubType];
          Layer[I-1].Rotation := LayerOrder[I].Rotation;
          Layer[I-1].Corners := LayerOrder[I].Corners;
        end;
      end;
  end;

var
  I,K,Size,Rad: Integer;
begin
  if not gTerrain.TileInMapCoords(aLocation.X, aLocation.Y) then Exit;

  Size := gGameCursor.MapEdSize;
  Rad := Size div 2;

  fTime[7].Desc := 'Cells total';
  fTime[8].Desc := 'Collisions total';

  if aOnlyCell or (Rad = 0) then
  begin
    ApplyMagicBrush(aLocation);
//    gLog.AddTime('MagicBrush applied');
    Exit;
  end;

//  gLog.AddTime('Prepare Temp MagicBrush');

  //There are two brush types here, even and odd size
  if Size mod 2 = 1 then
  begin
    //first comes odd sizes 1,3,5..
    for I:=-Rad to Rad do for K:=-Rad to Rad do
      if (gGameCursor.MapEdShape = hsSquare) or (Sqr(I) + Sqr(K) < Sqr(Rad + 0.5)) then               //Rounding corners in a nice way
        ApplyMagicBrush(KMPoint(aLocation.X+K, aLocation.Y+I));
  end
  else
  begin
    //even sizes 2,4,6..
    for I:=-Rad to Rad-1 do for K:=-Rad to Rad-1 do
      if (gGameCursor.MapEdShape = hsSquare) or (Sqr(I + 0.5) + Sqr(K + 0.5) < Sqr(Rad)) then           //Rounding corners in a nice way
        ApplyMagicBrush(KMPoint(aLocation.X+K, aLocation.Y+I));
  end;

end;


procedure TKMTerrainPainter.UpdateTempLand;
var
  I,J,L: Integer;
begin
  for I := 1 to gTerrain.MapY do
    for J := 1 to gTerrain.MapX do
    begin
      TempLand[I,J].BaseLayer := gTerrain.Land[I,J].BaseLayer;
      TempLand[I,J].LayersCnt := gTerrain.Land[I,J].LayersCnt;
      TempLand[I,J].Height := gTerrain.Land[I,J].Height;
      TempLand[I,J].Obj := gTerrain.Land[I,J].Obj;
      for L := 0 to 2 do
        TempLand[I,J].Layer[L] := gTerrain.Land[I,J].Layer[L];
    end;
end;


procedure TKMTerrainPainter.UseMagicBrush(X,Y,Rad: Integer; aSquare: Boolean);
var
  I,K: Integer;
begin
  for I := Low(fTime) to High(fTime) do
    fTime[I].Data := 0;

//  gLog.AddTime('Prepare Temp UseMagicBrush');
  UpdateTempLand;

  for I := -Rad to Rad do
    for K := -Rad to Rad do
      if aSquare or (Sqr(I) + Sqr(K) < Sqr(Rad)) then
        MagicBrush(KMPoint(X+K,Y+I));

  for I := Low(fTime) to High(fTime) do
    gLog.AddTime(Format('%s: %d ms', [fTime[I].Desc, fTime[I].Data]));
end;


procedure TKMTerrainPainter.EditBrush(const aLoc: TKMPoint);
var
  I,K,Size,Rad: Integer;
begin
  //Cell below cursor
  MapXc := EnsureRange(round(gGameCursor.Float.X+0.5),1,gTerrain.MapX);
  MapYc := EnsureRange(round(gGameCursor.Float.Y+0.5),1,gTerrain.MapY);

  //Node below cursor
  MapXn := EnsureRange(round(gGameCursor.Float.X+1),1,gTerrain.MapX);
  MapYn := EnsureRange(round(gGameCursor.Float.Y+1),1,gTerrain.MapY);

  Size := gGameCursor.MapEdSize;
  Rad := Size div 2;

  if Size = 0 then
  begin
    if (MapXn2 <> MapXn) or (MapYn2 <> MapYn) then
      LandTerKind[MapYn, MapXn].TerKind := TKMTerrainKind(gGameCursor.Tag1);
  end
  else
    if (MapXc2 <> MapXc) or (MapYc2 <> MapYc) then
    begin
      //There are two brush types here, even and odd size
      if Size mod 2 = 1 then
      begin
        //first comes odd sizes 1,3,5..
        for I:=-Rad to Rad do for K:=-Rad to Rad do
          if (gGameCursor.MapEdShape = hsSquare) or (Sqr(I) + Sqr(K) < Sqr(Rad + 0.5)) then               //Rounding corners in a nice way
            BrushTerrainTile(MapXc+K, MapYc+I, TKMTerrainKind(gGameCursor.Tag1));
      end
      else
      begin
        //even sizes 2,4,6..
        for I:=-Rad to Rad-1 do for K:=-Rad to Rad-1 do
          if (gGameCursor.MapEdShape = hsSquare) or (Sqr(I + 0.5) + Sqr(K + 0.5) < Sqr(Rad)) then           //Rounding corners in a nice way
            BrushTerrainTile(MapXc+K, MapYc+I, TKMTerrainKind(gGameCursor.Tag1));
      end;
    end;
  RebuildMap(MapXc, MapYc, Rad+2, (gGameCursor.MapEdShape = hsSquare)); //+3 for surrounding tiles

  if gGameCursor.MapEdMagicBrush2 then
    UseMagicBrush(MapXc, MapYc, Rad, (gGameCursor.MapEdShape = hsSquare));

  MapXn2 := MapXn;
  MapYn2 := MapYn;
  MapXc2 := MapXc;
  MapYc2 := MapYc;

  gTerrain.UpdatePassability(KMRectGrow(KMRect(aLoc), Rad+1));
end;


procedure TKMTerrainPainter.EditHeight;
var
  I, K: Integer;
  Rad, Slope, Speed: Byte;
  Tmp: Single;
  R: TKMRect;
  aLoc : TKMPointF;
  aRaise: Boolean;
begin
  aLoc    := KMPointF(gGameCursor.Float.X+1, gGameCursor.Float.Y+1); // Mouse point
  aRaise  := ssLeft in gGameCursor.SState;         // Raise or Lowered (Left or Right mousebtn)
  Rad     := gGameCursor.MapEdSize;                // Radius basing on brush size
  Slope   := gGameCursor.MapEdSlope;               // Elevation slope
  Speed   := gGameCursor.MapEdSpeed;               // Elvation speed
  for I := Max((round(aLoc.Y) - Rad), 1) to Min((round(aLoc.Y) + Rad), gTerrain.MapY) do
  for K := Max((round(aLoc.X) - Rad), 1) to Min((round(aLoc.X) + Rad), gTerrain.MapX) do
  begin

    // We have square area basing on mouse point +/- radius
    // Now we need to check whether point is inside brush type area(circle etc.)
    // Every MapEdShape case has it's own check routine
    case gGameCursor.MapEdShape of
      hsCircle: Tmp := Max((1 - GetLength(I - round(aLoc.Y), round(K - aLoc.X)) / Rad), 0);   // Negative number means that point is outside circle
      hsSquare: Tmp := 1 - Max(Abs(I - round(aLoc.Y)), Abs(K - round(aLoc.X))) / Rad;
      else      Tmp := 0;
    end;

    // Default cursor mode is elevate/decrease
    if gGameCursor.Mode = cmEqualize then
    begin // START Unequalize
      if aRaise then
      begin
        if (i > 1) and (k >1) and (i < gTerrain.MapY - 1) and (k < gTerrain.MapX - 1) then
        begin
        // Unequalize compares heights of adjacent tiles and increases differences
          if (gTerrain.Land[I,K].Height < gTerrain.Land[I-1,K+1].Height) then
            Tmp := -Min(gTerrain.Land[I-1,K+1].Height - gTerrain.Land[I,K].Height, Tmp)
          else
          if (gTerrain.Land[I,K].Height > gTerrain.Land[I-1,K+1].Height) then
            Tmp := Min(gTerrain.Land[I,K].Height - gTerrain.Land[I-1,K+1].Height, Tmp)
          else
            Tmp := 0;
        end
        else
          Tmp := 0;
       //END Unequalize
      end else
      // START Flatten
      begin
      //Flatten compares heights of mouse click and active tile then it increases/decreases height of active tile
        if (gTerrain.Land[I,K].Height < gTerrain.Land[Max(trunc(aLoc.Y), 1), Max(trunc(aLoc.X), 1)].Height) then
          Tmp := - Min(gTerrain.Land[Max(trunc(aLoc.Y), 1), Max(trunc(aLoc.X), 1)].Height - gTerrain.Land[I,K].Height, Tmp)
        else
          if (gTerrain.Land[I,K].Height > gTerrain.Land[Max(trunc(aLoc.Y), 1), Max(trunc(aLoc.X), 1)].Height) then
            Tmp := Min(gTerrain.Land[I,K].Height - gTerrain.Land[Max(trunc(aLoc.Y), 1), Max(trunc(aLoc.X), 1)].Height, Tmp)
          else
            Tmp := 0;
      end;
      //END Flatten
    end;
    //COMMON PART FOR Elevate/Lower and Unequalize/Flatten
    //Compute resulting floating-point height
    Tmp := power(abs(Tmp),(Slope+1)/6)*sign(Tmp); //Modify slopes curve
    Tmp := Tmp * (4.75/14*(Speed - 1) + 0.25);
    Tmp := EnsureRange(gTerrain.Land[I,K].Height + LandTerKind[I,K].HeightAdd/255 + Tmp * (Byte(aRaise)*2 - 1), 0, 100); // (Byte(aRaise)*2 - 1) - LeftButton pressed it equals 1, otherwise equals -1
    gTerrain.Land[I,K].Height := trunc(Tmp);
    LandTerKind[I,K].HeightAdd := round(frac(Tmp)*255); //write fractional part in 0..255 range (1Byte) to save us mem
  end;

  R := KMRectGrow(KMRect(aLoc), Rad);
  gTerrain.UpdateLighting(R);
  gTerrain.UpdatePassability(R);
end;


procedure TKMTerrainPainter.EditTile(const aLoc: TKMPoint; aTile: Word; aRotation: Byte);
begin
  if gTerrain.TileInMapCoords(aLoc.X, aLoc.Y) then
  begin
    LandTerKind[aLoc.Y, aLoc.X].TerKind := tkCustom;

    gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Terrain := aTile;
    gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Corners := [0,1,2,3];
    gTerrain.Land[aLoc.Y, aLoc.X].LayersCnt := 0;
    gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Rotation := aRotation;

    gTerrain.UpdatePassability(aLoc);
  end;
end;


procedure TKMTerrainPainter.MagicWater(const aLoc: TKMPoint);
type
  TMagicType = (mtNone, mtWater, mtShore, mtIce);
var
  FilledTiles: array of array of TMagicType;

  function CanRotate(aTileID: Word): Boolean;
  begin
    Result := (gRes.Tileset.TileIsWater(aTileID)
              and not (aTileID in [114, 115, 119, 194, 200, 210, 211, 235, 236]))
              or (gRes.Tileset.TileIsIce(aTileID)
              and not (aTileID in [4, 10, 12, 22, 23]));
  end;

  procedure MagicFillArea(X, Y: Word);
  begin
    if FilledTiles[Y, X] <> mtNone then
      Exit;

    //Detect rotateable shores
    if (gTerrain.Land[y,x].BaseLayer.Terrain in [126, 127]) then
      FilledTiles[y,x] := mtShore;

    //Detect full ice tiles
    if (gTerrain.Land[y, x].BaseLayer.Terrain = 44) then
      FilledTiles[y, x] := mtIce;

    //Detect water
    if CanRotate(gTerrain.Land[y,x].BaseLayer.Terrain) then
    begin
      FilledTiles[y,x] := mtWater;

      if x-1>=1 then
      begin
        if y-1>=1 then             MagicFillArea(x-1,y-1);
                                   MagicFillArea(x-1,y  );
        if y+1<=gTerrain.MapY then MagicFillArea(x-1,y+1);
      end;

      if y-1>=1 then               MagicFillArea(x,y-1);
      if y+1<=gTerrain.MapY then   MagicFillArea(x,y+1);

      if x+1<=gTerrain.MapX then
      begin
        if y-1>=1 then             MagicFillArea(x+1,y-1);
                                   MagicFillArea(x+1,y  );
        if y+1<=gTerrain.MapY then MagicFillArea(x+1,y+1);
      end;
    end;
  end;

var
  I,K:Integer;
  NewRot: Byte;
begin
  if not CanRotate(gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Terrain) then
    Exit;

  SetLength(FilledTiles, gTerrain.MapY+1, gTerrain.MapX+1);

  MagicFillArea(aLoc.X,aLoc.Y);

  NewRot := (gTerrain.Land[aLoc.Y,aLoc.X].BaseLayer.Rotation + 1) mod 4;
  for I := 1 to gTerrain.MapY do
    for K := 1 to gTerrain.MapX do
      case FilledTiles[I,K] of
        mtWater,
        mtIce:    begin
                    gTerrain.Land[I,K].BaseLayer.Rotation := NewRot;
                  end;
        mtShore:  begin
                    //These shores can be flipped
                    if (gTerrain.Land[I,K].BaseLayer.Terrain in [126, 127]) then
                      case gTerrain.Land[I,K].BaseLayer.Rotation of
                        0: if NewRot = 3 then gTerrain.Land[I,K].BaseLayer.Terrain := 126 else
                           if NewRot = 1 then gTerrain.Land[I,K].BaseLayer.Terrain := 127;

                        1: if NewRot = 0 then gTerrain.Land[I,K].BaseLayer.Terrain := 126 else
                           if NewRot = 2 then gTerrain.Land[I,K].BaseLayer.Terrain := 127;

                        2: if NewRot = 1 then gTerrain.Land[I,K].BaseLayer.Terrain := 126 else
                           if NewRot = 3 then gTerrain.Land[I,K].BaseLayer.Terrain := 127;

                        3: if NewRot = 2 then gTerrain.Land[I,K].BaseLayer.Terrain := 126 else
                           if NewRot = 0 then gTerrain.Land[I,K].BaseLayer.Terrain := 127;
                      end;
                  end;
      end;
  MakeCheckpoint;
end;


procedure TKMTerrainPainter.GenerateAddnData;
const
  SPECIAL_TILES = [24,25,194,198,199,202,206,207,214,216..219,221..233,246]; //Waterfalls and bridges
  OTHER_WATER_TILES = [193,208,209,240,244]; //Water tiles not used in painting (fast, straight, etc.)
  //Accuracies
  ACC_MAX = 5;  //Special tiles
  ACC_HIGH = 4; //Primary tiles
  ACC_MED = 3; //Random tiling
  ACC_LOW = 2; //Edges
  ACC_MIN = 1; //Coal random tiling (edges are better in this case)
  ACC_NONE = 0;
var
  Accuracy: array of array of Byte;

  procedure SetTerrainKindVertex(X,Y: Integer; T: TKMTerrainKind; aAccuracy: Byte);
  begin
    if not gTerrain.TileInMapCoords(X,Y) then Exit;

    //Special rules to fix stone hill corners:
    // - Never overwrite tkStoneMount with tkGrass
    // - Always allow tkStoneMount to overwrite tkGrass
    if (LandTerKind[Y,X].TerKind = tkStone) and (T = tkGrass) then Exit;
    if (LandTerKind[Y,X].TerKind = tkGrass) and (T = tkStone) then aAccuracy := ACC_MAX;

    //Skip if already set more accurately
    if aAccuracy < Accuracy[Y,X] then Exit;

    LandTerKind[Y,X].TerKind := T;
    Accuracy[Y,X] := aAccuracy;
  end;

  procedure SetTerrainKindTile(X,Y: Integer; T: TKMTerrainKind; aAccuracy: Byte);
  begin
    SetTerrainKindVertex(X  , Y  , T, aAccuracy);
    SetTerrainKindVertex(X+1, Y  , T, aAccuracy);
    SetTerrainKindVertex(X  , Y+1, T, aAccuracy);
    SetTerrainKindVertex(X+1, Y+1, T, aAccuracy);
  end;

var
  I,K,J,Rot: Integer;
  A: Byte;
  T, T2: TKMTerrainKind;
begin
  SetLength(Accuracy, gTerrain.MapY+1, gTerrain.MapX+1);

  for I := 1 to gTerrain.MapY do
  for K := 1 to gTerrain.MapX do
  begin
    LandTerKind[I,K].TerKind := tkCustom; //Everything custom by default
    Accuracy[I,K] := ACC_NONE;
  end;

  for I := 1 to gTerrain.MapY do
  for K := 1 to gTerrain.MapX do
    //Special tiles such as bridges should remain as tkCustom
    if gTerrain.Land[I,K].BaseLayer.Terrain in SPECIAL_TILES then
      SetTerrainKindTile(K, I, tkCustom, ACC_MAX) //Maximum accuracy
    else
      //Water tiles not used in painting (fast, straight, etc.)
      if gTerrain.Land[I,K].BaseLayer.Terrain in OTHER_WATER_TILES then
        SetTerrainKindTile(K, I, tkWater, ACC_MED) //Same accuracy as random tiling (see below)
      else
        for T := Low(TKMTerrainKind) to High(TKMTerrainKind) do
          if T <> tkCustom then
          begin
            //METHOD 1: Terrain type is the primary tile for this terrain
            if gTerrain.Land[I,K].BaseLayer.Terrain = Abs(Combo[T,T,1]) then
            begin
              SetTerrainKindTile(K, I, T, ACC_HIGH);
              Break; //Neither of the methods below can beat this one, so save time and don't check more TerrainKinds
            end;

            //METHOD 2: Terrain type is in RandomTiling
            for J := 1 to RandomTiling[T,0] do
              if gTerrain.Land[I,K].BaseLayer.Terrain = RandomTiling[T,J] then
              begin
                A := ACC_MED; //Random tiling is fairly accurate
                if T = tkCoal then A := ACC_MIN; //Random coal tiles are also used for edges, so edges are more accurate
                SetTerrainKindTile(K, I, T, A);
              end;

            //METHOD 3: Edging data
            A := ACC_LOW; //Edging data is not as accurate as other methods (some edges reuse the same tiles)
            for T2 := Low(TKMTerrainKind) to High(TKMTerrainKind) do
            begin
              //1 vertex is T, 3 vertexes are T2
              if gTerrain.Land[I,K].BaseLayer.Terrain = Abs(Combo[T,T2,1]) then
              begin
                Rot := gTerrain.Land[I,K].BaseLayer.Rotation mod 4;
                if Combo[T,T2,1] < 0 then Rot := (Rot+2) mod 4; //Flip
                case Rot of
                  0: begin
                       SetTerrainKindVertex(K,   I,   T2, A);
                       SetTerrainKindVertex(K+1, I,   T, A);
                       SetTerrainKindVertex(K,   I+1, T2, A);
                       SetTerrainKindVertex(K+1, I+1, T2, A);
                     end;
                  1: begin
                       SetTerrainKindVertex(K,   I,   T2, A);
                       SetTerrainKindVertex(K+1, I,   T2, A);
                       SetTerrainKindVertex(K,   I+1, T2, A);
                       SetTerrainKindVertex(K+1, I+1, T, A);
                     end;
                  2: begin
                       SetTerrainKindVertex(K,   I,   T2, A);
                       SetTerrainKindVertex(K+1, I,   T2, A);
                       SetTerrainKindVertex(K,   I+1, T, A);
                       SetTerrainKindVertex(K+1, I+1, T2, A);
                     end;
                  3: begin
                       SetTerrainKindVertex(K,   I,   T, A);
                       SetTerrainKindVertex(K+1, I,   T2, A);
                       SetTerrainKindVertex(K,   I+1, T2, A);
                       SetTerrainKindVertex(K+1, I+1, T2, A);
                     end;
                end;
              end;
              //Half T, half T2
              if gTerrain.Land[I,K].BaseLayer.Terrain = Abs(Combo[T,T2,2]) then
              begin
                Rot := gTerrain.Land[I,K].BaseLayer.Rotation mod 4;
                if Combo[T,T2,2] < 0 then Rot := (Rot+2) mod 4; //Flip
                case Rot of
                  0: begin
                       SetTerrainKindVertex(K,   I,   T, A);
                       SetTerrainKindVertex(K+1, I,   T, A);
                       SetTerrainKindVertex(K,   I+1, T2, A);
                       SetTerrainKindVertex(K+1, I+1, T2, A);
                     end;
                  1: begin
                       SetTerrainKindVertex(K,   I,   T2, A);
                       SetTerrainKindVertex(K+1, I,   T, A);
                       SetTerrainKindVertex(K,   I+1, T2, A);
                       SetTerrainKindVertex(K+1, I+1, T, A);
                     end;
                  2: begin
                       SetTerrainKindVertex(K,   I,   T2, A);
                       SetTerrainKindVertex(K+1, I,   T2, A);
                       SetTerrainKindVertex(K,   I+1, T, A);
                       SetTerrainKindVertex(K+1, I+1, T, A);
                     end;
                  3: begin
                       SetTerrainKindVertex(K,   I,   T, A);
                       SetTerrainKindVertex(K+1, I,   T2, A);
                       SetTerrainKindVertex(K,   I+1, T, A);
                       SetTerrainKindVertex(K+1, I+1, T2, A);
                     end;
                end;
              end;
              //3 vertex are T, 1 vertexes is T2
              if gTerrain.Land[I,K].BaseLayer.Terrain = Abs(Combo[T,T2,3]) then
              begin
                Rot := gTerrain.Land[I,K].BaseLayer.Rotation mod 4;
                if Combo[T,T2,3] < 0 then Rot := (Rot+2) mod 4; //Flip
                case Rot of
                  0: begin
                       SetTerrainKindVertex(K,   I,   T, A);
                       SetTerrainKindVertex(K+1, I,   T, A);
                       SetTerrainKindVertex(K,   I+1, T2, A);
                       SetTerrainKindVertex(K+1, I+1, T, A);
                     end;
                  1: begin
                       SetTerrainKindVertex(K,   I,   T2, A);
                       SetTerrainKindVertex(K+1, I,   T, A);
                       SetTerrainKindVertex(K,   I+1, T, A);
                       SetTerrainKindVertex(K+1, I+1, T, A);
                     end;
                  2: begin
                       SetTerrainKindVertex(K,   I,   T, A);
                       SetTerrainKindVertex(K+1, I,   T2, A);
                       SetTerrainKindVertex(K,   I+1, T, A);
                       SetTerrainKindVertex(K+1, I+1, T, A);
                     end;
                  3: begin
                       SetTerrainKindVertex(K,   I,   T, A);
                       SetTerrainKindVertex(K+1, I,   T, A);
                       SetTerrainKindVertex(K,   I+1, T, A);
                       SetTerrainKindVertex(K+1, I+1, T2, A);
                     end;
                end;
              end;
            end;
          end;
end;


procedure TKMTerrainPainter.InitSize(X, Y: Word);
var
  I: Integer;
begin
  for I := 0 to High(fUndos) do
    SetLength(fUndos[I].Data, Y+1, X+1);

  SetLength(LandTerKind, Y+1, X+1);
  SetLength(TempLand, Y+1, X+1);
end;


procedure TKMTerrainPainter.InitEmpty;
var
  I, K: Integer;
begin
  InitSize(gTerrain.MapX, gTerrain.MapY);

  //Fill in default terain type - Grass
  for I := 1 to gTerrain.MapY do
    for K := 1 to gTerrain.MapX do
      LandTerKind[I,K].TerKind := tkGrass;
end;


//Skip the KaM data and load MapEd vertice info
procedure TKMTerrainPainter.LoadFromFile(const aFileName: UnicodeString);
var
  I, K: Integer;
  TerType: ShortInt; //Krom's editor saves terrain kind as ShortInt
  S: TKMemoryStream;
  NewX, NewY: Integer;
  ResHead: packed record
    x1: Word;
    Allocated, Qty1, Qty2, x5, Len17: Integer;
  end;
  Chunk: AnsiString;
  MapEdChunkFound: Boolean;
  UseKaMFormat: Boolean;
  MapDataSize: Cardinal;
begin
  if not FileExists(aFileName) then Exit;

  InitSize(gTerrain.MapX, gTerrain.MapY);

  S := TKMemoryStream.Create;
  try
    S.LoadFromFile(aFileName);

    LoadMapHeader(S, NewX, NewY, UseKaMFormat, MapDataSize);

    //Skip terrain data
    if UseKaMFormat then
      S.Seek(23 * NewX * NewY, soFromCurrent)
    else
      S.Seek(MapDataSize, soFromCurrent);

    //For now we just throw away the resource footer because we don't understand it (and save a blank one)
    if UseKaMFormat then
    begin
      S.Read(ResHead, 22);
      S.Seek(17 * ResHead.Allocated, soFromCurrent);
    end;

    //ADDN
    MapEdChunkFound := False;
    if S.Position < S.Size then
    begin
      Chunk := '    ';
      S.Read(Chunk[1], 4);
      if Chunk = 'ADDN' then
      begin
        S.Read(Chunk[1], 4);
        if Chunk = 'TILE' then
        begin
          S.Read(I, 4); //Chunk size
          S.Read(I, 4); //Cypher - ommited
          for I := 1 to NewY do
          for K := 1 to NewX do
          begin
            //Krom's editor saves negative numbers for tiles placed manually
            S.Read(TerType, 1);
            if InRange(TerType, ShortInt(Low(TKMTerrainKind)), ShortInt(High(TKMTerrainKind))) then
              LandTerKind[I,K].TerKind := TKMTerrainKind(TerType)
            else
              LandTerKind[I,K].TerKind := tkCustom;
          end;
          MapEdChunkFound := True; //Only set it once it's all loaded successfully
        end
        else
          gLog.AddNoTime(aFileName + ' has no MapEd.TILE chunk');
      end
      else
        gLog.AddNoTime(aFileName + ' has no MapEd.ADDN chunk');
    end
    else
      gLog.AddNoTime(aFileName + ' has no MapEd chunk');
  finally
    S.Free;
  end;

  //We can regenerate the MapEd data if it's missing (won't be as good as the original)
  if not MapEdChunkFound then
  begin
    gLog.AddNoTime('Regenerating missing MapEd data as best as we can');
    GenerateAddnData;
  end;

  MakeCheckpoint;
end;


procedure TKMTerrainPainter.SaveToFile(const aFileName: UnicodeString);
begin
  SaveToFile(aFileName, KMRECT_ZERO);
end;


procedure TKMTerrainPainter.SaveToFile(const aFileName: UnicodeString; const aInsetRect: TKMRect);
var
  I, K, IFrom, KFrom: Integer;
  S: TKMemoryStream;
  NewX, NewY: Integer;
  ResHead: packed record
    x1: Word;
    Allocated, Qty1, Qty2, x5, Len17: Integer;
  end;
  UseKaMFormat: Boolean;
  MapDataSize: Cardinal;
begin
  if not FileExists(aFileName) then Exit;

  S := TKMemoryStream.Create;
  try
    S.LoadFromFile(aFileName);

    LoadMapHeader(S, NewX, NewY, UseKaMFormat, MapDataSize);

    //Skip terrain data
    if UseKaMFormat then
      S.Seek(23 * NewX * NewY, soFromCurrent)
    else
      S.Seek(MapDataSize, soFromCurrent);

    //For now we just throw away the resource footer because we don't understand it (and save a blank one)
    if UseKaMFormat then
    begin
      S.Read(ResHead, 22);
      S.Seek(17 * ResHead.Allocated, soFromCurrent);
    end;

    S.Write(AnsiString('ADDN')[1], 4);
    S.Write(AnsiString('TILE')[1], 4);

    S.Write(Integer(NewX * NewY)); //Chunk size
    S.Write(Integer(0)); //Cypher - ommited
    for I := 1 to NewY do
    begin
      if I <= aInsetRect.Top then
        IFrom := 1
      else if I >= aInsetRect.Top + gTerrain.MapY then
        IFrom := gTerrain.MapY
      else
        IFrom := I - aInsetRect.Top;

      for K := 1 to NewX do
      begin
        if K <= aInsetRect.Left then
          KFrom := 1
        else if K >= aInsetRect.Left + gTerrain.MapX then
          KFrom := gTerrain.MapX
        else
          KFrom := K - aInsetRect.Left;
        S.Write(LandTerKind[IFrom,KFrom].TerKind, 1);
      end;
    end;

    S.SaveToFile(aFileName);
  finally
    S.Free;
  end;
end;


procedure TKMTerrainPainter.MakeCheckpoint;
var
  I, J, L: Integer;
begin
  //Get next pos in circular buffer
  fUndoPos := (fUndoPos + 1) mod MAX_UNDO;

  //Store new checkpoint
  for I := 1 to gTerrain.MapY do
    for J := 1 to gTerrain.MapX do
      with fUndos[fUndoPos] do
      begin
        Data[I,J].BaseLayer := gTerrain.Land[I,J].BaseLayer;
        Data[I,J].LayersCnt := gTerrain.Land[I,J].LayersCnt;
        Data[I,J].Height := gTerrain.Land[I,J].Height;
        Data[I,J].Obj := gTerrain.Land[I,J].Obj;
        Data[I,J].TerKind := LandTerKind[I,J].TerKind;
        for L := 0 to 2 do
          Data[I,J].Layer[L] := gTerrain.Land[I,J].Layer[L];
      end;
  fUndos[fUndoPos].HasData := True;

  //Mark next checkpoint pos as invalid, so we can't Redo to it
  fUndos[(fUndoPos + 1) mod MAX_UNDO].HasData := False;
end;


function TKMTerrainPainter.CanUndo: Boolean;
begin
  Result := fUndos[(fUndoPos - 1 + MAX_UNDO) mod MAX_UNDO].HasData;
end;


function TKMTerrainPainter.CanRedo: Boolean;
begin
  Result := fUndos[(fUndoPos + 1) mod MAX_UNDO].HasData;
end;


procedure TKMTerrainPainter.Undo;
var
  Prev: Byte;
begin
  Prev := (fUndoPos - 1 + MAX_UNDO) mod MAX_UNDO;

  if not fUndos[Prev].HasData then Exit;

  fUndoPos := Prev;
  CheckpointToTerrain;
end;


procedure TKMTerrainPainter.Redo;
var
  Next: Byte;
begin
  //Next pos in circular buffer
  Next := (fUndoPos + 1) mod MAX_UNDO;

  if not fUndos[Next].HasData then Exit;

  fUndoPos := Next;

  CheckpointToTerrain;
end;


procedure TKMTerrainPainter.CheckpointToTerrain;
var
  I, J, L: Integer;
begin
  for I := 1 to gTerrain.MapY do
    for J := 1 to gTerrain.MapX do
      with fUndos[fUndoPos] do
      begin
        gTerrain.Land[I,J].BaseLayer.Terrain := Data[I,J].BaseLayer.Terrain;
        gTerrain.Land[I,J].BaseLayer.Rotation := Data[I,J].BaseLayer.Rotation;
        gTerrain.Land[I,J].BaseLayer.Corners := Data[I,J].BaseLayer.Corners;
        gTerrain.Land[I,J].LayersCnt := Data[I,J].LayersCnt;
        gTerrain.Land[I,J].Height := Data[I,J].Height;
        gTerrain.Land[I,J].Obj := Data[I,J].Obj;
        LandTerKind[I,J].TerKind := Data[I,J].TerKind;
        for L := 0 to 2 do
        begin
          gTerrain.Land[I,J].Layer[L].Terrain := Data[I,J].Layer[L].Terrain;
          gTerrain.Land[I,J].Layer[L].Rotation := Data[I,J].Layer[L].Rotation;
          gTerrain.Land[I,J].Layer[L].Corners := Data[I,J].Layer[L].Corners;
        end;
      end;

  //Update derived fields (lighting)
  gTerrain.UpdateLighting(gTerrain.MapRect);
  gTerrain.UpdatePassability(gTerrain.MapRect);
end;


procedure TKMTerrainPainter.Eyedropper(const aLoc: TKMPoint);
begin
  //Save specified loc's terrain info
  gGameCursor.Tag1 := gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Terrain;
  gGameCursor.MapEdDir := gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Rotation;
end;


procedure TKMTerrainPainter.RotateTile(const aLoc: TKMPoint);
begin
  EditTile(gGameCursor.Cell,
           gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Terrain,
           (gTerrain.Land[aLoc.Y, aLoc.X].BaseLayer.Rotation + 1) mod 4);
end;


procedure TKMTerrainPainter.UpdateStateIdle;
begin
  case gGameCursor.Mode of
    cmElevate,
    cmEqualize:   if (ssLeft in gGameCursor.SState) or (ssRight in gGameCursor.SState) then
                    EditHeight;
    cmBrush:      if (ssLeft in gGameCursor.SState) then
                  begin
                    if gGameCursor.MapEdMagicBrush then
                    begin
//                      UpdateTempLand;
                      MagicBrush(gGameCursor.Cell, False, False);
                    end else
                      EditBrush(gGameCursor.Cell);
                  end;
    cmTiles:      if (ssLeft in gGameCursor.SState) then
                    if gGameCursor.MapEdDir in [0..3] then //Defined direction
                      EditTile(gGameCursor.Cell, gGameCursor.Tag1, gGameCursor.MapEdDir)
                    else //Random direction
                      EditTile(gGameCursor.Cell, gGameCursor.Tag1, KaMRandom(4));
    cmObjects:    if (ssLeft in gGameCursor.SState) then
                    gTerrain.SetObject(gGameCursor.Cell, gGameCursor.Tag1);
  end;
end;


procedure TKMTerrainPainter.UpdateState;
begin
//  case gGameCursor.Mode of
//    cmBrush:      if (ssLeft in gGameCursor.SState) then
//                  begin
//                    if gGameCursor.MapEdMagicBrush then
//                    begin
//                      UpdateTempLand;
//                      MagicBrush(gGameCursor.Cell, False);
//                    end else
//                      EditBrush(gGameCursor.Cell);
//                  end;
//  end;
end;


end.
