package states.editors;

import flixel.FlxSubState;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;
import flixel.util.FlxDestroyUtil;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxGridOverlay;
import lime.utils.Assets;
import lime.media.AudioBuffer;
import openfl.media.Sound;
import openfl.geom.Rectangle;
import haxe.Json;
import haxe.Exception;
import haxe.io.Bytes;
import backend.StageData;
import backend.Highscore;
import backend.Difficulty;
import objects.Character;
import objects.HealthIcon;
import objects.note.Note;
import objects.note.StrumArrow;
import objects.note.Strumline;
import states.editors.content.MetaNote;
import states.editors.content.VSlice;
import states.editors.content.Prompt;
import states.editors.content.*;
import utils.SoundUtil;

using DateTools;

typedef UndoStruct =
{
  var action:UndoAction;
  var data:Dynamic;
}

enum abstract UndoAction(String)
{
  var ADD_NOTE = 'Add Note';
  var DELETE_NOTE = 'Delete Note';
  var MOVE_NOTE = 'Move Note';
  var SELECT_NOTE = 'Select Note';
}

enum abstract ChartingTheme(String)
{
  var LIGHT = 'light';
  var DEFAULT = 'default';
  var DARK = 'dark';
}

enum abstract WaveformTarget(String)
{
  var INST = 'inst';
  var PLAYER = 'voc';
  var OPPONENT = 'opp';
}

class ChartingState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
  public static final defaultEvents:Array<Array<String>> = [
    ['', "Nothing. Yep, that's right."], // Always leave this one empty pls
    [
      'Dadbattle Spotlight',
      "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"
    ],
    [
      'Hey!',
      "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF / 0 = Only Boyfriend, GF / 1 = Only Girlfriend,\nDAD / 2 = Only Opponent\nMOM / 3 = Only SecondOpponent\n4 = All\nValue 2: Custom animation duration,\nleave it blank for 0.6s"
    ],
    [
      'Set GF Speed',
      "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"
    ],
    [
      'Philly Glow',
      "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."
    ],
    ['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
    [
      'Add Camera Zoom',
      "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."
    ],
    ['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
    ['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
    [
      'Play Animation',
      "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"
    ],
    [
      'Camera Follow Pos',
      "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank.\nValue 3: Camera zoom."
    ],
    [
      'Alt Idle Animation',
      "Sets a specified postfix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New postfix (Leave it blank to disable)"
    ],
    [
      'Screen Shake',
      "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."
    ],
    [
      'Change Character',
      "Value 1: Character to change (BF / 0, GF / 2, Dad / 1, Mom / 3, Other Name / Other Num = (Custom Character))\nValue 2: New character's name"
    ],
    [
      'Change Scroll Speed',
      "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds.\nValue 3: Ease"
    ],
    ['Set Property', "Value 1: Variable name\nValue 2: New value"],
    [
      'Play Sound',
      "Value 1: Sound file name\nValue 2: Volume (Default: 1), ranges from 0 to 1"
    ],
    [
      'Reset Extra Arguments',
      "Value 1: (Dad / 0, BF / 1, GF / 2, Mom / 4, Other Name), Resets Some Default Arguments If Changed."
    ],
    ['Change Stage', "Value 1: Stage Name, Changes Stage to specified stage."],
    [
      'Add Cinematic Bars',
      "Value 1: Speed of the bars apperance\nValue 2: Thickness of bars"
    ],
    ['Remove Cinematic Bars', "Value 1: Time taken for bars to disappear"],
    [
      'Change Camera Props',
      "Value 1: X, Y, Zoom (Split by ',' so, 100, 100, 1)\nValue 2: If it tweens the values (true or false)\nValue 3: Eases for values, X, Y, Zoom Tweens Ex. (Linear, Sine, ExpoIn) \nValue 4: Time for eases to happen (0.2, 0.3, 1.2)"
    ],
    [
      "Default Camera Flash",
      "Value 1: Color Ex. FFFFFF\nValue 2: Time for flash to last\nValue 3: Camera Ex. camGame\nValue 4: Alpha of flash (how visible the flashSprite is)"
    ],
    [
      "Default Set Cam Zoom",
      "Value 1: Zoom For Camera\nValue 2: Time it may take (optional, leave blank for instant affect)"
    ]
  ];

  public static var keysArray:Array<String> = [ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT]; // Used for Vortex Editor
  public static var SHOW_EVENT_COLUMN = true;
  public static var GRID_COLUMNS_PER_PLAYER = 4;
  public static var GRID_PLAYERS = 2;
  public static var GRID_SIZE = 40;

  final BACKUP_EXT = '.bkp';

  public var quantizations:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];

  public var quantColors:Array<FlxColor> = [
    0xFFDF0000, 0xFF4040CF, 0xFFAF00AF, 0xFFFFAF00, 0xFFFFFFFF, 0xFFFFA0FF, 0xFFFF6030, 0xFF00CFCF, 0xFF00CF00, 0xFF9F9F9F, 0xFF3F3F3F,
  ];

  var curQuant(default, set):Int = 16;

  function set_curQuant(v:Int)
  {
    curQuant = v;
    updateVortexColor();
    return curQuant;
  }

  function updateVortexColor()
    vortexIndicator.color = quantColors[Std.int(FlxMath.bound(quantizations.indexOf(curQuant), 0, quantColors.length - 1))];

  var sectionFirstNoteID:Int = 0;
  var sectionFirstEventID:Int = 0;
  var curSec:Int = 0;

  var chartEditorSave:FlxSave;
  var mainBox:PsychUIBox;
  var mainBoxPosition:FlxPoint = FlxPoint.get(920, 40);
  var eventBox:PsychUIBox;
  var eventBoxPosition:FlxPoint = FlxPoint.get(40, 200);
  var infoBox:PsychUIBox;
  var infoBoxPosition:FlxPoint = FlxPoint.get(1000, 360);
  var upperBox:PsychUIBox;

  var camGame:FlxCamera;
  var camUI:FlxCamera;

  var prevGridBg:ChartingGridSprite;
  var gridBg:ChartingGridSprite;
  var nextGridBg:ChartingGridSprite;
  var waveformSprite:FlxSprite;
  var scrollY:Float = 0;

  var zoomList:Array<Float> = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 24];
  var curZoom:Float = 1;

  var mustHitIndicator:FlxSprite;
  var eventIcon:FlxSprite;
  var icons:Array<HealthIcon> = [];

  var events:Array<EventMetaNote> = [];
  var notes:Array<MetaNote> = [];

  var behindRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
  var curRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
  var movingNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
  var eventLockOverlay:FlxSprite;
  var vortexIndicator:FlxSprite;
  var strumLineNotes:Strumline = new Strumline(8);
  var dummyArrow:FlxSprite;
  var isMovingNotes:Bool = false;
  var movingNotesLastData:Int = 0;
  var movingNotesLastY:Float = 0;

  var vocals:FlxSound = new FlxSound();
  var opponentVocals:FlxSound = new FlxSound();

  var timeLine:FlxSprite;
  var infoText:FlxText;

  var autoSaveIcon:FlxSprite;
  var outputTxt:FlxText;

  var selectionStart:FlxPoint = FlxPoint.get();
  var selectionBox:FlxSprite;

  var _shouldReset:Bool = true;

  public function new(?shouldReset:Bool = true)
  {
    this._shouldReset = shouldReset;
    super();
  }

  var bg:FlxSprite;
  var theme:ChartingTheme = DEFAULT;

  var copiedNotes:Array<Dynamic> = [];
  var copiedEvents:Array<Dynamic> = [];

  var _keysPressedBuffer:Array<Bool> = [];

  var tipBg:FlxSprite;
  var fullTipText:FlxText;

  var vortexEnabled:Bool = false;
  var waveformEnabled:Bool = false;
  var waveformTarget:WaveformTarget = INST;

  override function create()
  {
    if (Difficulty.list.length < 1) Difficulty.resetList();
    _keysPressedBuffer.resize(keysArray.length);

    if (_shouldReset) Conductor.songPosition = 0;
    persistentUpdate = false;
    FlxG.mouse.visible = true;
    FlxG.sound.list.add(vocals);
    FlxG.sound.list.add(opponentVocals);

    vocals.autoDestroy = false;
    vocals.looped = true;
    opponentVocals.autoDestroy = false;
    opponentVocals.looped = true;

    camGame = initPsychCamera();
    camUI = new FlxCamera();
    camUI.bgColor.alpha = 0;
    FlxG.cameras.add(camUI, false);

    chartEditorSave = new FlxSave();
    chartEditorSave.bind('chart_editor_data', CoolUtil.getSavePath());

    bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.antialiasing = ClientPrefs.data.antialiasing;
    bg.scrollFactor.set();
    add(bg);

    if (chartEditorSave.data.autoSave != null) autoSaveCap = chartEditorSave.data.autoSave;
    if (chartEditorSave.data.backupLimit != null) backupLimit = chartEditorSave.data.backupLimit;
    if (chartEditorSave.data.vortex != null) vortexEnabled = chartEditorSave.data.vortex;

    changeTheme(chartEditorSave.data.theme != null ? chartEditorSave.data.theme : DEFAULT, false);

    createGrids();

    waveformSprite = new FlxSprite(gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0), 0).makeGraphic(1, 1, 0x00FFFFFF);
    waveformSprite.scrollFactor.x = 0;
    waveformSprite.visible = false;
    add(waveformSprite);

    dummyArrow = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
    dummyArrow.setGraphicSize(GRID_SIZE, GRID_SIZE);
    dummyArrow.updateHitbox();
    dummyArrow.scrollFactor.x = 0;
    add(dummyArrow);

    vortexIndicator = new FlxSprite(gridBg.x - GRID_SIZE, FlxG.height / 2).loadGraphic(Paths.image('editors/vortex_indicator'));
    vortexIndicator.setGraphicSize(GRID_SIZE);
    vortexIndicator.updateHitbox();
    vortexIndicator.scrollFactor.set();
    vortexIndicator.active = false;
    updateVortexColor();
    add(vortexIndicator);
    add(strumLineNotes);

    add(behindRenderedNotes);
    add(curRenderedNotes);
    add(movingNotes);

    eventLockOverlay = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.BLACK);
    eventLockOverlay.alpha = 0.6;
    eventLockOverlay.visible = false;
    eventLockOverlay.scrollFactor.x = 0;
    eventLockOverlay.scale.x = GRID_SIZE;
    eventLockOverlay.updateHitbox();
    add(eventLockOverlay);

    timeLine = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.WHITE);
    timeLine.setGraphicSize(Std.int(gridBg.width), 4);
    timeLine.updateHitbox();
    timeLine.screenCenter(Y);
    timeLine.scrollFactor.set();
    add(timeLine);

    var startX:Float = gridBg.x;
    var startY:Float = FlxG.height / 2;
    vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
    if (SHOW_EVENT_COLUMN) startX += GRID_SIZE;

    for (i in 0...Std.int(GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER))
    {
      var note:StrumArrow = new StrumArrow(startX + (GRID_SIZE * i), startY, i % GRID_COLUMNS_PER_PLAYER, 0, PlayState.SONG?.options?.strumSkin, false, true);
      note.scrollFactor.set();
      note.playAnim('static');
      note.alpha = 0.4;
      note.updateHitbox();
      if (note.width > note.height) note.setGraphicSize(GRID_SIZE);
      else
        note.setGraphicSize(0, GRID_SIZE);

      note.updateHitbox();

      note.x += GRID_SIZE / 2 - note.width / 2;
      note.y += GRID_SIZE / 2 - note.height / 2;
      strumLineNotes.add(note);
    }

    var columns:Int = 0;
    var iconX:Float = gridBg.x;
    var iconY:Float = 50;
    if (SHOW_EVENT_COLUMN)
    {
      eventIcon = new FlxSprite(0, iconY).loadGraphic(Paths.image('editors/eventIcon'));
      eventIcon.antialiasing = ClientPrefs.data.antialiasing;
      eventIcon.alpha = 0.6;
      eventIcon.setGraphicSize(30, 30);
      eventIcon.updateHitbox();
      eventIcon.scrollFactor.set();
      add(eventIcon);
      eventIcon.x = iconX + (GRID_SIZE * 0.5) - eventIcon.width / 2;
      iconX += GRID_SIZE;

      columns++;
    }

    mustHitIndicator = FlxSpriteUtil.drawTriangle(new FlxSprite(0, iconY - 20).makeGraphic(16, 16, FlxColor.TRANSPARENT), 0, 0, 16);
    mustHitIndicator.scrollFactor.set();
    mustHitIndicator.flipY = true;
    mustHitIndicator.offset.x += mustHitIndicator.width / 2;
    add(mustHitIndicator);

    var gridStripes:Array<Int> = [];
    for (i in 0...GRID_PLAYERS)
    {
      if (columns > 0) gridStripes.push(columns);
      columns += GRID_COLUMNS_PER_PLAYER;

      var icon:HealthIcon = new HealthIcon();
      icon.autoAdjustOffset = false;
      icon.y = iconY;
      icon.alpha = 0.6;
      icon.scrollFactor.set();
      icon.scale.set(0.3, 0.3);
      icon.updateHitbox();
      icon.ID = i + 1;
      add(icon);
      icons.push(icon);

      icon.x = iconX + GRID_SIZE * (GRID_COLUMNS_PER_PLAYER / 2) - icon.width / 2;
      iconX += GRID_SIZE * GRID_COLUMNS_PER_PLAYER;
    }
    prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = gridStripes;

    selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.CYAN);
    selectionBox.alpha = 0.4;
    selectionBox.blend = ADD;
    selectionBox.scrollFactor.set();
    selectionBox.visible = false;
    add(selectionBox);

    infoBox = new PsychUIBox(infoBoxPosition.x, infoBoxPosition.y, 220, 220, ['Information']);
    infoBox.scrollFactor.set();
    infoBox.cameras = [camUI];
    infoText = new FlxText(15, 15, 230, '', 16);
    infoText.scrollFactor.set();
    infoBox.getTab('Information').menu.add(infoText);
    add(infoBox);

    mainBox = new PsychUIBox(mainBoxPosition.x, mainBoxPosition.y, 330, 280, ['Charting', 'Data', 'Note', 'Section', 'Song', 'Gameplay Options']);
    mainBox.selectedName = 'Song';
    mainBox.scrollFactor.set();
    mainBox.cameras = [camUI];
    add(mainBox);

    eventBox = new PsychUIBox(eventBoxPosition.x, eventBoxPosition.y, 380, 480, ['Events']);
    eventBox.selectedName = 'Events';
    eventBox.scrollFactor.set();
    eventBox.cameras = [camUI];
    add(eventBox);

    autoSaveIcon = new FlxSprite(50).loadGraphic(Paths.image('editors/autosave'));
    autoSaveIcon.screenCenter(Y);
    autoSaveIcon.scale.set(0.6, 0.6);
    autoSaveIcon.antialiasing = ClientPrefs.data.antialiasing;
    autoSaveIcon.scrollFactor.set();
    autoSaveIcon.alpha = 0;
    add(autoSaveIcon);

    // save data positions for the UI boxes
    if (chartEditorSave.data.mainBoxPosition != null
      && chartEditorSave.data.mainBoxPosition.length > 1) mainBox.setPosition(chartEditorSave.data.mainBoxPosition[0], chartEditorSave.data.mainBoxPosition[1]);
    if (chartEditorSave.data.eventBoxPosition != null
      && chartEditorSave.data.eventBoxPosition.length > 1) eventBox.setPosition(chartEditorSave.data.eventBoxPosition[0],
        chartEditorSave.data.eventBoxPosition[1]);
    if (chartEditorSave.data.infoBoxPosition != null
      && chartEditorSave.data.infoBoxPosition.length > 1) infoBox.setPosition(chartEditorSave.data.infoBoxPosition[0], chartEditorSave.data.infoBoxPosition[1]);

    upperBox = new PsychUIBox(40, 40, 330, 300, ['File', 'Edit', 'View']);
    upperBox.scrollFactor.set();
    upperBox.isMinimized = true;
    upperBox.minimizeOnFocusLost = true;
    upperBox.canMove = false;
    upperBox.cameras = [camUI];
    upperBox.bg.visible = false;
    add(upperBox);

    outputTxt = new FlxText(25, FlxG.height - 50, FlxG.width - 50, '', 20);
    outputTxt.borderSize = 2;
    outputTxt.borderStyle = OUTLINE_FAST;
    outputTxt.scrollFactor.set();
    outputTxt.cameras = [camUI];
    outputTxt.alpha = 0;
    add(outputTxt);

    if (PlayState.SONG == null) // Atleast try to avoid crashes
    {
      openNewChart();
    }

    updateJsonData();

    // TABS
    ////// for main box
    addChartingTab();
    addDataTab();
    addNoteTab();
    addSectionTab();
    addSongTab();
    addGameplayOptionsTab();

    ////// for event box
    addEventsTab();

    ////// for upper box
    addFileTab();
    addEditTab();
    addViewTab();
    //

    loadMusic();
    reloadNotesDropdowns();
    if (!_shouldReset)
    {
      vocals.time = opponentVocals.time = FlxG.sound.music.time = Conductor.songPosition - Conductor.offset;
      if (FlxG.sound.music.time >= vocals.length) vocals.pause();
      if (FlxG.sound.music.time >= opponentVocals.length) opponentVocals.pause();
    }

    reloadNotes();
    updateGridVisibility();

    // CHARACTERS FOR THE DROP DOWNS
    var gameOverCharacters:Array<String> = loadFileList('data/characters/', 'data/characterList.txt');
    var characterList:Array<String> = gameOverCharacters.filter((name:String) -> (!name.endsWith('-dead') && !name.endsWith('-death')));
    playerDropDown.list = characterList;
    opponentDropDown.list = characterList;
    girlfriendDropDown.list = characterList;

    gameOverCharacters.insert(0, '');
    gameOverCharacters.sort(function(a:String, b:String) {
      if ((a == '' || a.endsWith('-dead') || a.endsWith('-death'))
        && !(b == '' || b.endsWith('-dead') || b.endsWith('-death'))) return -1; // Prioritize "-dead" or "-death" characters
      return 0;
    });
    gameOverCharDropDown.list = gameOverCharacters;

    stageDropDown.list = loadFileList('data/stages/', 'data/stageList.txt');
    onChartLoaded();

    var tipText:FlxText = new FlxText(FlxG.width - 210, FlxG.height - 30, 200, 'Press F1 for Help', 20);
    tipText.cameras = [camUI];
    tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT);
    tipText.borderColor = FlxColor.BLACK;
    tipText.scrollFactor.set();
    tipText.borderSize = 1;
    tipText.active = false;
    add(tipText);

    tipBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
    tipBg.cameras = [camUI];
    tipBg.scale.set(FlxG.width, FlxG.height);
    tipBg.updateHitbox();
    tipBg.scrollFactor.set();
    tipBg.visible = tipBg.active = false;
    tipBg.alpha = 0.6;
    add(tipBg);

    fullTipText = new FlxText(0, 0, FlxG.width - 200);
    fullTipText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
    fullTipText.cameras = [camUI];
    fullTipText.scrollFactor.set();
    fullTipText.visible = fullTipText.active = false;
    fullTipText.text = [
      "W/S/Mouse Wheel - Move Conductor's Time",
      "A/D - Change Sections",
      "Q/E - Decrease/Increase Note Sustain Length",
      "Hold Shift/Alt to Increase/Decrease move by 4x",
      "",
      "F12 - Preview Chart",
      "Enter - Playtest Chart",
      "Space - Stop/Resume song",
      "",
      "Alt + Click - Select Note(s)",
      "Shift + Click - Select/Unselect Note(s)",
      "Right Click - Selection Box",
      "",
      "R - Reset Section",
      "Z/X - Zoom in/out",
      "Left/Right - Change Snap",
      #if FLX_PITCH
      "Left Bracket / Right Bracket - Change Song Playback Rate", "ALT + Left Bracket / Right Bracket - Reset Song Playback Rate",
      #end
      "",
      "Ctrl + Z - Undo",
      "Ctrl + Y - Redo",
      "Ctrl + X - Cut Selected Notes",
      "Ctrl + C - Copy Selected Notes",
      "Ctrl + V - Paste Copied Notes",
      "Ctrl + A - Select all in current Section",
      "Ctrl + S - Quicksave",
    ].join('\n');
    fullTipText.screenCenter();
    add(fullTipText);

    super.create();
  }

  var gridColors:Array<FlxColor>;
  var gridColorsOther:Array<FlxColor>;

  function changeTheme(changeTo:ChartingTheme, ?doSave:Bool = true)
  {
    var oldTheme:ChartingTheme = theme;
    theme = changeTo;
    chartEditorSave.data.theme = changeTo;
    if (doSave) chartEditorSave.flush();

    var gridBgWidth = gridBg == null ? null : gridBg.width;
    var prevGridBgWidth = prevGridBg == null ? null : prevGridBg.width;
    var nextGridBgWidth = nextGridBg == null ? null : nextGridBg.width;

    switch (theme)
    {
      case LIGHT:
        bg.color = 0xFFA0A0A0;
        gridColors = [0xFFDFDFDF, 0xFFBFBFBF];
        gridColorsOther = [0xFF5F5F5F, 0xFF4A4A4A];
      case DARK:
        bg.color = 0xFF222222;
        gridColors = [0xFF3F3F3F, 0xFF2F2F2F];
        gridColorsOther = [0xFF1F1F1F, 0xFF111111];
      default:
        bg.color = 0xFF303030;
        gridColors = [0xFFDFDFDF, 0xFFBFBFBF];
        gridColorsOther = [0xFF5F5F5F, 0xFF4A4A4A];
    }

    if (theme != oldTheme)
    {
      if (gridBg != null)
      {
        gridBg.loadGrid(gridColors[0], gridColors[1]);
        gridBg.vortexLineEnabled = vortexEnabled;
        gridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
        if (gridBgWidth != null) gridBg.width = gridBgWidth;
      }
      if (prevGridBg != null)
      {
        prevGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
        prevGridBg.vortexLineEnabled = vortexEnabled;
        prevGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
        if (prevGridBgWidth != null) prevGridBg.width = prevGridBgWidth;
      }
      if (nextGridBg != null)
      {
        nextGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
        nextGridBg.vortexLineEnabled = vortexEnabled;
        nextGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
        if (nextGridBgWidth != null) prevGridBg.width = nextGridBgWidth;
      }
    }
  }

  function openNewChart()
  {
    var song:SwagSong =
      {
        song: 'Test',
        songId: 'Test',
        notes: [],
        events: [],
        bpm: 150,
        needsVoices: true,
        speed: 1,
        offset: 0,

        notITG: false,
        sleHUD: false,

        stage: 'stage',
        format: 'psych_v1',
      };
    Song.defaultIfNotFound(song);
    Song.chartPath = null;
    loadChart(song);
  }

  function prepareReload()
  {
    updateJsonData();
    loadMusic();
    reloadNotes();
    onChartLoaded();

    updateHeads(true);

    Conductor.songPosition = 0;
    if (FlxG.sound.music != null) FlxG.sound.music.time = 0;
    curSec = 0;
    loadSection();
    forceDataUpdate = true;
  }

  function onChartLoaded()
  {
    if (PlayState.SONG == null) return;

    // SONG TAB
    songNameInputText.text = PlayState.SONG.songId;
    allowVocalsCheckBox.checked = (PlayState.SONG.needsVoices != false); // If the song for some reason does not have this value, it will be set to true

    bpmStepper.value = PlayState.SONG.bpm;
    scrollSpeedStepper.value = PlayState.SONG.speed;
    audioOffsetStepper.value = Reflect.hasField(PlayState.SONG, 'offset') ? PlayState.SONG.offset : 0;
    Conductor.offset = audioOffsetStepper.value;

    playerDropDown.selectedLabel = PlayState.SONG.characters.player;
    opponentDropDown.selectedLabel = PlayState.SONG.characters.opponent;
    girlfriendDropDown.selectedLabel = PlayState.SONG.characters.girlfriend;
    stageDropDown.selectedLabel = PlayState.SONG.stage;
    StageData.loadDirectory(PlayState.SONG);

    // NOTE TAB
    noRGBCheckBox.checked = PlayState.SONG.options.disableNoteRGB;
    noRGBQuantCheckBox.checked = PlayState.SONG.options.disableNoteQuantRGB;
    noStrumRGBCheckBox.checked = PlayState.SONG.options.disableStrumRGB;
    noSplashRGBCheckBox.checked = PlayState.SONG.options.disableSplashRGB;
    noHoldCoverRGBCheckBox.checked = PlayState.SONG.options.disableHoldCoversRGB;

    opponentNoteStyleInputText.text = PlayState.SONG.options.opponentNoteStyle;
    playerNoteStyleInputText.text = PlayState.SONG.options.playerNoteStyle;
    opponentStrumStyleInputText.text = PlayState.SONG.options.opponentStrumStyle;
    playerStrumStyleInputText.text = PlayState.SONG.options.playerStrumStyle;

    // DATA TAB
    gameOverCharDropDown.selectedLabel = PlayState.SONG.gameOverData.gameOverChar;
    gameOverSndInputText.text = PlayState.SONG.gameOverData.gameOverSound;
    gameOverLoopInputText.text = PlayState.SONG.gameOverData.gameOverLoop;
    gameOverRetryInputText.text = PlayState.SONG.gameOverData.gameOverEnd;

    holdCoverSkinInputText.text = PlayState.SONG.options.holdCoverSkin;
    noteTextureInputText.text = PlayState.SONG.options.arrowSkin;
    strumTextureInputText.text = PlayState.SONG.options.strumSkin;
    noteSplashesInputText.text = PlayState.SONG.options.splashSkin;

    // GAMEPLAY OPTIONS TAB
    disableCachingCheckBox.checked = PlayState.SONG.options.disableCaching;
    notITGModchartCheckBox.checked = PlayState.SONG.options.notITG;
    usesHUDCheckBox.checked = PlayState.SONG.options.usesHUD;
    oldBarSystemCheckBox.checked = PlayState.SONG.options.oldBarSystem;
    forceRightScrollCheckBox.checked = PlayState.SONG.options.rightScroll;
    forceMiddleScrollCheckBox.checked = PlayState.SONG.options.middleScroll;
    blockOpponentModeCheckBox.checked = PlayState.SONG.options.blockOpponentMode;

    useSLEHUDCheckBox.checked = if (PlayState.SONG.options.sleHUD != null) PlayState.SONG.options.sleHUD else PlayState.SONG.sleHUD;

    vocalsPrefixInputText.text = PlayState.SONG.options.vocalsPrefix;
    vocalsSuffixInputText.text = PlayState.SONG.options.vocalsSuffix;

    instrumentalPrefixInputText.text = PlayState.SONG.options.instrumentalPrefix;
    instrumentalSuffixInputText.text = PlayState.SONG.options.instrumentalSuffix;
  }

  var noteSelectionSine:Float = 0;
  var selectedNotes:Array<MetaNote> = [];
  var ignoreClickForThisFrame:Bool = false;
  var outputAlpha:Float = 0;
  var songFinished:Bool = false;

  var fileDialog:FileDialogHandler = new FileDialogHandler();
  var lastFocus:PsychUIInputText;

  var autoSaveTime:Float = 0;
  var autoSaveCap:Int = 2; // in minutes
  var backupLimit:Int = 10;

  var lastBeatHit:Int = 0;

  override function update(elapsed:Float)
  {
    if (!fileDialog.completed)
    {
      lastFocus = PsychUIInputText.focusOn;
      return;
    }

    for (num => key in keysArray)
      _keysPressedBuffer[num] = FlxG.keys.checkStatus(key, JUST_PRESSED);

    if (autoSaveCap > 0)
    {
      autoSaveTime += elapsed / 60.0;
      // trace(autoSaveTime);
      // #if debug if(FlxG.keys.justPressed.J) autoSaveTime += 20/60.0; #end
      if (autoSaveTime >= autoSaveCap #if debug || FlxG.keys.justPressed.NUMPADMULTIPLY #end)
      {
        FlxTween.cancelTweensOf(autoSaveIcon);
        autoSaveTime = 0;
        autoSaveIcon.alpha = 0;
        updateChartData();
        var chartName:String = 'unknown';
        if (Song.chartPath != null)
        {
          chartName = Song.chartPath.replace('/', '\\');
          chartName = chartName.substring(chartName.lastIndexOf('\\') + 1, chartName.lastIndexOf('.'));
        }
        chartName += DateTools.format(Date.now(), '_%Y-%m-%d_%H-%M-%S');
        var songCopy:SwagSong = Reflect.copy(PlayState.SONG);
        Reflect.setField(songCopy, '__original_path', Song.chartPath);
        var dataToSave:String = haxe.Json.stringify(songCopy);
        // trace(chartName, dataToSave);
        if (!FileSystem.isDirectory('backups')) FileSystem.createDirectory('backups');
        File.saveContent('backups/$chartName.$BACKUP_EXT', dataToSave);

        if (backupLimit > 0)
        {
          var files:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
          if (files.length > backupLimit)
          {
            var incorrect:Array<String> = [];
            var map:Map<String, Float> = [];
            for (file in files)
            {
              var split:Array<String> = file.split('_');
              if (split.length > 2) // is properly formatted
              {
                try
                {
                  var timeStr:String = split[split.length - 1].replace('-', ':');
                  timeStr = timeStr.substr(0, timeStr.indexOf('.'));

                  var fileJoin:String = split[split.length - 2] + ' ' + timeStr;
                  var date:Date = Date.fromString(fileJoin);
                  // trace(fileJoin, date.getTime());
                  map.set(file, date.getTime());
                }
                catch (e:Exception)
                {
                  incorrect.push(file);
                }
              }
              else
                incorrect.push(file);
            }

            if (incorrect.length > 0) files = files.filter((file:String) -> !incorrect.contains(file));
            files.sort(function(a:String, b:String) return map.get(a) > map.get(b) ? 1 : -1);

            while (files.length > backupLimit)
            {
              var file = files.shift();
              // trace('removed $file');
              try
              {
                FileSystem.deleteFile('backups/$file');
              }
              catch (e:Exception) {}
            }
          }
        }

        FlxTween.tween(autoSaveIcon, {alpha: 1}, 0.5,
          {
            onComplete: function(_) FlxTween.tween(autoSaveIcon, {alpha: 0}, 0.5, {startDelay: 2})
          });
      }
    }

    ClientPrefs.toggleVolumeKeys(PsychUIInputText.focusOn == null);

    var lastTime:Float = Conductor.songPosition;
    outputAlpha = Math.max(0, outputAlpha - elapsed);
    var holdingAlt:Bool = FlxG.keys.pressed.ALT;
    if (FlxG.sound.music != null)
    {
      if (PsychUIInputText.focusOn == null) // If not typing anything
      {
        var doCut:Bool = false;
        var canContinue:Bool = true;
        if (FlxG.keys.justPressed.F12)
        {
          super.update(elapsed);
          openEditorPlayState();
          lastFocus = PsychUIInputText.focusOn;
          return;
        }
        else if (FlxG.keys.justPressed.F1)
        {
          var vis:Bool = !fullTipText.visible;
          tipBg.visible = tipBg.active = fullTipText.visible = fullTipText.active = vis;
        }

        var goingBack:Bool = false;
        if (FlxG.keys.pressed.RBRACKET || (FlxG.keys.pressed.LBRACKET && (goingBack = true)))
        {
          if (holdingAlt)
          {
            if (playbackRate != 1)
            {
              playbackRate = 1;
              setPitch();
            }
          }
          else
          {
            playbackRate = FlxMath.bound(playbackRate + elapsed * (!goingBack ? 1 : -1), playbackSlider.min, playbackSlider.max);
            setPitch();
          }
          playbackSlider.value = playbackRate;
        }

        if (vortexEnabled && _keysPressedBuffer.contains(true))
        {
          var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex];
          if (typeSelected != null)
          {
            typeSelected = typeSelected.trim();
            if (typeSelected.length < 1) typeSelected = null;
          }

          var sectionStart:Float = cachedSectionTimes[curSec];
          var strumTime:Float = Conductor.songPosition - sectionStart;
          strumTime -= strumTime % (Conductor.stepCrochet * 16 / curQuant);
          strumTime += sectionStart;

          trace('Vortex editor press at time: $strumTime');
          var deletedNotes:Array<MetaNote> = [];
          var addedNotes:Array<MetaNote> = [];
          for (num => press in _keysPressedBuffer)
          {
            if (!press) continue;

            // Try to find a note to delete first
            var didDelete:Bool = false;
            for (note in curRenderedNotes)
            {
              if (note == null || note.isEvent) continue;

              if (note.songData[1] == num && Math.abs(strumTime - note.strumTime) < 1)
              {
                deletedNotes.push(note);
                didDelete = true;
                break;
              }
            }

            if (didDelete) continue;

            // If no notes were found, add a new in its place
            var didAdd:Bool = false;
            var noteSetupData:Array<Dynamic> = [strumTime, num, 0];
            if (typeSelected != null) noteSetupData.push(typeSelected);

            var noteAdded:MetaNote = createNote(noteSetupData);
            for (num in sectionFirstNoteID...notes.length)
            {
              var note = notes[num];
              if (note.strumTime >= strumTime)
              {
                notes.insert(num, noteAdded);
                didAdd = true;
                break;
              }
            }
            if (!didAdd) notes.push(noteAdded);
            addedNotes.push(noteAdded);
          }

          if (deletedNotes.length > 0)
          {
            var wasSelected:Bool = false;
            for (note in deletedNotes)
            {
              if (selectedNotes.contains(note))
              {
                selectedNotes.remove(note);
                wasSelected = true;
              }
              notes.remove(note);
            }
            if (wasSelected) onSelectNote();

            addUndoAction(DELETE_NOTE, {notes: deletedNotes});
          }
          if (addedNotes.length > 0) addUndoAction(ADD_NOTE, {notes: addedNotes});
          softReloadNotes(true);
        }
        else if (FlxG.keys.justPressed.A != FlxG.keys.justPressed.D && !holdingAlt)
        {
          if (FlxG.sound.music.playing) setSongPlaying(false);

          var shiftAdd:Int = FlxG.keys.pressed.SHIFT ? 4 : 1;

          if (FlxG.keys.justPressed.A)
          {
            if (curSec - shiftAdd < 0) shiftAdd = curSec;

            if (shiftAdd > 0)
            {
              loadSection(curSec - shiftAdd);
              Conductor.songPosition = FlxG.sound.music.time = cachedSectionTimes[curSec] + 0.000001;
            }
          }
          else if (FlxG.keys.justPressed.D)
          {
            if (curSec + shiftAdd >= PlayState.SONG.notes.length) shiftAdd = PlayState.SONG.notes.length - curSec - 1;

            if (shiftAdd > 0)
            {
              loadSection(curSec + shiftAdd);
              Conductor.songPosition = FlxG.sound.music.time = cachedSectionTimes[curSec] + 0.000001;
            }
          }
        }
        else if (FlxG.keys.justPressed.R)
        {
          Conductor.songPosition = FlxG.sound.music.time = cachedSectionTimes[curSec] + (curSec > 0 ? 0.000001 : 0);
        }
        else if (FlxG.keys.pressed.W != FlxG.keys.pressed.S || FlxG.mouse.wheel != 0)
        {
          if (FlxG.sound.music.playing) setSongPlaying(false);

          if (mouseSnapCheckBox.checked && FlxG.mouse.wheel != 0)
          {
            var snap:Float = Conductor.stepCrochet / (curQuant / 16) / curZoom;
            var timeAdd:Float = (FlxG.keys.pressed.SHIFT ? 4 : 1) / (holdingAlt ? 4 : 1) * -FlxG.mouse.wheel * snap;
            var time:Float = Math.round((FlxG.sound.music.time + timeAdd) / snap) * snap;
            if (time > 0) time += 0.000001; // goes at the start of a section more properly
            FlxG.sound.music.time = time;
          }
          else
          {
            var speedMult:Float = (FlxG.keys.pressed.SHIFT ? 4 : 1) * (FlxG.mouse.wheel != 0 ? 4 : 1) / (holdingAlt ? 4 : 1);
            if (FlxG.keys.pressed.W || FlxG.mouse.wheel > 0) FlxG.sound.music.time -= Conductor.crochet * speedMult * elapsed / curZoom;
            else if (FlxG.keys.pressed.S || FlxG.mouse.wheel < 0) FlxG.sound.music.time += Conductor.crochet * speedMult * elapsed / curZoom;
          }

          FlxG.sound.music.time = FlxMath.bound(FlxG.sound.music.time, 0, FlxG.sound.music.length - 1);
          if (FlxG.sound.music.playing) setSongPlaying(!FlxG.sound.music.playing);
        }
        else if (FlxG.keys.justPressed.SPACE)
        {
          setSongPlaying(!FlxG.sound.music.playing);
        }
      }

      if (!songFinished) Conductor.songPosition = FlxMath.bound(FlxG.sound.music.time + Conductor.offset, 0, FlxG.sound.music.length - 1);
      updateScrollY();
    }

    super.update(elapsed);

    if (songFinished)
    {
      onSongComplete();
      lastTime = FlxG.sound.music.time;
      songFinished = false;
    }
    else if (FlxG.sound.music != null)
    {
      if (FlxG.sound.music.time >= vocals.length) vocals.pause();
      if (FlxG.sound.music.time >= opponentVocals.length) opponentVocals.pause();

      if (curSec > 0 && Conductor.songPosition < cachedSectionTimes[curSec]) loadSection(curSec - 1);
      else if (curSec < cachedSectionTimes.length - 1 && Conductor.songPosition >= cachedSectionTimes[curSec + 1]) loadSection(curSec + 1);
    }

    if (PsychUIInputText.focusOn == null && lastFocus == null)
    {
      var doCut:Bool = false;
      var canContinue:Bool = true;
      if (FlxG.keys.justPressed.ENTER)
      {
        goToPlayState();
        return;
      }
      else if (FlxG.keys.pressed.CONTROL
        && !isMovingNotes
        && (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.Y || FlxG.keys.justPressed.X || FlxG.keys.justPressed.C || FlxG.keys.justPressed.V
          || FlxG.keys.justPressed.A || FlxG.keys.justPressed.S))
      {
        canContinue = false;
        if (FlxG.keys.justPressed.Z) undo();
        else if (FlxG.keys.justPressed.Y) redo();
        else if ((doCut = FlxG.keys.justPressed.X) || FlxG.keys.justPressed.C) // Cut (Ctrl + X) and Copy (Ctrl + C)
        {
          if (selectedNotes.length > 0)
          {
            copiedNotes = [];
            copiedEvents = [];
            var pushedNotes:Array<Array<Dynamic>> = [];

            for (note in selectedNotes)
            {
              if (note == null) continue;

              var copied:Array<Dynamic> = makeNoteDataCopy(note.songData, note.isEvent);
              pushedNotes.push(copied);
              if (note.isEvent) copiedEvents.push(copied);
              else
                copiedNotes.push(copied);
            }
            pushedNotes.sort((a:Array<Dynamic>, b:Array<Dynamic>) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));

            var minTime:Float = pushedNotes[0][0];
            for (note in pushedNotes)
              note[0] -= minTime;
          }
        }
        else if (FlxG.keys.justPressed.V) // Paste (Ctrl + V)
        {
          if (copiedNotes.length > 0 || copiedEvents.length > 0)
          {
            selectionBox.visible = false;
            stopMovingNotes();
            resetSelectedNotes();
            selectedNotes = pasteCopiedNotesToSection();
            selectedNotes.sort(PlayState.sortByTime);

            var didFind:Bool = false;
            var minNoteData:Float = Math.POSITIVE_INFINITY;
            for (note in selectedNotes)
            {
              if (note == null || note.isEvent) continue;

              if (minNoteData > note.songData[1]) minNoteData = note.songData[1];
              didFind = true;
            }
            if (!didFind) minNoteData = 0;

            var pushedNotes:Array<MetaNote> = [];
            var pushedEvents:Array<EventMetaNote> = [];
            for (note in selectedNotes)
            {
              if (note == null) continue;
              if (!note.isEvent)
              {
                note.changeNoteData(Std.int(note.songData[1] - minNoteData));
                pushedNotes.push(note);
              }
              else
                pushedEvents.push(cast(note, EventMetaNote));
            }
            addUndoAction(ADD_NOTE, {notes: pushedNotes, events: pushedEvents});
            moveSelectedNotes(Std.int(minNoteData), selectedNotes[0].y);
          }
        }
        else if (FlxG.keys.justPressed.A) // Select All (Ctrl + A)
        {
          var sel = selectedNotes;
          selectedNotes = curRenderedNotes.members.copy();
          addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
          onSelectNote();
          trace('Notes selected: ' + selectedNotes.length);
        }
        else if (FlxG.keys.justPressed.S) // Save (Ctrl + S)
          saveChart();
      }

      if (doCut
        || FlxG.keys.justPressed.DELETE
        || FlxG.keys.justPressed.BACKSPACE
        || (isMovingNotes && (FlxG.mouse.justPressedRight || FlxG.keys.justPressed.ESCAPE))) // Delete button
      {
        if (selectedNotes.length > 0)
        {
          var removedNotes:Array<MetaNote> = [];
          var removedEvents:Array<EventMetaNote> = [];
          while (selectedNotes.length > 0)
          {
            var note:MetaNote = selectedNotes[0];
            selectedNotes.shift();
            if (note == null) continue;

            trace('Removed ${!note.isEvent ? 'note' : 'event'} at time: ${note.strumTime}');
            if (!note.isEvent)
            {
              notes.remove(note);
              removedNotes.push(note);
            }
            else
            {
              var ev:EventMetaNote = cast(note, EventMetaNote);
              events.remove(ev);
              removedEvents.push(ev);
            }
          }
          movingNotes.clear();
          isMovingNotes = false;
          selectedNotes = [];
          onSelectNote();
          softReloadNotes();
          addUndoAction(DELETE_NOTE, {notes: removedNotes, events: removedEvents});
        }
      }
      else if (canContinue)
      {
        if (FlxG.keys.justPressed.LEFT != FlxG.keys.justPressed.RIGHT) // Lower/Higher quant
        {
          if (FlxG.keys.justPressed.LEFT) curQuant = quantizations[Std.int(Math.max(quantizations.indexOf(curQuant) - 1, 0))];
          else
            curQuant = quantizations[Std.int(Math.min(quantizations.indexOf(curQuant) + 1, quantizations.length - 1))];
          forceDataUpdate = true;
        }
        else if (FlxG.keys.justPressed.Z != FlxG.keys.justPressed.X) // Decrease/Increase Zoom
        {
          if (FlxG.keys.justPressed.Z) curZoom = zoomList[Std.int(Math.max(zoomList.indexOf(curZoom) - 1, 0))];
          else
            curZoom = zoomList[Std.int(Math.min(zoomList.indexOf(curZoom) + 1, zoomList.length - 1))];

          notes.sort(PlayState.sortByTime);
          var noteSec:Int = 0;
          var nextSectionTime:Float = cachedSectionTimes[noteSec + 1];
          var curSectionTime:Float = cachedSectionTimes[noteSec];
          for (num => note in notes)
          {
            if (note == null) continue;

            while (cachedSectionTimes[noteSec + 1] <= note.strumTime)
            {
              noteSec++;
              nextSectionTime = cachedSectionTimes[noteSec + 1];
              curSectionTime = cachedSectionTimes[noteSec];
            }
            positionNoteYOnTime(note, noteSec);
          }
          for (event in events)
          {
            var secNum:Int = 0;
            for (time in cachedSectionTimes)
            {
              if (time > event.strumTime) break;
              secNum++;
            }
            positionNoteYOnTime(event, secNum);
          }
          loadSection();
          showOutput('Zoom: ${Math.round(curZoom * 100)}%');
          updateScrollY();
        }
      }
    }

    if (selectionBox.visible)
    {
      if (FlxG.mouse.releasedRight)
      {
        var sel = selectedNotes.copy();
        updateSelectionBox();
        if (!FlxG.keys.pressed.SHIFT && !holdingAlt) resetSelectedNotes();

        var selectionBounds = selectionBox.getScreenBounds(null, camUI);
        for (note in curRenderedNotes)
        {
          if (note == null) continue;

          if (!selectedNotes.contains(note) || holdingAlt /*&& FlxG.overlap(selectionBox, note)*/) // overlap doesnt work here
          {
            var noteBounds = note.getScreenBounds(null, camUI);
            noteBounds.top -= scrollY;
            noteBounds.bottom -= scrollY;

            if (selectionBounds.overlaps(noteBounds))
            {
              if (holdingAlt && selectedNotes.contains(note))
              {
                selectedNotes.remove(note);
                note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
                if (note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
              }
              else
                selectedNotes.push(note);
              onSelectNote();
            }
          }
        }
        selectionBox.visible = false;
        addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
      }
      else if (FlxG.mouse.justMoved) updateSelectionBox();
    }
    else if (FlxG.mouse.pressedRight && (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0))
    {
      selectionBox.setPosition(FlxG.mouse.screenX, FlxG.mouse.screenY);
      selectionStart.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
      selectionBox.visible = true;
      updateSelectionBox();
    }

    if (FlxG.mouse.justPressed
      && (FlxG.mouse.overlaps(mainBox.bg) || FlxG.mouse.overlaps(infoBox.bg) || FlxG.mouse.overlaps(eventBox.bg))) ignoreClickForThisFrame = true;

    var minX:Float = gridBg.x;
    if (SHOW_EVENT_COLUMN && lockedEvents) minX += GRID_SIZE;

    if (isMovingNotes && FlxG.mouse.justReleased) stopMovingNotes();

    if (FlxG.mouse.x >= minX && FlxG.mouse.x < gridBg.x + gridBg.width)
    {
      var diffX:Float = FlxG.mouse.x - gridBg.x;
      var diffY:Float = FlxG.mouse.y - gridBg.y;
      if (!FlxG.keys.pressed.SHIFT) diffY -= diffY % (GRID_SIZE / (curQuant / 16));

      if (nextGridBg.visible) diffY = Math.min(diffY, gridBg.height + nextGridBg.height);
      else
        diffY = Math.min(diffY, gridBg.height);

      if (prevGridBg.visible) diffY = Math.max(diffY, -prevGridBg.height);
      else
        diffY = Math.max(diffY, 0);

      var noteData:Int = Math.floor(diffX / GRID_SIZE);
      dummyArrow.visible = !selectionBox.visible;
      dummyArrow.x = gridBg.x + noteData * GRID_SIZE;
      if (SHOW_EVENT_COLUMN) noteData--;

      if (FlxG.keys.pressed.SHIFT || FlxG.mouse.y >= gridBg.y || !prevGridBg.visible) dummyArrow.y = gridBg.y + diffY;
      else
      {
        var t:Float = (diffY - (GRID_SIZE / (curQuant / 16)));
        if (FlxG.mouse.y >= gridBg.y) t *= curZoom;
        dummyArrow.y = gridBg.y + t;
      }

      if (isMovingNotes)
      {
        // Move note data
        var nData:Int = Std.int(Math.max(0, noteData));
        if (movingNotesLastData != nData)
        {
          var isFirst:Bool = true;
          var movingNotesMinData:Int = 0;
          var movingNotesMaxData:Int = 0;
          for (note in selectedNotes) // Find boundaries first
          {
            if (note == null || note.isEvent) continue;

            var data:Int = note.songData[1];
            if (isFirst || data < movingNotesMinData) movingNotesMinData = data;
            if (data > movingNotesMaxData) movingNotesMaxData = data;
            isFirst = false;
          }

          var diff:Int = nData - movingNotesLastData;
          var maxn:Int = (GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER) - 1;
          movingNotesMinData += diff;
          movingNotesMaxData += diff;
          if (movingNotesMinData < 0) diff -= movingNotesMinData;
          else if (movingNotesMaxData > maxn) diff -= movingNotesMaxData - maxn;

          for (note in movingNotes)
          {
            if (note == null || note.isEvent) continue; // Events shouldn't change note data as they don't have one

            note.changeNoteData(note.songData[1] + diff);
            positionNoteXByData(note);
          }
        }
        movingNotesLastData = nData;

        // Move note strum time
        if (dummyArrow.y != movingNotesLastY)
        {
          var diff:Float = dummyArrow.y - movingNotesLastY;
          var curSecRow:Int = 0;
          for (note in movingNotes) // Try to figure out new strum time for the notes, DEFINITELY INACCURATE WITH BPM CHANGING, ALTHOUGH UNTESTED
          {
            if (note == null) continue;

            note.chartY += diff;
            var row:Float = (note.chartY / GRID_SIZE) * curZoom;
            while (curSecRow + 1 < cachedSectionRow.length && cachedSectionRow[curSecRow] <= row)
            {
              curSecRow++;
            }

            note.setStrumTime(Math.max(-5000, note.strumTime + (diff * cachedSectionCrochets[curSecRow] / 4) / GRID_SIZE * curZoom));
            positionNoteYOnTime(note, curSecRow);
            if (note.isEvent) cast(note, EventMetaNote).updateEventText();
          }
          movingNotesLastY = dummyArrow.y;
        }
      }
      else if (FlxG.mouse.justPressed && !ignoreClickForThisFrame)
      {
        if (FlxG.keys.pressed.CONTROL && FlxG.mouse.justPressed)
        {
          if (selectedNotes.length > 0) moveSelectedNotes(noteData, dummyArrow.y);
          else
            showOutput('You must select notes to move them!', true);
        }
        else if (FlxG.mouse.x >= gridBg.x && FlxG.mouse.x < gridBg.x + gridBg.width)
        {
          var closeNotes:Array<MetaNote> = curRenderedNotes.members.filter(function(note:MetaNote) {
            var chartY:Float = FlxG.mouse.y - note.chartY;
            return ((note.isEvent && noteData < 0) || note.songData[1] == noteData) && chartY >= 0 && chartY < GRID_SIZE;
          });
          closeNotes.sort(function(a:MetaNote, b:MetaNote) return Math.abs(a.strumTime - FlxG.mouse.y) < Math.abs(b.strumTime - FlxG.mouse.y) ? 1 : -1);

          var closest = closeNotes[0];
          if (closest != null && (!closest.isEvent || !lockedEvents))
          {
            if (FlxG.keys.pressed.SHIFT || holdingAlt) // Select Note/Event
            {
              var sel = selectedNotes.copy();
              if (!selectedNotes.contains(closest))
              {
                selectedNotes.push(closest);
                addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
              }
              else if (!holdingAlt)
              {
                resetSelectedNotes();
                selectedNotes = sel.copy();
                selectedNotes.remove(closest);
                addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
              }

              trace('Notes selected: ' + selectedNotes.length);
            }
            else if (!FlxG.keys.pressed.CONTROL) // Remove Note/Event
            {
              trace('Removed ${!closest.isEvent ? 'note' : 'event'} at time: ${closest.strumTime}');
              if (!closest.isEvent) notes.remove(closest);
              else
                events.remove(cast(closest, EventMetaNote));

              selectedNotes.remove(closest);
              curRenderedNotes.remove(closest, true);
              addUndoAction(DELETE_NOTE, !closest.isEvent ?
                {notes: [closest]} :
                  {events: [closest]});
            }
            if (selectedNotes.length == 1) onSelectNote();
            forceDataUpdate = true;
          }
          else if (!holdingAlt && FlxG.mouse.y >= gridBg.y && FlxG.mouse.y < gridBg.y + gridBg.height) // Add note
          {
            var strumTime:Float = (diffY / GRID_SIZE * Conductor.stepCrochet / curZoom) + cachedSectionTimes[curSec];
            if (noteData >= 0)
            {
              trace('Added note at time: $strumTime');
              var didAdd:Bool = false;

              var noteSetupData:Array<Dynamic> = [strumTime, noteData, 0];
              var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex].trim();
              if (typeSelected != null && typeSelected.length > 0) noteSetupData.push(typeSelected);

              var noteAdded:MetaNote = createNote(noteSetupData);
              for (num in sectionFirstNoteID...notes.length)
              {
                var note = notes[num];
                if (note.strumTime >= strumTime)
                {
                  notes.insert(num, noteAdded);
                  didAdd = true;
                  break;
                }
              }
              if (!didAdd) notes.push(noteAdded);

              if (!holdingAlt) resetSelectedNotes();

              selectedNotes.push(noteAdded);
              addUndoAction(ADD_NOTE, {notes: [noteAdded]});
            }
            else if (!lockedEvents)
            {
              trace('Added event at time: $strumTime');
              var didAdd:Bool = false;

              var eventAdded:EventMetaNote = createEvent([
                strumTime,
                [
                  [
                    eventsList[Std.int(Math.max(eventDropDown.selectedIndex, 0))][0],
                    [
                      value1InputText.text, value2InputText.text, value3InputText.text, value4InputText.text, value5InputText.text, value6InputText.text,
                      value7InputText.text, value8InputText.text, value9InputText.text, value10InputText.text, value11InputText.text, value12InputText.text,
                      value13InputText.text, value14InputText.text
                    ]
                  ]
                ]
              ]);
              for (num in sectionFirstEventID...events.length)
              {
                var event = events[num];
                if (event.strumTime >= strumTime)
                {
                  events.insert(num, eventAdded);
                  didAdd = true;
                  break;
                }
              }
              if (!didAdd) events.push(eventAdded);

              if (!holdingAlt) resetSelectedNotes();

              selectedNotes.push(eventAdded);
              addUndoAction(ADD_NOTE, {events: [eventAdded]});
            }
            onSelectNote();
            softReloadNotes();
          }
        }
      }
    }
    else if (!ignoreClickForThisFrame)
    {
      if (FlxG.mouse.justPressed) resetSelectedNotes();

      dummyArrow.visible = false;
    }
    ignoreClickForThisFrame = false;

    if (Conductor.songPosition != lastTime || forceDataUpdate)
    {
      var curTime:String = FlxStringUtil.formatTime(Conductor.songPosition / 1000, true);
      var songLength:String = (FlxG.sound.music != null) ? FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true) : '???';
      var str:String = '$curTime / $songLength' + '\n\nSection: $curSec' + '\nBeat: $curBeat' + '\nStep: $curStep' + '\n\nBeat Snap: ${curQuant} / 16'
        + '\nSelected: ${selectedNotes.length}';

      if (str != infoText.text)
      {
        infoText.text = str;
        if (infoText.autoSize) infoText.autoSize = false;
      }

      var vortexPlaying:Bool = (vortexEnabled && FlxG.sound.music != null && FlxG.sound.music.playing);
      var canPlayHitSound:Bool = (FlxG.sound.music != null && FlxG.sound.music.playing && lastTime < Conductor.songPosition);
      var hitSoundPlayer:Bool = (hitsoundPlayerStepper.value > 0);
      var hitSoundOpp:Bool = (hitsoundOpponentStepper.value > 0);
      for (note in curRenderedNotes)
      {
        if (note == null || note.isEvent) continue;

        note.alpha = (note.strumTime >= Conductor.songPosition) ? 1 : 0.6;
        if (Conductor.songPosition > note.strumTime && lastTime <= note.strumTime)
        {
          if (canPlayHitSound)
          {
            if (hitSoundPlayer && note.mustPress)
            {
              FlxG.sound.play(Paths.sound('hitsound'), hitsoundPlayerStepper.value);
              hitSoundPlayer = false;
            }
            else if (hitSoundOpp && !note.mustPress)
            {
              FlxG.sound.play(Paths.sound('hitsound'), hitsoundOpponentStepper.value);
              hitSoundOpp = false;
            }
          }

          if (vortexPlaying)
          {
            var strumNote:StrumArrow = strumLineNotes.members[note.songData[1]];
            if (strumNote != null)
            {
              strumNote.playAnim('confirm', true);
              strumNote.resetAnim = Math.max(200, note.sustainLength) / 1000.0;
            }
          }
        }
      }
      forceDataUpdate = false;

      // moved from beatHit()
      if (metronomeStepper.value > 0 && lastBeatHit != curBeat) FlxG.sound.play(Paths.sound('Metronome_Tick'), metronomeStepper.value);

      lastBeatHit = curBeat;
    }

    if (selectedNotes.length > 0)
    {
      noteSelectionSine += elapsed;
      var sineValue:Float = 0.75 + Math.cos(Math.PI * noteSelectionSine * (isMovingNotes ? 8 : 2)) / 4;
      // trace(sineValue);

      var qPress = FlxG.keys.justPressed.Q;
      var ePress = FlxG.keys.justPressed.E;
      var addSus = (FlxG.keys.pressed.SHIFT ? 4 : 1) * (Conductor.stepCrochet / 2);
      if (qPress) addSus *= -1;

      if (qPress != ePress && selectedNotes.length != 1) susLengthStepper.value += addSus;

      for (note in selectedNotes)
      {
        if (note == null || !note.exists) continue;

        if (!note.isEvent)
        {
          if (qPress != ePress)
          {
            FlxG.sound.play(Paths.sound('chartingSounds/stretchSNAP_UI'), 0.7);
            note.setSustainLength(note.sustainLength + addSus, Conductor.stepCrochet, curZoom);
            if (selectedNotes.length == 1) susLengthStepper.value = note.sustainLength;
          }
          note.animation.update(elapsed); // let selected notes be animated for better visibility
        }
        note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = sineValue;
      }
    }
    else
      noteSelectionSine = 0;

    outputTxt.alpha = outputAlpha;
    outputTxt.visible = (outputAlpha > 0);
    camGame.scroll.y = scrollY;
    lastFocus = PsychUIInputText.focusOn;
  }

  function moveSelectedNotes(noteData:Int = 0, lastY:Float) // This turns selected notes into moving notes
  {
    var originalNotes:Array<MetaNote> = [];
    var originalEvents:Array<EventMetaNote> = [];
    var movedNotes:Array<MetaNote> = [];
    var movedEvents:Array<EventMetaNote> = [];
    for (note in selectedNotes)
    {
      if (note == null) continue;

      if (!note.isEvent)
      {
        notes.remove(note);
        var secNum:Int = 0;
        for (time in cachedSectionTimes)
        {
          if (time > note.strumTime) break;
          secNum++;
        }
        originalNotes.push(note);
        var mov:MetaNote = createNote(note.songData, secNum);
        movingNotes.add(mov);
        movedNotes.push(mov);
      }
      else
      {
        events.remove(cast(note, EventMetaNote));
        originalEvents.push(cast(note, EventMetaNote));
        var mov:EventMetaNote = createEvent(note.songData);
        movingNotes.add(mov);
        movedEvents.push(mov);
      }
    }
    selectedNotes = movingNotes.members.copy();
    isMovingNotes = true;
    movingNotesLastY = lastY;
    movingNotesLastData = noteData;
    movingNotes.sort(cast PlayState.sortByTime);
    addUndoAction(MOVE_NOTE,
      {
        originalNotes: originalNotes,
        originalEvents: originalEvents,
        movedNotes: movedNotes,
        movedEvents: movedEvents
      });
    softReloadNotes();
  }

  function stopMovingNotes() // This turns moving notes into saved notes
  {
    var pushedNotes:Array<MetaNote> = [];
    var pushedEvents:Array<EventMetaNote> = [];
    movingNotes.forEachAlive(function(note:MetaNote) {
      notes.push(note);
      if (!note.isEvent) pushedNotes.push(note);
      else
        pushedEvents.push(cast(note, EventMetaNote));
    });
    notes.sort(PlayState.sortByTime);
    movingNotes.clear();
    isMovingNotes = false;
    softReloadNotes();
  }

  function makeNoteDataCopy(originalData:Array<Dynamic>, isEvent:Bool)
  {
    var dataCopy:Array<Dynamic> = originalData.copy();
    if (isEvent)
    {
      var eventGrp:Array<Array<Dynamic>> = cast dataCopy[1].copy();
      for (num => subEvent in eventGrp)
        eventGrp[num] = subEvent.copy();

      dataCopy[1] = eventGrp;
    }
    return dataCopy;
  }

  function updateScrollY()
  {
    var secStartTime:Null<Float> = cast cachedSectionTimes[curSec];
    var secCrochet:Null<Float> = cast cachedSectionCrochets[curSec];
    var secRows:Null<Float> = cast cachedSectionRow[curSec];
    if (secStartTime == null || secCrochet == null || secRows == null) return;

    scrollY = (((Conductor.songPosition - secStartTime) / secCrochet * GRID_SIZE * 4) + (secRows * GRID_SIZE)) * curZoom - FlxG.height / 2;
  }

  function updateSelectionBox()
  {
    var diffX:Float = FlxG.mouse.screenX - selectionStart.x;
    var diffY:Float = FlxG.mouse.screenY - selectionStart.y;
    selectionBox.setPosition(selectionStart.x, selectionStart.y);

    if (diffX < 0) // Fixes negative X scale
    {
      diffX = Math.abs(diffX);
      selectionBox.x -= diffX;
    }
    if (diffY < 0) // Fixes negative Y scale
    {
      diffY = Math.abs(diffY);
      selectionBox.y -= diffY;
    }
    selectionBox.scale.set(diffX, diffY);
    selectionBox.updateHitbox();
  }

  function showOutput(message:String, isError:Bool = false)
  {
    trace(message);
    outputTxt.text = message;
    outputTxt.y = FlxG.height - outputTxt.height - 30;
    outputAlpha = 4;
    if (isError)
    {
      FlxG.sound.play(Paths.sound('cancelMenu'), 0.6);
      outputTxt.color = FlxColor.RED;
    }
    else
    {
      FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
      outputTxt.color = FlxColor.WHITE;
    }
  }

  function resetSelectedNotes()
  {
    for (note in selectedNotes)
    {
      if (note == null || !note.exists) continue;

      note.colorTransform.redMultiplier = note.colorTransform.greenMultiplier = note.colorTransform.blueMultiplier = 1;
      if (note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
    }
    selectedNotes = [];
    onSelectNote();
    forceDataUpdate = true;
  }

  function onSelectNote()
  {
    if (selectedNotes.length == 1) // Only one note selected
    {
      var note:MetaNote = selectedNotes[0];
      strumTimeStepper.value = note.strumTime;
      if (!note.isEvent) // Normal note
      {
        if (!note.isEvent)
        {
          susLengthLastVal = susLengthStepper.value = note.sustainLength;
          noteTypeDropDown.selectedIndex = Std.int(Math.max(0, noteTypes.indexOf(note.noteType)));
        }
        else
        {
          susLengthLastVal = susLengthStepper.value = 0;
          noteTypeDropDown.selectedLabel = '';
        }
      }
      else // Event note
      {
        var eventNote:EventMetaNote = cast(selectedNotes[0], EventMetaNote);
        updateSelectedEventText();
      }
    }
    else if (selectedNotes.length > 1)
    {
      susLengthStepper.min = -susLengthStepper.max;
      susLengthLastVal = susLengthStepper.value = 0;
      strumTimeStepper.value = selectedNotes[0].strumTime;
      noteTypeDropDown.selectedLabel = '';
      eventDropDown.selectedLabel = '';
      value1InputText.text = '';
      value2InputText.text = '';
      value3InputText.text = '';
      value4InputText.text = '';
      value5InputText.text = '';
      value6InputText.text = '';
      value7InputText.text = '';
      value8InputText.text = '';
      value9InputText.text = '';
      value10InputText.text = '';
      value11InputText.text = '';
      value12InputText.text = '';
      value13InputText.text = '';
      value14InputText.text = '';
    }
    forceDataUpdate = true;
  }

  function updateSelectedEventText()
  {
    if (selectedNotes.length == 1 && selectedNotes[0].isEvent)
    {
      var eventNote:EventMetaNote = cast(selectedNotes[0], EventMetaNote);
      curEventSelected = Std.int(FlxMath.bound(curEventSelected, 0, eventNote.events.length - 1));
      selectedEventText.text = 'Selected Event: ${curEventSelected + 1} / ${eventNote.events.length}';
      selectedEventText.visible = true;

      var myEvent = eventNote.events[curEventSelected];
      if (myEvent != null)
      {
        var eventName:String = (myEvent[0] != null) ? myEvent[0] : '';
        for (num => event in eventsList)
        {
          if (event[0] == eventName)
          {
            eventDropDown.selectedIndex = num;
            break;
          }
        }
        value1InputText.text = (myEvent[1][0] != null) ? myEvent[1][0] : '';
        value2InputText.text = (myEvent[1][1] != null) ? myEvent[1][1] : '';
        value3InputText.text = (myEvent[1][2] != null) ? myEvent[1][2] : '';
        value4InputText.text = (myEvent[1][3] != null) ? myEvent[1][3] : '';
        value5InputText.text = (myEvent[1][4] != null) ? myEvent[1][4] : '';
        value6InputText.text = (myEvent[1][5] != null) ? myEvent[1][5] : '';
        value7InputText.text = (myEvent[1][6] != null) ? myEvent[1][6] : '';
        value8InputText.text = (myEvent[1][7] != null) ? myEvent[1][7] : '';
        value9InputText.text = (myEvent[1][8] != null) ? myEvent[1][8] : '';
        value10InputText.text = (myEvent[1][9] != null) ? myEvent[1][9] : '';
        value11InputText.text = (myEvent[1][10] != null) ? myEvent[1][10] : '';
        value12InputText.text = (myEvent[1][11] != null) ? myEvent[1][11] : '';
        value13InputText.text = (myEvent[1][12] != null) ? myEvent[1][12] : '';
        value14InputText.text = (myEvent[1][13] != null) ? myEvent[1][13] : '';
      }
    }
    else
      selectedEventText.visible = false;
  }

  function createGrids()
  {
    var destroyed:Bool = false;
    var stripes:Array<Int> = null;
    if (prevGridBg != null)
    {
      stripes = prevGridBg.stripes;
      remove(prevGridBg);
      remove(gridBg);
      remove(nextGridBg);
      prevGridBg = FlxDestroyUtil.destroy(prevGridBg);
      gridBg = FlxDestroyUtil.destroy(gridBg);
      nextGridBg = FlxDestroyUtil.destroy(nextGridBg);
      destroyed = true;
    }

    var columnCount:Int = (GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS) + (SHOW_EVENT_COLUMN ? 1 : 0);
    gridBg = new ChartingGridSprite(columnCount, gridColors[0], gridColors[1]);
    gridBg.screenCenter(X);

    prevGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
    nextGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
    prevGridBg.x = nextGridBg.x = gridBg.x;
    prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = stripes;

    if (destroyed)
    {
      insert(getFirstNull(), prevGridBg);
      insert(getFirstNull(), nextGridBg);
      insert(getFirstNull(), gridBg);
      loadSection();
    }
    else
    {
      add(prevGridBg);
      add(nextGridBg);
      add(gridBg);
    }
  }

  var cachedSectionRow:Array<Int>;
  var cachedSectionTimes:Array<Float>;
  var cachedSectionCrochets:Array<Float>;
  var cachedSectionBPMs:Array<Float>;

  function loadChart(song:SwagSong)
  {
    PlayState.SONG = song;
    StageData.loadDirectory(PlayState.SONG);
    Conductor.bpm = PlayState.SONG.bpm;
  }

  function loadMusic(?killAudio:Bool = false)
  {
    setSongPlaying(false);
    var time:Float = Conductor.songPosition;

    if (killAudio)
    {
      var sndsToKill:Array<String> = [];
      for (key => snd in Paths.currentTrackedSounds)
      {
        // trace(key, snd);
        if (key.contains('/songs/${Paths.formatToSongPath(PlayState.SONG.songId)}/') && snd != null)
        {
          sndsToKill.push(key);
          snd.close();
        }
      }

      for (key in sndsToKill)
      {
        Assets.cache.clear(key);
        Paths.currentTrackedSounds.remove(key);
        Paths.localTrackedAssets.remove(key);
      }
    }

    try
    {
      FlxG.sound.playMusic(Paths.inst((PlayState.SONG.options.instrumentalPrefix != null ? PlayState.SONG.options.instrumentalPrefix : ''),
        PlayState.SONG.songId, (PlayState.SONG.options.instrumentalSuffix != null ? PlayState.SONG.options.instrumentalSuffix : '')),
        0);
      FlxG.sound.music.pause();
      FlxG.sound.music.time = time;
      FlxG.sound.music.onComplete = (function() songFinished = true);
    }
    catch (e:Exception)
    {
      Debug.logError('Error loading song: $e');
      return;
    }

    @:privateAccess vocals.cleanup(true);
    @:privateAccess opponentVocals.cleanup(true);
    if (PlayState.SONG.needsVoices)
    {
      try
      {
        final currentPrefix:String = (PlayState.SONG.options.vocalsPrefix != null ? PlayState.SONG.options.vocalsPrefix : '');
        final currentSuffix:String = (PlayState.SONG.options.vocalsSuffix != null ? PlayState.SONG.options.vocalsSuffix : '');
        final vocalPl:String = (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1;
        final normalVocals:Sound = Paths.voices(currentPrefix, PlayState.SONG.songId, currentSuffix);
        var playerVocals:Sound = SoundUtil.findVocal(
          {
            song: PlayState.SONG.songId,
            prefix: currentPrefix,
            suffix: currentSuffix,
            externVocal: vocalPl,
            character: characterData.vocalsP1,
            difficulty: Difficulty.getString()
          });
        vocals.loadEmbedded(playerVocals != null ? playerVocals : normalVocals);
        vocals.volume = 0;
        vocals.play();
        vocals.pause();
        vocals.time = time;

        final vocalOp:String = (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2;
        var oppVocals:Sound = SoundUtil.findVocal(
          {
            song: PlayState.SONG.songId,
            prefix: currentPrefix,
            suffix: currentSuffix,
            externVocal: vocalOp,
            character: characterData.vocalsP2,
            difficulty: Difficulty.getString()
          });
        if (oppVocals != null && oppVocals.length > 0)
        {
          opponentVocals.loadEmbedded(oppVocals);
          opponentVocals.volume = 0;
          opponentVocals.play();
          opponentVocals.pause();
          opponentVocals.time = time;
        }
      }
      catch (e:Dynamic) {}
    }

    updateAudioVolume();
    setPitch();
    _cacheSections();
  }

  function onSongComplete()
  {
    trace('song completed');
    setSongPlaying(false);
    Conductor.songPosition = FlxG.sound.music.time = vocals.time = opponentVocals.time = FlxG.sound.music.length - 1;
    curSec = PlayState.SONG.notes.length - 1;
    forceDataUpdate = true;
  }

  function updateAudioVolume()
  {
    FlxG.sound.music.volume = instVolumeStepper.value;
    vocals.volume = playerVolumeStepper.value;
    opponentVocals.volume = opponentVolumeStepper.value;
    if (instMuteCheckBox.checked) FlxG.sound.music.volume = 0;
    if (playerMuteCheckBox.checked) vocals.volume = 0;
    if (opponentMuteCheckBox.checked) opponentVocals.volume = 0;
  }

  var playbackRate:Float = 1;

  function setPitch(?value:Null<Float>)
  {
    #if FLX_PITCH
    if (value == null) value = playbackRate;
    FlxG.sound.music.pitch = value;
    vocals.pitch = value;
    opponentVocals.pitch = value;
    #end
  }

  function setSongPlaying(doPlay:Bool)
  {
    if (FlxG.sound.music == null) return;

    vocals.time = FlxG.sound.music.time;
    opponentVocals.time = FlxG.sound.music.time;

    if (doPlay)
    {
      FlxG.sound.music.play();
      vocals.play();
      opponentVocals.play();
    }
    else
    {
      FlxG.sound.music.pause();
      vocals.pause();
      opponentVocals.pause();
    }

    for (note in strumLineNotes)
    {
      note.alpha = doPlay ? 1 : 0.4;
      if (!doPlay)
      {
        note.playAnim('static');
        note.resetAnim = 0;
      }
    }
  }

  function reloadNotes()
  {
    selectedNotes = [];
    for (note in notes)
      if (note != null) note.destroy();
    for (event in events)
      if (event != null) event.destroy();
    notes = [];
    events = [];
    undoActions = [];

    for (secNum => section in PlayState.SONG.notes)
      for (note in section.sectionNotes)
        if (note != null) notes.push(createNote(note, secNum));

    for (eventNum => event in PlayState.SONG.events)
      if (event != null
        && (cachedSectionTimes.length < 1
          || event[0] < cachedSectionTimes[cachedSectionTimes.length - 1])) // dont spawn events over the time limit
        events.push(createEvent(event));

    notes.sort(PlayState.sortByTime);
    events.sort(PlayState.sortByTime);

    trace('Note count: ${notes.length}');
    trace('Events count: ${events.length}');

    loadSection();
  }

  function createNote(note:Dynamic, ?secNum:Null<Int> = null)
  {
    if (secNum == null) secNum = curSec;
    var section = PlayState.SONG.notes[secNum];

    var daStrumTime:Float = note[0];
    var daNoteData:Int = Std.int(note[1] % GRID_COLUMNS_PER_PLAYER);
    var gottaHitNote:Bool = (note[1] < GRID_COLUMNS_PER_PLAYER);

    var swagNote:MetaNote = new MetaNote(daStrumTime, daNoteData, note);
    swagNote.mustPress = gottaHitNote;
    swagNote.setSustainLength(note[2], cachedSectionCrochets[secNum] / 4, curZoom);
    swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
    swagNote.noteType = note[3];
    swagNote.scrollFactor.x = 0;
    var txt:FlxText = swagNote.findNoteTypeText(swagNote.noteType != null ? noteTypes.indexOf(swagNote.noteType) : 0);
    if (txt != null) txt.visible = showNoteTypeLabels;

    swagNote.updateHitbox();
    if (swagNote.width > swagNote.height) swagNote.setGraphicSize(GRID_SIZE);
    else
      swagNote.setGraphicSize(0, GRID_SIZE);

    swagNote.updateHitbox();
    swagNote.active = false;
    positionNoteXByData(swagNote);
    positionNoteYOnTime(swagNote, secNum);
    return swagNote;
  }

  function createEvent(event:Dynamic)
  {
    var daStrumTime:Float = event[0];
    var swagEvent:EventMetaNote = new EventMetaNote(daStrumTime, event);
    swagEvent.x = gridBg.x;
    swagEvent.eventText.x = swagEvent.x - swagEvent.eventText.width - 10;
    swagEvent.scrollFactor.x = 0;
    swagEvent.active = false;

    var secNum:Int = 0;
    for (i in 1...cachedSectionTimes.length)
    {
      if (cachedSectionTimes[i] > daStrumTime) break;
      secNum++;
    }
    positionNoteYOnTime(swagEvent, secNum);
    return swagEvent;
  }

  function _cacheSections()
  {
    var time:Float = 0;
    var row:Int = 0;
    cachedSectionRow = [];
    cachedSectionTimes = [];
    cachedSectionCrochets = [];
    cachedSectionBPMs = [];

    if (PlayState.SONG == null)
    {
      cachedSectionRow.push(0);
      cachedSectionTimes.push(0);
      cachedSectionCrochets.push(0);
      cachedSectionBPMs.push(0);
      return;
    }

    var bpm:Float = PlayState.SONG.bpm;
    var reachedLimit:Bool = false;
    for (secNum => section in PlayState.SONG.notes)
    {
      var secs:Null<Float> = cast section.sectionBeats;
      if (secs == null || Math.isNaN(secs) || secs <= 0) section.sectionBeats = 4;

      if (section.changeBPM) bpm = section.bpm;
      var beat:Float = Conductor.calculateCrochet(bpm);
      // trace(secBPM, beat);

      cachedSectionRow.push(row);
      cachedSectionTimes.push(time);
      cachedSectionCrochets.push(beat);
      cachedSectionBPMs.push(bpm);

      var lastTime:Float = time;
      var rowRound:Int = Math.round(4 * section.sectionBeats);
      row += rowRound;
      time += beat * (rowRound / 4);

      for (note in section.sectionNotes)
      {
        if (secNum > 0 && note[0] < lastTime) note[0] = lastTime;
        else if (secNum < PlayState.SONG.notes.length && note[0] >= time - 0.000001) note[0] = time - 0.000001;
      }

      if (FlxG.sound.music != null && time >= FlxG.sound.music.length)
      {
        var lastSectionNum:Int = PlayState.SONG.notes.length - 1;
        if (secNum < lastSectionNum) // Delete extra sections
        {
          while (PlayState.SONG.notes.length - 1 > secNum)
          {
            PlayState.SONG.notes.pop();
          }

          trace('breaking at section $secNum');
          reachedLimit = true;
          break;
        }
        else if (secNum == lastSectionNum)
        {
          trace('reached limit at section $secNum');
          reachedLimit = true;
        }
      }
    }

    if (FlxG.sound.music != null && !reachedLimit) // Created sections to fill blank space
    {
      var lastSection = PlayState.SONG.notes[PlayState.SONG.notes.length - 1];
      var beat:Float = Conductor.calculateCrochet(bpm);
      var sectionBeats:Float = lastSection != null ? lastSection.sectionBeats : 4;
      var rowRound:Int = Math.round(4 * sectionBeats);
      var timeAdd:Float = beat * (rowRound / 4);
      var mustHitSec:Bool = lastSection != null ? lastSection.mustHitSection : true;
      var changeBpmSec:Bool = lastSection != null ? lastSection.changeBPM : false;
      var altAnimSec:Bool = lastSection != null ? lastSection.altAnim : false;
      var cpuAltSec:Bool = lastSection != null ? lastSection.CPUAltAnim : false;
      var playerAltSec:Bool = lastSection != null ? lastSection.playerAltAnim : false;
      var player4Sec:Bool = lastSection != null ? lastSection.player4Section : false;
      var gfSec:Bool = lastSection != null ? lastSection.gfSection : false;
      var dType:Int = lastSection != null ? lastSection.dType : 0;

      while (!reachedLimit)
      {
        PlayState.SONG.notes.push(
          {
            sectionNotes: [],
            sectionBeats: sectionBeats,
            mustHitSection: mustHitSec,
            bpm: bpm,
            changeBPM: changeBpmSec,
            altAnim: altAnimSec,
            CPUAltAnim: cpuAltSec,
            playerAltAnim: playerAltSec,
            player4Section: player4Sec,
            gfSection: gfSec,
            dType: dType
          });

        cachedSectionRow.push(row);
        cachedSectionTimes.push(time);
        cachedSectionCrochets.push(beat);
        cachedSectionBPMs.push(bpm);

        row += rowRound;
        time += timeAdd;

        if (time >= FlxG.sound.music.length)
        {
          Debug.logInfo('created sections until ${PlayState.SONG.notes.length - 1}');
          reachedLimit = true;
        }
      }
    }
    cachedSectionRow.push(row);
    cachedSectionTimes.push(time);
  }

  var showPreviousSection:Bool = true;
  var showNextSection:Bool = true;
  var showNoteTypeLabels:Bool = true;
  var forceDataUpdate:Bool = true;

  function loadSection(?sec:Null<Int> = null)
  {
    if (sec != null) curSec = sec;
    curSec = Std.int(FlxMath.bound(curSec, 0, PlayState.SONG.notes.length - 1));
    Conductor.bpm = cachedSectionBPMs[curSec];

    var hei:Float = 0;
    if (curSec > 0)
    {
      prevGridBg.y = cachedSectionRow[curSec - 1] * GRID_SIZE * curZoom;
      prevGridBg.rows = Math.round(4 * PlayState.SONG.notes[curSec - 1].sectionBeats * curZoom);
      prevGridBg.visible = showPreviousSection;
      hei += prevGridBg.height;
      eventLockOverlay.y = prevGridBg.y;
    }
    else
      prevGridBg.visible = false;

    if (curSec < PlayState.SONG.notes.length - 1)
    {
      nextGridBg.y = cachedSectionRow[curSec + 1] * GRID_SIZE * curZoom;
      nextGridBg.rows = Math.round(4 * PlayState.SONG.notes[curSec + 1].sectionBeats * curZoom);
      nextGridBg.visible = showNextSection;
      hei += nextGridBg.height;
    }
    else
      nextGridBg.visible = false;

    gridBg.y = cachedSectionRow[curSec] * GRID_SIZE * curZoom;
    gridBg.rows = Math.round(4 * PlayState.SONG.notes[curSec].sectionBeats * curZoom);
    hei += gridBg.height;

    if (!prevGridBg.visible) eventLockOverlay.y = gridBg.y;
    eventLockOverlay.scale.y = hei;
    eventLockOverlay.updateHitbox();

    softReloadNotes();
    updateHeads();

    var sec = getCurChartSection();
    if (sec != null)
    {
      mustHitCheckBox.checked = sec.mustHitSection;
      gfSectionCheckBox.checked = sec.gfSection;
      player4SectionCheckBox.checked = sec.player4Section;
      altAnimSectionCheckBox.checked = sec.altAnim;
      playerAltAnimSectionCheckBox.checked = sec.playerAltAnim;
      cpuAltAnimSectionCheckBox.checked = sec.CPUAltAnim;
      changeBpmCheckBox.checked = sec.changeBPM;
      changeBpmStepper.value = Conductor.bpm;
      beatsPerSecStepper.value = sec.sectionBeats;
      // No Negative Numbers!
      dTypeSecStepper.value = Std.int(Math.abs(sec.dType));

      strumTimeStepper.step = Conductor.stepCrochet;
      susLengthStepper.step = cachedSectionCrochets[curSec] / 4 / 2;
      susLengthStepper.max = susLengthStepper.step * 128;
      if (selectedNotes.length > 1) susLengthStepper.min = -susLengthStepper.max;
      else
        susLengthStepper.min = 0;
    }
    prevGridBg.vortexLineEnabled = gridBg.vortexLineEnabled = nextGridBg.vortexLineEnabled = vortexEnabled;
    prevGridBg.vortexLineSpace = gridBg.vortexLineSpace = nextGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
    updateWaveform();
  }

  function softReloadNotes(onlyCurrent:Bool = false)
  {
    if (!onlyCurrent) behindRenderedNotes.clear();
    curRenderedNotes.clear();

    var minTime:Float = getMinNoteTime(curSec);
    var maxTime:Float = getMaxNoteTime(curSec);
    function curSecFilter(note:MetaNote)
    {
      return (note.strumTime >= minTime && note.strumTime < maxTime);
    }

    var firstNote:Bool = false;
    var firstEvent:Bool = false;
    sectionFirstNoteID = 0;
    sectionFirstEventID = 0;
    for (num => note in notes)
    {
      if (note != null && curSecFilter(note))
      {
        if (!firstNote) sectionFirstNoteID = num;
        curRenderedNotes.add(note);
        note.alpha = (note.strumTime >= Conductor.songPosition) ? 1 : 0.6;
        if (note.hasSustain) note.updateSustainToZoom(cachedSectionCrochets[curSec] / 4, curZoom);
      }
    }

    if (SHOW_EVENT_COLUMN)
    {
      for (num => event in events)
      {
        if (event != null && curSecFilter(event))
        {
          if (!firstEvent) sectionFirstEventID = num;
          curRenderedNotes.add(event);
          event.alpha = (event.strumTime >= Conductor.songPosition) ? 1 : 0.6;
          event.eventText.visible = true;
        }
      }
    }

    if (!onlyCurrent)
    {
      if (showPreviousSection || showNextSection)
      {
        var prevMinTime:Float = getMinNoteTime(curSec - 1);
        var prevMaxTime:Float = getMaxNoteTime(curSec - 1);
        var nextMinTime:Float = getMinNoteTime(curSec + 1);
        var nextMaxTime:Float = getMaxNoteTime(curSec + 1);
        function otherSecFilter(note:MetaNote)
        {
          return (prevGridBg.visible && (note.strumTime >= prevMinTime && note.strumTime < prevMaxTime))
            || (nextGridBg.visible && (note.strumTime >= nextMinTime && note.strumTime < nextMaxTime));
        }

        for (note in notes.filter(otherSecFilter))
        {
          behindRenderedNotes.add(note);
          note.alpha = 0.4;
          if (note.hasSustain) note.updateSustainToZoom(cachedSectionCrochets[curSec] / 4, curZoom);
        }

        if (SHOW_EVENT_COLUMN)
        {
          for (event in events.filter(otherSecFilter))
          {
            behindRenderedNotes.add(event);
            event.alpha = 0.4;
            event.eventText.visible = false;
          }
        }
      }
    }
  }

  function getMinNoteTime(sec:Int)
  {
    var minTime:Float = Math.NEGATIVE_INFINITY;
    if (sec > 0) minTime = cachedSectionTimes[sec];
    return minTime;
  }

  function getMaxNoteTime(sec:Int)
  {
    var maxTime:Float = Math.POSITIVE_INFINITY;
    if (sec < cachedSectionTimes.length) maxTime = cachedSectionTimes[sec + 1];
    return maxTime;
  }

  function positionNoteXByData(note:MetaNote, ?data:Null<Int> = null)
  {
    if (data == null) data = note.songData[1];

    var noteX:Float = gridBg.x + (GRID_SIZE - note.width) / 2;
    if (SHOW_EVENT_COLUMN) noteX += GRID_SIZE;

    noteX += GRID_SIZE * data;
    note.x = noteX;
    // trace(gridBg.x, noteX);
  }

  function positionNoteYOnTime(note:MetaNote, section:Int)
  {
    var time:Float = note.strumTime - cachedSectionTimes[section];
    var noteY:Float = (time / cachedSectionCrochets[section]) * GRID_SIZE * 4 * curZoom;
    noteY += cachedSectionRow[section] * GRID_SIZE * curZoom;
    noteY = Math.max(noteY, -150);
    note.y = noteY + (GRID_SIZE / 2 - note.height / 2) * curZoom;
    note.chartY = noteY;
    // trace(gridBg.y, noteY);
  }

  var characterData:Dynamic = {};

  function updateJsonData():Void
  {
    for (i in 1...GRID_PLAYERS + 1)
    {
      // trace('adding iconP$i');
      var characters:Array<String> = ['player', 'opponent', 'girlfriend', 'secondOpponent'];
      var data:CharacterFile = loadCharacterFile(Reflect.field(PlayState.SONG.characters, characters[i - 1]));
      Reflect.setField(characterData, 'iconP$i', data != null && data.healthicon != null ? data.healthicon : 'face');
      Reflect.setField(characterData, 'vocalsP$i', data != null && data.vocals_file != null ? data.vocals_file : '');
    }
  }

  var _lastSec:Int = -1;
  var _lastGfSection:Null<Bool> = null;

  function updateHeads(ignoreCheck:Bool = false):Void
  {
    var curSecData:SwagSection = PlayState.SONG.notes[curSec];
    var isGfSection:Bool = (curSecData != null && curSecData.gfSection == true);
    if (_lastGfSection == isGfSection && _lastSec == curSec && !ignoreCheck) return; // optimization

    for (i in 0...GRID_PLAYERS)
    {
      var icon:HealthIcon = icons[i];
      // trace('changing iconP${icon.ID}');
      var iconName:String = Reflect.field(characterData, 'iconP${icon.ID}');
      icon.changeIcon(iconName);
    }

    if (icons.length > 1)
    {
      var iconP1:HealthIcon = icons[0];
      var iconP2:HealthIcon = icons[1];
      var mustHitSection:Bool = (curSecData != null && curSecData.mustHitSection == true);
      if (isGfSection)
      {
        if (mustHitSection) iconP1.changeIcon('gf');
        else
          iconP2.changeIcon('gf');
      }

      if (mustHitSection) mustHitIndicator.x = iconP1.x + iconP1.width / 2;
      else
        mustHitIndicator.x = iconP2.x + iconP2.width / 2;
    }
    _lastGfSection = isGfSection;
    _lastSec = curSec;
  }

  var playbackSlider:PsychUISlider;

  var mouseSnapCheckBox:PsychUICheckBox;
  var ignoreProgressCheckBox:PsychUICheckBox;
  var hitsoundPlayerStepper:PsychUINumericStepper;
  var hitsoundOpponentStepper:PsychUINumericStepper;
  var metronomeStepper:PsychUINumericStepper;

  var instVolumeStepper:PsychUINumericStepper;
  var instMuteCheckBox:PsychUICheckBox;
  var playerVolumeStepper:PsychUINumericStepper;
  var playerMuteCheckBox:PsychUICheckBox;
  var opponentVolumeStepper:PsychUINumericStepper;
  var opponentMuteCheckBox:PsychUICheckBox;

  function addChartingTab()
  {
    var tab_group = mainBox.getTab('Charting').menu;
    var objX = 10;
    var objY = 10;

    var txt = new FlxText(objX, objY, 280, "Any options here won't actually affect gameplay!");
    txt.alignment = CENTER;
    tab_group.add(txt);

    objY += 25;
    playbackSlider = new PsychUISlider(50, objY, function(v:Float) setPitch(playbackRate = v), 1, 0.5, 3, 200);
    playbackSlider.label = 'Playback Rate';

    objY += 60;
    mouseSnapCheckBox = new PsychUICheckBox(objX, objY, 'Mouse Scroll Snap', 100, function() chartEditorSave.data.mouseScrollSnap = mouseSnapCheckBox.checked);
    mouseSnapCheckBox.checked = chartEditorSave.data.mouseScrollSnap;

    ignoreProgressCheckBox = new PsychUICheckBox(objX + 150, objY, 'Ignore Progress Warnings', 100,
      function() chartEditorSave.data.ignoreProgressWarns = ignoreProgressCheckBox.checked);
    ignoreProgressCheckBox.checked = chartEditorSave.data.ignoreProgressWarns;

    objY += 50;
    hitsoundPlayerStepper = new PsychUINumericStepper(objX, objY, 0.2, 0, 0, 1, 1);
    hitsoundOpponentStepper = new PsychUINumericStepper(objX + 100, objY, 0.2, 0, 0, 1, 1);
    metronomeStepper = new PsychUINumericStepper(objX + 200, objY, 0.2, 0, 0, 1, 1);

    objY += 50;
    instVolumeStepper = new PsychUINumericStepper(objX, objY, 0.1, 0.6, 0, 1, 1);
    instVolumeStepper.onValueChange = updateAudioVolume;
    playerVolumeStepper = new PsychUINumericStepper(objX + 100, objY, 0.1, 1, 0, 1, 1);
    playerVolumeStepper.onValueChange = updateAudioVolume;
    opponentVolumeStepper = new PsychUINumericStepper(objX + 200, objY, 0.1, 1, 0, 1, 1);
    opponentVolumeStepper.onValueChange = updateAudioVolume;

    objY += 25;
    instMuteCheckBox = new PsychUICheckBox(objX, objY, 'Mute', 60, updateAudioVolume);
    playerMuteCheckBox = new PsychUICheckBox(objX + 100, objY, 'Mute', 60, updateAudioVolume);
    opponentMuteCheckBox = new PsychUICheckBox(objX + 200, objY, 'Mute', 60, updateAudioVolume);

    tab_group.add(playbackSlider);
    tab_group.add(mouseSnapCheckBox);
    tab_group.add(ignoreProgressCheckBox);

    tab_group.add(new FlxText(hitsoundPlayerStepper.x, hitsoundPlayerStepper.y - 15, 100, 'Hitsound (Player):'));
    tab_group.add(new FlxText(hitsoundOpponentStepper.x, hitsoundOpponentStepper.y - 15, 100, 'Hitsound (Opp.):'));
    tab_group.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 100, 'Metronome:'));
    tab_group.add(hitsoundPlayerStepper);
    tab_group.add(hitsoundOpponentStepper);
    tab_group.add(metronomeStepper);

    tab_group.add(new FlxText(instVolumeStepper.x, instVolumeStepper.y - 15, 100, 'Inst. Volume:'));
    tab_group.add(new FlxText(playerVolumeStepper.x, playerVolumeStepper.y - 15, 100, 'Main Vocals:'));
    tab_group.add(new FlxText(opponentVolumeStepper.x, opponentVolumeStepper.y - 15, 100, 'Opp. Vocals:'));
    tab_group.add(instVolumeStepper);
    tab_group.add(instMuteCheckBox);
    tab_group.add(playerVolumeStepper);
    tab_group.add(playerMuteCheckBox);
    tab_group.add(opponentVolumeStepper);
    tab_group.add(opponentMuteCheckBox);
  }

  var gameOverCharDropDown:PsychUIDropDownMenu;
  var gameOverSndInputText:PsychUIInputText;
  var gameOverLoopInputText:PsychUIInputText;
  var gameOverRetryInputText:PsychUIInputText;

  var holdCoverSkinInputText:PsychUIInputText;
  var strumTextureInputText:PsychUIInputText;
  var noteTextureInputText:PsychUIInputText;
  var noteSplashesInputText:PsychUIInputText;

  function addDataTab()
  {
    var tab_group = mainBox.getTab('Data').menu;
    var objX = 10;
    var objY = 25;
    gameOverCharDropDown = new PsychUIDropDownMenu(objX, objY, [''], function(id:Int, character:String) {
      PlayState.SONG.gameOverData.gameOverChar = character;
      if (character.length < 1) Reflect.deleteField(PlayState.SONG.gameOverData, 'gameOverChar');
      trace('selected $character');
    });

    objY += 40;
    gameOverSndInputText = new PsychUIInputText(objX, objY, 120, '', 8);
    gameOverSndInputText.onChange = function(old:String, cur:String) {
      PlayState.SONG.gameOverData.gameOverSound = cur;
      if (cur.trim().length < 1) Reflect.deleteField(PlayState.SONG.gameOverData, 'gameOverSound');
    }
    objY += 40;
    gameOverLoopInputText = new PsychUIInputText(objX, objY, 120, '', 8);
    gameOverLoopInputText.onChange = function(old:String, cur:String) {
      PlayState.SONG.gameOverData.gameOverLoop = cur;
      if (cur.trim().length < 1) Reflect.deleteField(PlayState.SONG.gameOverData, 'gameOverLoop');
    }
    objY += 40;
    gameOverRetryInputText = new PsychUIInputText(objX, objY, 120, '', 8);
    gameOverRetryInputText.onChange = function(old:String, cur:String) {
      PlayState.SONG.gameOverData.gameOverEnd = cur;
      if (cur.trim().length < 1) Reflect.deleteField(PlayState.SONG.gameOverData, 'gameOverEnd');
    }

    objY += 40;
    noteTextureInputText = new PsychUIInputText(objX, objY, 120, '');
    noteTextureInputText.unfocus = function() {
      var changed:Bool = false;
      if (PlayState.SONG.options.arrowSkin != noteTextureInputText.text) changed = true;
      PlayState.SONG.options.arrowSkin = noteTextureInputText.text.trim();
      if (PlayState.SONG.options.arrowSkin.trim().length < 1) PlayState.SONG.options.arrowSkin = null;

      if (changed)
      {
        var textureLoad:String = !noteTextureInputText.text.contains('images') ? 'images/${noteTextureInputText.text}.png' : '${noteTextureInputText.text}.png';
        if (Paths.fileExists(textureLoad, IMAGE) || noteTextureInputText.text.trim() == '')
        {
          for (note in notes)
          {
            if (note == null) continue;
            note.reloadToNewTexture(note.texture);
          }
          if (noteTextureInputText.text.trim().length > 0) showOutput('Reloaded notes to: "$textureLoad"');
          else
            showOutput('Reloaded notes to default texture');
        }
        else
          showOutput('ERROR: "$textureLoad" not found.', true);
      }
    };

    noteSplashesInputText = new PsychUIInputText(objX + 140, objY, 120, '');
    noteSplashesInputText.onChange = function(old:String, cur:String) {
      PlayState.SONG.options.splashSkin = cur;
      if (cur.trim().length < 1) PlayState.SONG.options.splashSkin = null;
    }

    holdCoverSkinInputText = new PsychUIInputText(objX, objY + 40, 120, '', 8);
    holdCoverSkinInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.holdCoverSkin = cur;

    strumTextureInputText = new PsychUIInputText(holdCoverSkinInputText.x + 140, holdCoverSkinInputText.y, 120, '');
    strumTextureInputText.unfocus = function() {
      var changed:Bool = false;
      if (PlayState.SONG.options.strumSkin != strumTextureInputText.text) changed = true;
      PlayState.SONG.options.strumSkin = strumTextureInputText.text.trim();
      if (PlayState.SONG.options.strumSkin.trim().length < 1) PlayState.SONG.options.strumSkin = null;

      if (changed)
      {
        var textureLoad:String = !strumTextureInputText.text.contains('images') ? 'images/${strumTextureInputText.text}.png' : '${strumTextureInputText.text}.png';
        if (Paths.fileExists(textureLoad, IMAGE) || strumTextureInputText.text.trim() == '')
        {
          for (note in strumLineNotes)
          {
            if (note == null) continue;
            note.reloadNote(note.texture);
            if (note.width > note.height) note.setGraphicSize(GRID_SIZE);
            else
              note.setGraphicSize(0, GRID_SIZE);

            note.updateHitbox();
            // note.x += GRID_SIZE / 2 - note.width / 2;
            // note.y += GRID_SIZE / 2 - note.height / 2;
          }
          if (strumTextureInputText.text.trim().length > 0) showOutput('Reloaded strums to: "$textureLoad"');
          else
            showOutput('Reloaded strums to default texture');
        }
        else
          showOutput('ERROR: "$textureLoad" not found.', true);
      }
    };

    tab_group.add(new FlxText(gameOverCharDropDown.x, gameOverCharDropDown.y - 15, 120, 'Game Over Character:'));
    tab_group.add(new FlxText(gameOverSndInputText.x, gameOverSndInputText.y - 15, 180, 'Game Over Death Sound (sounds/):'));
    tab_group.add(new FlxText(gameOverLoopInputText.x, gameOverLoopInputText.y - 15, 180, 'Game Over Loop Music (music/):'));
    tab_group.add(new FlxText(gameOverRetryInputText.x, gameOverRetryInputText.y - 15, 180, 'Game Over Retry Music (music/):'));
    tab_group.add(gameOverSndInputText);
    tab_group.add(gameOverLoopInputText);
    tab_group.add(gameOverRetryInputText);

    tab_group.add(new FlxText(noteTextureInputText.x, noteTextureInputText.y - 15, 100, 'Note Texture:'));
    tab_group.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 120, 'Note Splashes Texture:'));
    tab_group.add(new FlxText(holdCoverSkinInputText.x, holdCoverSkinInputText.y - 15, 125, 'Hold Covers Texture:'));
    tab_group.add(new FlxText(strumTextureInputText.x, strumTextureInputText.y - 15, 125, 'Strum Note Texture:'));
    tab_group.add(noteTextureInputText);
    tab_group.add(noteSplashesInputText);
    tab_group.add(holdCoverSkinInputText);
    tab_group.add(strumTextureInputText);

    tab_group.add(gameOverCharDropDown); // lowest priority to display properly
  }

  var eventDropDown:PsychUIDropDownMenu;
  var value1InputText:PsychUIInputText;
  var value2InputText:PsychUIInputText;
  var value3InputText:PsychUIInputText;
  var value4InputText:PsychUIInputText;
  var value5InputText:PsychUIInputText;
  var value6InputText:PsychUIInputText;
  var value7InputText:PsychUIInputText;
  var value8InputText:PsychUIInputText;
  var value9InputText:PsychUIInputText;
  var value10InputText:PsychUIInputText;
  var value11InputText:PsychUIInputText;
  var value12InputText:PsychUIInputText;
  var value13InputText:PsychUIInputText;
  var value14InputText:PsychUIInputText;
  var selectedEventText:FlxText;
  var eventDescriptionText:FlxText;

  var eventsList:Array<Array<String>>;
  var curEventSelected:Int = 0;

  function addEventsTab()
  {
    var tab_group = eventBox.getTab('Events').menu;
    var objX = 10;
    var objY = 25;

    eventDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, character:String) {
      var eventSelected:Array<String> = eventsList[id];
      var eventName:String = eventSelected[0];
      var description:String = eventSelected[1];
      eventDescriptionText.text = description;
      if (selectedNotes.length > 1)
      {
        for (note in selectedNotes)
        {
          if (note == null || !note.isEvent) continue;

          var event:EventMetaNote = cast(note, EventMetaNote);
          event.events[event.events.length - 1][0] = eventName;
          event.updateEventText();
        }
      }
      else if (selectedNotes.length == 1 && selectedNotes[0].isEvent)
      {
        var event:EventMetaNote = cast(selectedNotes[0], EventMetaNote);
        event.events[Std.int(FlxMath.bound(curEventSelected, 0, event.events.length - 1))][0] = eventName;
        event.updateEventText();
      }
    });

    function genericEventButton(func:EventMetaNote->Void)
    {
      if (selectedNotes.length == 1)
      {
        if (selectedNotes[0].isEvent)
        {
          var event:EventMetaNote = cast(selectedNotes[0], EventMetaNote);
          func(event);
          updateSelectedEventText();
        }
        else
          showOutput('Note selected must be an Event!', true);
      }
      else
        showOutput('You must select a single event to press this button.', true);
    }

    var objX2 = 140;
    var removeButton:PsychUIButton = new PsychUIButton(objX2, objY, '-', function() {
      genericEventButton(function(event:EventMetaNote) {
        if (event.events.length > 1)
        {
          var selectedEvent = event.events[curEventSelected];
          if (selectedEvent != null)
          {
            event.events.remove(selectedEvent);
            event.updateEventText();
            curEventSelected--;
          }
          else
            showOutput('No event is selected when you deleted it?? Weird.', true);
        }
        else
        {
          selectedNotes.remove(event);
          events.remove(event);
          curRenderedNotes.remove(event, true);
          addUndoAction(DELETE_NOTE, {events: [event]});
        }
      });
    }, 20);
    var addButton:PsychUIButton = new PsychUIButton(objX2 + 30, objY, '+', function() {
      genericEventButton(function(event:EventMetaNote) {
        event.events.push([
          eventsList[Std.int(Math.max(eventDropDown.selectedIndex, 0))][0],
          [
            value1InputText.text, value2InputText.text, value3InputText.text, value4InputText.text, value5InputText.text, value6InputText.text,
            value7InputText.text, value8InputText.text, value9InputText.text, value10InputText.text, value11InputText.text, value12InputText.text,
            value13InputText.text, value14InputText.text
          ]
        ]);
        event.updateEventText();
        curEventSelected++;
      });
    }, 20);
    var leftButton:PsychUIButton = new PsychUIButton(objX2 + 80, objY, '<', function() {
      genericEventButton(function(event:EventMetaNote) curEventSelected = FlxMath.wrap(curEventSelected - 1, 0, event.events.length - 1));
    }, 20);
    var rightButton:PsychUIButton = new PsychUIButton(objX2 + 110, objY, '>', function() {
      genericEventButton(function(event:EventMetaNote) curEventSelected = FlxMath.wrap(curEventSelected + 1, 0, event.events.length - 1));
    }, 20);
    removeButton.normalStyle.bgColor = FlxColor.RED;
    removeButton.normalStyle.textColor = FlxColor.WHITE;
    addButton.normalStyle.bgColor = FlxColor.GREEN;
    addButton.normalStyle.textColor = FlxColor.WHITE;

    selectedEventText = new FlxText(150, objY + 30, 150, '');
    selectedEventText.visible = false;

    function changeEventsValue(str:String, n:Int)
    {
      if (selectedNotes.length > 1)
      {
        for (note in selectedNotes)
        {
          if (note == null || !note.isEvent) continue;

          var event:EventMetaNote = cast(note, EventMetaNote);
          event.events[event.events.length - 1][1][n] = str;
          event.updateEventText();
        }
      }
      else if (selectedNotes.length == 1 && selectedNotes[0].isEvent)
      {
        var event:EventMetaNote = cast(selectedNotes[0], EventMetaNote);
        event.events[Std.int(FlxMath.bound(curEventSelected, 0, event.events.length - 1))][1][n] = str;
        event.updateEventText();
      }
    }

    objY += 70;
    value1InputText = new PsychUIInputText(objX, objY, 120, '', 8);
    value1InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 0);
    value2InputText = new PsychUIInputText(objX + 150, objY, 120, '', 8);
    value2InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 1);
    value3InputText = new PsychUIInputText(objX, objY + 30, 120, '', 8);
    value3InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 2);
    value4InputText = new PsychUIInputText(objX + 150, objY + 30, 120, '', 8);
    value4InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 3);
    value5InputText = new PsychUIInputText(objX, objY + 60, 120, '', 8);
    value5InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 4);
    value6InputText = new PsychUIInputText(objX + 150, objY + 60, 120, '', 8);
    value6InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 5);
    value7InputText = new PsychUIInputText(objX, objY + 90, 120, '', 8);
    value7InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 6);
    value8InputText = new PsychUIInputText(objX + 150, objY + 90, 120, '', 8);
    value8InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 7);
    value9InputText = new PsychUIInputText(objX, objY + 120, 120, '', 8);
    value9InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 8);
    value10InputText = new PsychUIInputText(objX + 150, objY + 120, 120, '', 8);
    value10InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 9);
    value11InputText = new PsychUIInputText(objX, objY + 150, 120, '', 8);
    value11InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 10);
    value12InputText = new PsychUIInputText(objX + 150, objY + 150, 120, '', 8);
    value12InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 11);
    value13InputText = new PsychUIInputText(objX, objY + 180, 120, '', 8);
    value13InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 12);
    value14InputText = new PsychUIInputText(objX + 150, objY + 180, 120, '', 8);
    value14InputText.onChange = function(old:String, cur:String) changeEventsValue(cur, 13);

    objY += 140;
    eventDescriptionText = new FlxText(objX, objY + 60, 280, defaultEvents[0][1]);

    tab_group.add(new FlxText(eventDropDown.x, eventDropDown.y - 15, 80, 'Event:'));
    tab_group.add(new FlxText(value1InputText.x, value1InputText.y - 15, 80, 'Value 1:'));
    tab_group.add(new FlxText(value2InputText.x, value2InputText.y - 15, 80, 'Value 2:'));
    tab_group.add(new FlxText(value3InputText.x, value3InputText.y - 15, 80, 'Value 3:'));
    tab_group.add(new FlxText(value4InputText.x, value4InputText.y - 15, 80, 'Value 4:'));
    tab_group.add(new FlxText(value5InputText.x, value5InputText.y - 15, 80, 'Value 5:'));
    tab_group.add(new FlxText(value6InputText.x, value6InputText.y - 15, 80, 'Value 6:'));
    tab_group.add(new FlxText(value7InputText.x, value7InputText.y - 15, 80, 'Value 7:'));
    tab_group.add(new FlxText(value8InputText.x, value8InputText.y - 15, 80, 'Value 8:'));
    tab_group.add(new FlxText(value9InputText.x, value9InputText.y - 15, 80, 'Value 9:'));
    tab_group.add(new FlxText(value10InputText.x, value10InputText.y - 15, 80, 'Value 10:'));
    tab_group.add(new FlxText(value11InputText.x, value11InputText.y - 15, 80, 'Value 11:'));
    tab_group.add(new FlxText(value12InputText.x, value12InputText.y - 15, 80, 'Value 12:'));
    tab_group.add(new FlxText(value13InputText.x, value13InputText.y - 15, 80, 'Value 13:'));
    tab_group.add(new FlxText(value14InputText.x, value14InputText.y - 15, 80, 'Value 14:'));

    tab_group.add(removeButton);
    tab_group.add(addButton);
    tab_group.add(leftButton);
    tab_group.add(rightButton);
    tab_group.add(selectedEventText);

    tab_group.add(value1InputText);
    tab_group.add(value2InputText);
    tab_group.add(value3InputText);
    tab_group.add(value4InputText);
    tab_group.add(value5InputText);
    tab_group.add(value6InputText);
    tab_group.add(value7InputText);
    tab_group.add(value8InputText);
    tab_group.add(value9InputText);
    tab_group.add(value10InputText);
    tab_group.add(value11InputText);
    tab_group.add(value12InputText);
    tab_group.add(value13InputText);
    tab_group.add(value14InputText);
    tab_group.add(eventDescriptionText);

    tab_group.add(eventDropDown); // lowest priority to display properly
  }

  var susLengthLastVal:Float = 0; // used for multiple notes selected
  var susLengthStepper:PsychUINumericStepper;
  var strumTimeStepper:PsychUINumericStepper;
  var noteTypeDropDown:PsychUIDropDownMenu;
  var noteTypes:Array<String>;

  var noRGBCheckBox:PsychUICheckBox;
  var noRGBQuantCheckBox:PsychUICheckBox;
  var noStrumRGBCheckBox:PsychUICheckBox;
  var noSplashRGBCheckBox:PsychUICheckBox;
  var noHoldCoverRGBCheckBox:PsychUICheckBox;

  var opponentNoteStyleInputText:PsychUIInputText;
  var playerNoteStyleInputText:PsychUIInputText;

  var opponentStrumStyleInputText:PsychUIInputText;
  var playerStrumStyleInputText:PsychUIInputText;

  function addNoteTab()
  {
    var tab_group = mainBox.getTab('Note').menu;
    var objX = 10;
    var objY = 25;

    susLengthStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 128, 1, 80);
    susLengthStepper.onValueChange = function() {
      var halfStep:Float = (Conductor.stepCrochet / 2);
      trace(halfStep, susLengthStepper.value);
      var val:Float = Math.round(susLengthStepper.value / halfStep) * halfStep;
      susLengthStepper.value = val;
      if (susLengthLastVal != susLengthStepper.value)
      {
        if (selectedNotes.length > 1)
        {
          for (note in selectedNotes)
          {
            if (note == null && !note.isEvent) continue;
            note.setSustainLength(note.sustainLength + (susLengthStepper.value - susLengthLastVal), Conductor.stepCrochet, curZoom);
          }
        }
        else if (selectedNotes.length == 1) selectedNotes[0].setSustainLength(susLengthStepper.value, Conductor.stepCrochet, curZoom);
        susLengthLastVal = susLengthStepper.value;
      }
    };

    objY += 40;
    strumTimeStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet, 0, -5000, Math.POSITIVE_INFINITY, 3, 120);
    strumTimeStepper.onValueChange = function() {
      if (selectedNotes.length < 1) return;

      var firstTime:Float = selectedNotes[0].strumTime;
      for (note in selectedNotes)
      {
        if (note == null) continue;

        note.strumTime = Math.max(-5000, strumTimeStepper.value + (note.strumTime - firstTime));
        positionNoteYOnTime(note, curSec);
      }
      softReloadNotes();
    };

    objY += 40;
    noteTypeDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, changeToType:String) {
      var newSelected:Array<MetaNote> = [];
      var typeSelected:String = noteTypes[id].trim();
      for (note in selectedNotes)
      {
        if (note == null || note.isEvent) continue;

        if (typeSelected != null && typeSelected.length > 0) note.songData[3] = typeSelected;
        else
          note.songData.remove(note.songData[3]);

        var id:Int = notes.indexOf(note);
        if (id > -1)
        {
          notes[id] = createNote(note.songData, curSec);
          actionReplaceNotes(note, notes[id]);
          newSelected.push(notes[id]);
          note.destroy();
        }
      }
      selectedNotes = newSelected;
      softReloadNotes();
    }, 150);

    noRGBCheckBox = new PsychUICheckBox(objX + 190, objY - 85, 'Disable Note RGB', 80, updateNotesRGB);
    noRGBQuantCheckBox = new PsychUICheckBox(noRGBCheckBox.x, noRGBCheckBox.y + 25, 'Disable Note Quant RGB', 80,
      function() PlayState.SONG.options.disableNoteQuantRGB = noRGBQuantCheckBox.checked);
    noStrumRGBCheckBox = new PsychUICheckBox(noRGBCheckBox.x, noRGBCheckBox.y + 45, 'Disable Strum RGB', 80, updateStrumsRGB);
    noSplashRGBCheckBox = new PsychUICheckBox(noRGBCheckBox.x, noRGBCheckBox.y + 65, 'Disable Splash RGB', 80, updateSplashesRGB);
    noHoldCoverRGBCheckBox = new PsychUICheckBox(noRGBCheckBox.x, noRGBCheckBox.y + 85, 'Disable Hold Covers RGB', 80,
      function() PlayState.SONG.options.disableHoldCoversRGB = noHoldCoverRGBCheckBox.checked);

    objY += 60;
    opponentNoteStyleInputText = new PsychUIInputText(objX, objY, 100, '', 8);
    opponentNoteStyleInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.opponentNoteStyle = cur;

    playerNoteStyleInputText = new PsychUIInputText(objX + 150, objY, 100, '', 8);
    playerNoteStyleInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.playerNoteStyle = cur;

    objY += 40;
    opponentStrumStyleInputText = new PsychUIInputText(objX, objY, 100, '', 8);
    opponentStrumStyleInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.opponentStrumStyle = cur;

    playerStrumStyleInputText = new PsychUIInputText(objX + 150, objY, 100, '', 8);
    playerStrumStyleInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.playerStrumStyle = cur;

    tab_group.add(new FlxText(opponentNoteStyleInputText.x, opponentNoteStyleInputText.y - 15, 120, 'Opponent Note Style:'));
    tab_group.add(new FlxText(playerNoteStyleInputText.x, playerNoteStyleInputText.y - 15, 100, 'Player Note Style:'));

    tab_group.add(new FlxText(opponentStrumStyleInputText.x, opponentStrumStyleInputText.y - 15, 120, 'Opponent Strum Style:'));
    tab_group.add(new FlxText(playerStrumStyleInputText.x, playerStrumStyleInputText.y - 15, 100, 'Player Strum Style:'));

    tab_group.add(opponentNoteStyleInputText);
    tab_group.add(playerNoteStyleInputText);
    tab_group.add(opponentStrumStyleInputText);
    tab_group.add(playerStrumStyleInputText);

    tab_group.add(new FlxText(susLengthStepper.x, susLengthStepper.y - 15, 80, 'Sustain length:'));
    tab_group.add(new FlxText(strumTimeStepper.x, strumTimeStepper.y - 15, 100, 'Note Hit time (ms):'));
    tab_group.add(new FlxText(noteTypeDropDown.x, noteTypeDropDown.y - 15, 80, 'Note Type:'));
    tab_group.add(susLengthStepper);
    tab_group.add(strumTimeStepper);
    tab_group.add(noteTypeDropDown);

    tab_group.add(noRGBCheckBox);
    tab_group.add(noRGBQuantCheckBox);
    tab_group.add(noStrumRGBCheckBox);
    tab_group.add(noSplashRGBCheckBox);
    tab_group.add(noHoldCoverRGBCheckBox);
  }

  var mustHitCheckBox:PsychUICheckBox;
  var gfSectionCheckBox:PsychUICheckBox;
  var altAnimSectionCheckBox:PsychUICheckBox;
  var player4SectionCheckBox:PsychUICheckBox;
  var playerAltAnimSectionCheckBox:PsychUICheckBox;
  var cpuAltAnimSectionCheckBox:PsychUICheckBox;

  var changeBpmCheckBox:PsychUICheckBox;
  var changeBpmStepper:PsychUINumericStepper;
  var beatsPerSecStepper:PsychUINumericStepper;
  var dTypeSecStepper:PsychUINumericStepper;

  function addSectionTab()
  {
    var affectNotes:PsychUICheckBox = null;
    var affectEvents:PsychUICheckBox = null;
    var copyLastSecStepper:PsychUINumericStepper = null;
    var tab_group = mainBox.getTab('Section').menu;
    var objX = 10;
    var objY = 10;

    function copyNotesOnSection(?secOff:Int = 0, ?showMessage:Bool = true) // Used on "Copy Section" and "Copy Last Section" buttons
    {
      var curSectionTime:Null<Float> = cachedSectionTimes[curSec - secOff];
      if (curSectionTime == null)
      {
        // showOutput('ERROR: Unknown section??', true);
        return;
      }

      var nextSectionTime:Null<Float> = cachedSectionTimes[curSec - secOff + 1];
      if (nextSectionTime == null) Math.POSITIVE_INFINITY;

      var notesCopyNum:Int = 0;
      if (affectNotes.checked)
      {
        copiedNotes = [];
        for (note in notes)
        {
          if (note.strumTime >= curSectionTime && note.strumTime < nextSectionTime)
          {
            var dataCopy:Array<Dynamic> = makeNoteDataCopy(note.songData, false);
            dataCopy[0] = note.strumTime - curSectionTime;
            copiedNotes.push(dataCopy);
            notesCopyNum++;
          }
        }
      }

      var eventsCopyNum:Int = 0;
      if (affectEvents.checked)
      {
        copiedEvents = [];
        for (event in events)
        {
          if (event.strumTime >= curSectionTime && event.strumTime < nextSectionTime)
          {
            var dataCopy:Array<Dynamic> = makeNoteDataCopy(event.songData, true);
            dataCopy[0] = event.strumTime - curSectionTime;

            copiedEvents.push(dataCopy);
            eventsCopyNum++;
          }
        }
      }

      if (showMessage)
      {
        if (notesCopyNum == 0 && eventsCopyNum == 0)
        {
          showOutput('Nothing to copy!', true);
          return;
        }

        var str:String = '';
        if (notesCopyNum > 0) str += 'Notes Copied: $notesCopyNum';
        if (eventsCopyNum > 0)
        {
          if (str.length > 0) str += '\n';
          str += 'Events Copied: $eventsCopyNum';
        }

        if (str.length > 0) showOutput(str);
      }
    }

    mustHitCheckBox = new PsychUICheckBox(objX, objY, 'Must Hit Sec.', 70, function() {
      var sec = getCurChartSection();
      if (sec != null) sec.mustHitSection = mustHitCheckBox.checked;
      updateHeads(true);
    });
    gfSectionCheckBox = new PsychUICheckBox(objX + 100, objY, 'GF Section', 70, function() {
      var sec = getCurChartSection();
      if (sec != null) sec.gfSection = gfSectionCheckBox.checked;
      updateHeads(true);
    });
    player4SectionCheckBox = new PsychUICheckBox(gfSectionCheckBox.x, gfSectionCheckBox.y + 20, 'Player 4 Section', 80, function() {
      var sec = getCurChartSection();
      if (sec != null) sec.player4Section = player4SectionCheckBox.checked;
    });
    altAnimSectionCheckBox = new PsychUICheckBox(objX + 200, objY, 'Alt Anim', 70, function() {
      var sec = getCurChartSection();
      if (sec != null) sec.altAnim = altAnimSectionCheckBox.checked;
    });
    playerAltAnimSectionCheckBox = new PsychUICheckBox(objX + 200, objY + 20, 'Player Alt Anim', 70, function() {
      var sec = getCurChartSection();
      if (sec != null) sec.playerAltAnim = playerAltAnimSectionCheckBox.checked;
    });
    cpuAltAnimSectionCheckBox = new PsychUICheckBox(playerAltAnimSectionCheckBox.x, playerAltAnimSectionCheckBox.y + 20, 'CPU Alt Anim', 70, function() {
      var sec = getCurChartSection();
      if (sec != null) sec.CPUAltAnim = cpuAltAnimSectionCheckBox.checked;
    });

    objY += 40;
    changeBpmCheckBox = new PsychUICheckBox(objX, objY, 'Change BPM', 80, function() {
      var sec = getCurChartSection();
      if (sec != null)
      {
        var oldTimes:Array<Float> = cachedSectionTimes.copy();
        sec.changeBPM = changeBpmCheckBox.checked;
        if (!Reflect.hasField(sec, 'bpm')) sec.bpm = changeBpmStepper.value;
        adaptNotesToNewTimes(oldTimes);
      }
    });

    objY += 25;
    changeBpmStepper = new PsychUINumericStepper(objX, objY, 1, 0, 1, 400, 3);
    changeBpmStepper.onValueChange = function() {
      var sec = getCurChartSection();
      if (sec != null)
      {
        var oldTimes:Array<Float> = cachedSectionTimes.copy();
        sec.bpm = changeBpmStepper.value;
        sec.changeBPM = true;
        changeBpmCheckBox.checked = true;
        adaptNotesToNewTimes(oldTimes);
      }
    };

    dTypeSecStepper = new PsychUINumericStepper(objX + 90, objY, 1, 0, 0, 1000, 0);
    dTypeSecStepper.onValueChange = function() {
      var sec = getCurChartSection();
      if (sec != null)
      {
        // No Negative Numbers!
        sec.dType = Std.int(Math.abs(dTypeSecStepper.value));
      }
    };

    objY += 40;
    var copyButton:PsychUIButton = new PsychUIButton(objX, objY, 'Copy Section', copyNotesOnSection.bind());
    var pasteButton:PsychUIButton = new PsychUIButton(objX + 100, objY, 'Paste Section', function() {
      pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
    });
    var clearButton:PsychUIButton = new PsychUIButton(objX + 200, objY, 'Clear', function() {
      if (affectNotes.checked)
      {
        for (note in curRenderedNotes)
        {
          if (note == null || note.isEvent) continue;

          selectedNotes.remove(note);
          notes.remove(note);
        }
      }
      if (affectEvents.checked)
      {
        for (event in curRenderedNotes)
        {
          if (event == null || !event.isEvent) continue;

          selectedNotes.remove(event);
          events.remove(cast(event, EventMetaNote));
        }
      }
      softReloadNotes(true);
    });
    clearButton.normalStyle.bgColor = FlxColor.RED;
    clearButton.normalStyle.textColor = FlxColor.WHITE;

    objY += 25;
    affectNotes = new PsychUICheckBox(objX, objY, 'Notes', 60);
    affectNotes.checked = true;
    affectEvents = new PsychUICheckBox(objX + 100, objY, 'Events', 60);

    objY += 32;
    var copyLastSecButton:PsychUIButton = new PsychUIButton(objX, objY, 'Copy Last Section', function() {
      var lastCopiedNotes = copiedNotes;
      var lastCopiedEvents = copiedEvents;
      copyNotesOnSection(Std.int(copyLastSecStepper.value), false);
      pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
      copiedNotes = lastCopiedNotes;
      copiedEvents = lastCopiedEvents;
    });
    copyLastSecButton.resize(80, 26);
    copyLastSecStepper = new PsychUINumericStepper(objX + 90, objY + 2, 1, 1, -999, 999, 0);

    beatsPerSecStepper = new PsychUINumericStepper(copyLastSecStepper.x + 70, objY + 2, 1, 4, 1, 7, 2);
    beatsPerSecStepper.onValueChange = function() {
      var sec = getCurChartSection();
      if (sec != null)
      {
        var oldTimes:Array<Float> = cachedSectionTimes.copy();
        sec.sectionBeats = beatsPerSecStepper.value;
        adaptNotesToNewTimes(oldTimes);
      }
    };

    objY += 40;
    var swapSectionButton:PsychUIButton = new PsychUIButton(objX, objY, 'Swap Section', function() {
      var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
      for (note in curRenderedNotes)
      {
        if (note != null && !note.isEvent)
        {
          var data:Int = note.songData[1] + GRID_COLUMNS_PER_PLAYER;
          if (data >= maxData) data -= maxData;
          note.changeNoteData(data);
          positionNoteXByData(note);
        }
      }
      softReloadNotes(true);
    });
    var duetSectionButton:PsychUIButton = new PsychUIButton(objX + 100, objY, 'Duet Section', function() {
      var side:Int = -1;
      for (note in curRenderedNotes.members)
      {
        if (note == null || note.isEvent) continue;

        // First figure out if there are notes on more than one player's sides to cancel operation early
        if (side > -1)
        {
          if (Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER) != side)
          {
            showOutput('You cannot press this button with notes on more than one side.');
            return;
          }
        }
        else
          side = Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER);
      }

      var pushedNotes:Array<MetaNote> = [];
      for (note in curRenderedNotes.members)
      {
        if (note == null || note.isEvent) continue;

        for (i in 0...GRID_PLAYERS)
        {
          if (i == side) continue;

          var songDataCopy:Array<Dynamic> = note.songData.copy();
          songDataCopy[1] = note.noteData + i * GRID_COLUMNS_PER_PLAYER;
          var newNote = createNote(songDataCopy);
          notes.push(newNote);
          pushedNotes.push(newNote);
        }
      }
      notes.sort(PlayState.sortByTime);
      softReloadNotes(true);

      addUndoAction(ADD_NOTE, {notes: pushedNotes});
    });
    var mirrorNotesButton:PsychUIButton = new PsychUIButton(objX + 200, objY, 'Mirror Notes', function() {
      var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
      for (note in curRenderedNotes)
      {
        if (note == null || note.isEvent) continue;

        var data:Int = Std.int(note.songData[1]);
        note.changeNoteData((Math.floor(data / GRID_COLUMNS_PER_PLAYER) * GRID_COLUMNS_PER_PLAYER) + GRID_COLUMNS_PER_PLAYER - note.noteData - 1);
        positionNoteXByData(note);
      }
      softReloadNotes(true);
    });

    tab_group.add(mustHitCheckBox);
    tab_group.add(gfSectionCheckBox);
    tab_group.add(player4SectionCheckBox);
    tab_group.add(altAnimSectionCheckBox);
    tab_group.add(playerAltAnimSectionCheckBox);
    tab_group.add(cpuAltAnimSectionCheckBox);

    tab_group.add(new FlxText(copyLastSecStepper.x, copyLastSecStepper.y - 15, 100, 'Copy Last Section:'));
    tab_group.add(new FlxText(beatsPerSecStepper.x, beatsPerSecStepper.y - 15, 100, 'Beats Per Section:'));
    tab_group.add(new FlxText(dTypeSecStepper.x, dTypeSecStepper.y - 15, 100, 'D Type Per Section:'));
    tab_group.add(changeBpmCheckBox);
    tab_group.add(changeBpmStepper);
    tab_group.add(beatsPerSecStepper);
    tab_group.add(dTypeSecStepper);

    tab_group.add(copyButton);
    tab_group.add(pasteButton);
    tab_group.add(clearButton);
    tab_group.add(affectNotes);
    tab_group.add(affectEvents);

    tab_group.add(copyLastSecButton);
    tab_group.add(copyLastSecStepper);

    tab_group.add(swapSectionButton);
    tab_group.add(duetSectionButton);
    tab_group.add(mirrorNotesButton);
  }

  function reloadNotesDropdowns()
  {
    // Event drop down
    if (eventDropDown != null)
    {
      eventsList = [];
      var eventFiles:Array<String> = loadFileList('custom_events/', ['.txt']);
      for (file in eventFiles)
      {
        var desc:String = Paths.getTextFromFile('custom_events/$file.txt');
        eventsList.push([file, desc]);
      }

      for (id => event in defaultEvents)
        if (!eventsList.contains(event)) eventsList.insert(id, event);

      var displayEventsList:Array<String> = [];
      for (id => data in eventsList)
      {
        if (id > 0) displayEventsList[id] = '$id. ${data[0]}';
        else
          displayEventsList.push('');
      }

      var lastSelected:String = eventDropDown.selectedLabel;
      eventDropDown.list = displayEventsList;
      eventDropDown.selectedLabel = lastSelected;
    }

    // Note type drop down
    if (noteTypeDropDown != null)
    {
      var exts:Array<String> = ['.txt'];
      #if LUA_ALLOWED exts.push('.lua'); #end
      #if HSCRIPT_ALLOWED
      exts.push('.hx');
      exts.push('.hsc');
      exts.push('.hscript');
      exts.push('.hxs');
      #end
      noteTypes = loadFileList('custom_notetypes/', exts);
      for (id => noteType in Note.defaultNoteTypes)
        if (!noteTypes.contains(noteType)) noteTypes.insert(id, noteType);

      if (Song.chartPath != null && Song.chartPath.length > 0)
      {
        var parentFolder:String = Song.chartPath.replace('/', '\\');
        parentFolder = parentFolder.substr(0, Song.chartPath.lastIndexOf('\\') + 1);
        var notetypeFile:Array<String> = CoolUtil.coolTextFile(parentFolder + 'notetypes.txt');
        if (notetypeFile.length > 0)
        {
          for (ntTyp in notetypeFile)
          {
            var name:String = ntTyp.trim();
            if (!noteTypes.contains(name)) noteTypes.push(name);
          }
        }
      }

      var displayNoteTypes:Array<String> = noteTypes.copy();
      for (id => key in displayNoteTypes)
      {
        if (id == 0) continue;
        displayNoteTypes[id] = '$id. $key';
      }

      var lastSelected:String = noteTypeDropDown.selectedLabel;
      noteTypeDropDown.list = displayNoteTypes;
      noteTypeDropDown.selectedLabel = lastSelected;
    }
  }

  function pasteCopiedNotesToSection(?canCopyNotes:Bool = true, ?canCopyEvents:Bool = true,
      ?showMessage:Bool = true) // Used on "Paste Section" and "Copy Last Section" buttons
  {
    var curSectionTime:Null<Float> = cachedSectionTimes[curSec];
    if (curSectionTime == null)
    {
      showOutput('ERROR: Unknown section??', true);
      return [];
    }

    var pushedNotes:Array<MetaNote> = [];
    var nts:Array<MetaNote> = [];
    var evs:Array<EventMetaNote> = [];
    if (canCopyNotes && copiedNotes.length > 0)
    {
      for (note in copiedNotes)
      {
        if (note == null) continue;
        var dataCopy:Array<Dynamic> = makeNoteDataCopy(note, false);
        dataCopy[0] += curSectionTime;

        var createdNote = createNote(dataCopy, curSec);
        notes.push(createdNote);
        pushedNotes.push(createdNote);
        nts.push(createdNote);
      }
      notes.sort(PlayState.sortByTime);
    }

    if (canCopyEvents && copiedEvents.length > 0)
    {
      for (event in copiedEvents)
      {
        if (event == null) continue;
        var dataCopy:Array<Dynamic> = makeNoteDataCopy(event, true);
        dataCopy[0] += curSectionTime;

        var createdEvent = createEvent(dataCopy);
        events.push(createdEvent);
        pushedNotes.push(createdEvent);
        evs.push(createdEvent);
      }
      events.sort(PlayState.sortByTime);
    }
    loadSection();

    if (showMessage)
    {
      if (nts.length == 0 && evs.length == 0)
      {
        showOutput('Nothing to paste!', true);
        return [];
      }

      var str:String = '';
      if (nts.length > 0) str += 'Notes Added: ${nts.length}';
      if (evs.length > 0)
      {
        if (str.length > 0) str += '\n';
        str += 'Events Added: ${evs.length}';
      }

      if (str.length > 0) showOutput(str);
    }
    addUndoAction(ADD_NOTE, {notes: nts, events: evs});
    return pushedNotes;
  }

  var songNameInputText:PsychUIInputText;
  var allowVocalsCheckBox:PsychUICheckBox;

  var bpmStepper:PsychUINumericStepper;
  var scrollSpeedStepper:PsychUINumericStepper;
  var audioOffsetStepper:PsychUINumericStepper;

  var stageDropDown:PsychUIDropDownMenu;
  var playerDropDown:PsychUIDropDownMenu;
  var opponentDropDown:PsychUIDropDownMenu;
  var girlfriendDropDown:PsychUIDropDownMenu;

  function addSongTab()
  {
    var tab_group = mainBox.getTab('Song').menu;
    var objX = 10;
    var objY = 25;

    songNameInputText = new PsychUIInputText(objX, objY, 100, 'None', 8);
    songNameInputText.onChange = function(old:String, cur:String) PlayState.SONG.songId = cur;

    allowVocalsCheckBox = new PsychUICheckBox(objX, objY + 20, 'Allow Vocals', 80, function() {
      PlayState.SONG.needsVoices = allowVocalsCheckBox.checked;
      loadMusic();
    });
    var reloadAudioButton:PsychUIButton = new PsychUIButton(objX + 120, objY, 'Reload Audio', function() loadMusic(true), 80);

    objY += 65;
    // (x:Float = 0, y:Float = 0, step:Float = 1, defValue:Float = 0, min:Float = -999, max:Float = 999, decimals:Int = 0, ?wid:Int = 60, ?isPercent:Bool = false)
    bpmStepper = new PsychUINumericStepper(objX, objY, 1, 1, 1, 400, 3);
    bpmStepper.onValueChange = function() {
      var oldTimes:Array<Float> = cachedSectionTimes.copy();
      PlayState.SONG.bpm = bpmStepper.value;
      adaptNotesToNewTimes(oldTimes);
    };

    scrollSpeedStepper = new PsychUINumericStepper(objX + 90, objY, 0.1, 1, 0.1, 10, 2);
    scrollSpeedStepper.onValueChange = function() PlayState.SONG.speed = scrollSpeedStepper.value;

    audioOffsetStepper = new PsychUINumericStepper(objX + 180, objY, 1, 0, -500, 500, 0);
    audioOffsetStepper.onValueChange = function() {
      PlayState.SONG.offset = audioOffsetStepper.value;
      Conductor.offset = audioOffsetStepper.value;
    };

    tab_group.add(new FlxText(songNameInputText.x, songNameInputText.y - 15, 80, 'Song Name:'));
    tab_group.add(songNameInputText);
    tab_group.add(allowVocalsCheckBox);
    tab_group.add(reloadAudioButton);

    // Find characters
    var characters:Array<String> = [];
    //

    objY += 40;
    playerDropDown = new PsychUIDropDownMenu(objX, objY, [''], function(id:Int, character:String) {
      PlayState.SONG.characters.player = character;
      updateJsonData();
      updateHeads(true);
      loadMusic();
      trace('selected $character');
    });
    stageDropDown = new PsychUIDropDownMenu(objX + 140, objY, [''], function(id:Int, stage:String) {
      PlayState.SONG.stage = stage;
      StageData.loadDirectory(PlayState.SONG);
      trace('selected $stage');
    });

    opponentDropDown = new PsychUIDropDownMenu(objX, objY + 40, [''], function(id:Int, character:String) {
      PlayState.SONG.characters.opponent = character;
      updateJsonData();
      updateHeads(true);
      loadMusic();
      trace('selected $character');
    });

    girlfriendDropDown = new PsychUIDropDownMenu(objX, objY + 80, [''], function(id:Int, character:String) {
      PlayState.SONG.characters.girlfriend = character;
      trace('selected $character');
    });

    tab_group.add(new FlxText(bpmStepper.x, bpmStepper.y - 15, 50, 'BPM:'));
    tab_group.add(new FlxText(scrollSpeedStepper.x, scrollSpeedStepper.y - 15, 80, 'Scroll Speed:'));
    tab_group.add(new FlxText(audioOffsetStepper.x, audioOffsetStepper.y - 15, 100, 'Audio Offset (ms):'));
    tab_group.add(bpmStepper);
    tab_group.add(scrollSpeedStepper);
    tab_group.add(audioOffsetStepper);

    // dropdowns
    tab_group.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 80, 'Stage:'));
    tab_group.add(new FlxText(playerDropDown.x, playerDropDown.y - 15, 80, 'Player:'));
    tab_group.add(new FlxText(opponentDropDown.x, opponentDropDown.y - 15, 80, 'Opponent:'));
    tab_group.add(new FlxText(girlfriendDropDown.x, girlfriendDropDown.y - 15, 80, 'Girlfriend:'));
    tab_group.add(stageDropDown);
    tab_group.add(girlfriendDropDown);
    tab_group.add(opponentDropDown);
    tab_group.add(playerDropDown);
  }

  var disableCachingCheckBox:PsychUICheckBox;
  var notITGModchartCheckBox:PsychUICheckBox;
  var usesHUDCheckBox:PsychUICheckBox;
  var oldBarSystemCheckBox:PsychUICheckBox;
  var forceRightScrollCheckBox:PsychUICheckBox;
  var forceMiddleScrollCheckBox:PsychUICheckBox;
  var blockOpponentModeCheckBox:PsychUICheckBox;

  var useSLEHUDCheckBox:PsychUICheckBox;

  var vocalsPrefixInputText:PsychUIInputText;
  var vocalsSuffixInputText:PsychUIInputText;
  var instrumentalPrefixInputText:PsychUIInputText;
  var instrumentalSuffixInputText:PsychUIInputText;

  function addGameplayOptionsTab()
  {
    var tab_group = mainBox.getTab('Gameplay Options').menu;
    var objX = 10;
    var objY = 10;

    disableCachingCheckBox = new PsychUICheckBox(objX, objY, 'Disable PlayState Caching', 60,
      function() PlayState.SONG.options.disableCaching = disableCachingCheckBox.checked);
    notITGModchartCheckBox = new PsychUICheckBox(disableCachingCheckBox.x + 70, objY, 'NotITG Modchart', 60,
      function() PlayState.SONG.options.notITG = notITGModchartCheckBox.checked);
    usesHUDCheckBox = new PsychUICheckBox(notITGModchartCheckBox.x + 90, objY, 'Notes In HUD Camera', 60,
      function() PlayState.SONG.options.usesHUD = usesHUDCheckBox.checked);

    // 40 Y Split
    objY += 40;
    oldBarSystemCheckBox = new PsychUICheckBox(objX, objY, 'Uses Old Bars', 60, function() PlayState.SONG.options.oldBarSystem = oldBarSystemCheckBox.checked);
    forceRightScrollCheckBox = new PsychUICheckBox(oldBarSystemCheckBox.x + 70, objY, 'Force RightScroll', 60,
      function() PlayState.SONG.options.rightScroll = forceRightScrollCheckBox.checked);
    forceMiddleScrollCheckBox = new PsychUICheckBox(forceRightScrollCheckBox.x + 90, objY, 'Force MiddleScroll', 70,
      function() PlayState.SONG.options.middleScroll = forceMiddleScrollCheckBox.checked);

    // Obj 40 Y Split
    objY += 40;
    blockOpponentModeCheckBox = new PsychUICheckBox(objX, objY, 'Block Opponent Mode', 60,
      function() PlayState.SONG.options.blockOpponentMode = blockOpponentModeCheckBox.checked);

    useSLEHUDCheckBox = new PsychUICheckBox(blockOpponentModeCheckBox.x + 70, objY, 'Use SLE HUD', 60,
    function() {
      if (PlayState.SONG.options.sleHUD != null)
        PlayState.SONG.options.sleHUD = useSLEHUDCheckBox.checked;
      else 
        PlayState.SONG.sleHUD = useSLEHUDCheckBox.checked;
    });

    // 80 Y Split
    objY += 80;
    vocalsPrefixInputText = new PsychUIInputText(objX, objY, 100, '', 8);
    vocalsPrefixInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.vocalsPrefix = cur;

    vocalsSuffixInputText = new PsychUIInputText(objX + 120, objY, 100, '', 8);
    vocalsSuffixInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.vocalsSuffix = cur;

    // 130 Y Split
    objY += 50;
    instrumentalSuffixInputText = new PsychUIInputText(objX, objY, 100, '', 8);
    instrumentalSuffixInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.instrumentalSuffix = cur;

    instrumentalPrefixInputText = new PsychUIInputText(objX + 120, objY, 100, '', 8);
    instrumentalPrefixInputText.onChange = function(old:String, cur:String) PlayState.SONG.options.instrumentalPrefix = cur;

    tab_group.add(disableCachingCheckBox);
    tab_group.add(notITGModchartCheckBox);
    tab_group.add(blockOpponentModeCheckBox);
    tab_group.add(useSLEHUDCheckBox);
    tab_group.add(usesHUDCheckBox);
    tab_group.add(oldBarSystemCheckBox);
    tab_group.add(forceRightScrollCheckBox);
    tab_group.add(forceMiddleScrollCheckBox);

    tab_group.add(new FlxText(vocalsPrefixInputText.x, vocalsPrefixInputText.y - 15, 100, "Vocals Prefix:"));
    tab_group.add(new FlxText(vocalsSuffixInputText.x, vocalsSuffixInputText.y - 15, 100, "Vocals Suffix:"));
    tab_group.add(new FlxText(instrumentalPrefixInputText.x, instrumentalPrefixInputText.y - 15, 130, "Instrumental Prefix:"));
    tab_group.add(new FlxText(instrumentalSuffixInputText.x, instrumentalSuffixInputText.y - 15, 130, "Instrumental Suffix:"));
    tab_group.add(vocalsPrefixInputText);
    tab_group.add(vocalsSuffixInputText);
    tab_group.add(instrumentalPrefixInputText);
    tab_group.add(instrumentalSuffixInputText);
  }

  function addFileTab()
  {
    var tab = upperBox.getTab('File');
    var tab_group = tab.menu;
    var btnX = tab.x - upperBox.x;
    var btnY = 1;
    var btnWid = Std.int(tab.width);

    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  New', function() {
      var func:Void->Void = function() {
        openNewChart();
        reloadNotesDropdowns();
        prepareReload();
      }

      if (!ignoreProgressCheckBox.checked) openSubState(new Prompt('Are you sure you want to start over?', func));
      else
        func();
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Chart...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      fileDialog.open(function() {
        try
        {
          var filePath:String = fileDialog.path.replace('/', '\\');
          var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('\\')));
          if (loadedChart == null || !Reflect.hasField(loadedChart, 'song')) // Check if chart is ACTUALLY a chart and valid
          {
            showOutput('Error: File loaded is not a Psych Engine/FNF 0.2.x.x chart.', true);
            return;
          }

          var func:Void->Void = function() {
            loadChart(loadedChart);
            Song.chartPath = fileDialog.path;
            reloadNotesDropdowns();
            prepareReload();
            showOutput('Opened chart "${Song.chartPath}" successfully!');
          }
          if (!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', func));
          else
            func();
        }
        catch (e:Exception)
        {
          showOutput('Error: ${e.message}', true);
          trace(e.stack);
        }
      });
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Autosave...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      if (!FileSystem.exists('backups/'))
      {
        showOutput('The "backups" folder does not exist.', true);
        return;
      }

      var fileList:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
      if (fileList.length < 1)
      {
        showOutput('No autosave files found.', true);
        return;
      }

      fileList.sort((a:String, b:String) -> (a.toUpperCase() < b.toUpperCase()) ? 1 : -1); // Sort alphabetically descending
      var maxItems:Int = Std.int(Math.min(5, fileList.length));
      var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(0, 0, fileList, 25, maxItems, false, 240);
      radioGrp.checked = 0;

      var hei:Float = radioGrp.height + 160;
      openSubState(new BasePrompt(420, hei, 'Choose an Autosave', function(state:BasePrompt) {
        upperBox.isMinimized = true;
        upperBox.bg.visible = false;

        var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
        btn.cameras = state.cameras;
        state.add(btn);

        radioGrp.screenCenter(X);
        radioGrp.y = state.bg.y + 80;
        radioGrp.cameras = state.cameras;
        state.add(radioGrp);

        var btn:PsychUIButton = new PsychUIButton(0, radioGrp.y + radioGrp.height + 20, 'Load', function() {
          var autosaveName:String = fileList[radioGrp.checked];
          var path:String = 'backups/$autosaveName';
          state.close();

          if (FileSystem.exists(path))
          {
            try
            {
              var loadedChart:SwagSong = Song.parseJSON(File.getContent(path), autosaveName, null);
              if (loadedChart == null || !Reflect.hasField(loadedChart, '__original_path'))
              {
                showOutput('Error: File loaded is not a valid Psych Engine autosave.', true);
                return;
              }

              var originalPath:String = Reflect.field(loadedChart, '__original_path');
              Reflect.deleteField(loadedChart, '__original_path');

              var func:Void->Void = function() {
                Song.chartPath = FileSystem.exists(originalPath) ? originalPath : null;
                loadChart(loadedChart);
                reloadNotesDropdowns();

                showOutput('Opened autosave "$autosaveName" successfully!');
              }

              if (!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', func));
              else
                func();
            }
            catch (e:Exception)
            {
              showOutput('Error on loading autosave: ${e.message}', true);
            }
          }
          else
            showOutput('Error! Autosave file selected could not be found, huh??', true);
        });
        btn.cameras = state.cameras;
        btn.screenCenter(X);
        state.add(btn);
      }));
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    if (SHOW_EVENT_COLUMN)
    {
      btnY += 20;
      var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Events...', function() {
        if (!fileDialog.completed) return;
        upperBox.isMinimized = true;
        upperBox.bg.visible = false;

        fileDialog.open(function() {
          try
          {
            var filePath:String = fileDialog.path.replace('/', '\\');
            var eventsFile:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('\\')));
            if (eventsFile == null || Reflect.hasField(eventsFile, 'scrollSpeed') || eventsFile.events == null)
            {
              showOutput('Error: File loaded is not a Psych Engine chart/events file.', true);
              return;
            }

            var loadedEvents:Array<Dynamic> = eventsFile.events;
            if (loadedEvents.length < 1)
            {
              showOutput('Events file loaded is empty.', true);
              return;
            }

            openSubState(new BasePrompt('Events Found! Choose an action.', function(state:BasePrompt) {
              var btnY = 390;
              var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Replace All', function() {
                for (event in events)
                {
                  if (event != null)
                  {
                    event.destroy();
                    selectedNotes.remove(event);
                  }
                }
                undoActions = [];
                events = [];

                for (event in loadedEvents)
                  events.push(createEvent(event));

                softReloadNotes();
                state.close();
                showOutput('Events loaded successfully!');
              });
              btn.normalStyle.bgColor = FlxColor.RED;
              btn.normalStyle.textColor = FlxColor.WHITE;
              btn.screenCenter(X);
              btn.x -= 125;
              btn.cameras = state.cameras;
              state.add(btn);

              var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Add', function() {
                for (event in loadedEvents)
                  events.push(createEvent(event));

                softReloadNotes();
                state.close();
                showOutput('Events added successfully!');
              });
              btn.screenCenter(X);
              btn.cameras = state.cameras;
              state.add(btn);

              var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Cancel', state.close);
              btn.screenCenter(X);
              btn.x += 125;
              btn.cameras = state.cameras;
              state.add(btn);
            }));
          }
          catch (e:Exception)
          {
            showOutput('Error: ${e.message}', true);
            trace(e.stack);
          }
        });
      }, btnWid);
      btn.text.alignment = LEFT;
      tab_group.add(btn);
    }

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      saveChart();
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save as...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      saveChart(false);
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    if (SHOW_EVENT_COLUMN)
    {
      btnY += 20;
      var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save Events...', function() {
        if (!fileDialog.completed) return;
        upperBox.isMinimized = true;

        updateChartData();
        fileDialog.save('events.json', PsychJsonPrinter.print({events: PlayState.SONG.events, format: 'psych_v1'}, ['events']),
          function() showOutput('Events saved successfully to: ${fileDialog.path}'), null, function() showOutput('Error on saving events!', true));
      }, btnWid);
      btn.text.alignment = LEFT;
      tab_group.add(btn);
    }

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Reload Chart', function() {
      var func:Void->Void = function() {
        if (Song.chartPath == null)
        {
          showOutput('You must save/load a Chart first to Reload it!', true);
          return;
        }

        if (FileSystem.exists(Song.chartPath))
        {
          try
          {
            var reloadedChart:SwagSong = Song.parseJSON(File.getContent(Song.chartPath));
            loadChart(reloadedChart);
            reloadNotesDropdowns();
            prepareReload();
            showOutput('Chart reloaded successfully!');
          }
          catch (e:Exception)
          {
            showOutput('Error: ${e.message}', true);
            trace(e.stack);
          }
        }
        else
          showOutput('You must save/load a Chart first to Reload it!', true);
      }

      if (!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress will be lost', func));
      else
        func();
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save (V-Slice)...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      fileDialog.openDirectory('Save V-Slice Chart/Metadata JSONs', function() {
        try
        {
          var path:String = fileDialog.path.replace('/', '\\');

          var chartName:String = Paths.formatToSongPath(PlayState.SONG.songId) + '.json';
          // if(Song.chartPath != null) chartName = Song.chartPath.replace('/', '\\').trim();
          chartName = chartName.substring(chartName.lastIndexOf('\\') + 1, chartName.lastIndexOf('.'));

          var chartFile:String = '$path\\$chartName-chart.json';
          var metadataFile:String = '$path\\$chartName-metadata.json';

          updateChartData();
          var pack:VSlicePackage = VSlice.export(PlayState.SONG);

          ClientPrefs.toggleVolumeKeys(false);
          openSubState(new BasePrompt('Metadata', function(state:BasePrompt) {
            var btnX = 640;
            var btnY = 400;
            var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'Save', function() {
              overwriteSavedSomething = false;
              overwriteCheck(chartFile, '$chartName-chart.json', PsychJsonPrinter.print(pack.chart, ['events', 'notes', 'scrollSpeed']), function() {
                overwriteCheck(metadataFile, '$chartName-metadata.json', PsychJsonPrinter.print(pack.metadata, ['characters', 'difficulties', 'timeChanges']),
                  function() {
                    if (overwriteSavedSomething) showOutput('Files saved successfully to: $path!');
                  });
              });
              state.close();
            });
            btn.normalStyle.bgColor = FlxColor.GREEN;
            btn.normalStyle.textColor = FlxColor.WHITE;
            btn.cameras = state.cameras;
            state.add(btn);

            var btn:PsychUIButton = new PsychUIButton(btnX + 100, btnY, 'Cancel', state.close);
            btn.cameras = state.cameras;
            state.add(btn);

            var textX = FlxG.width / 2 - 155;
            var textY = 360;
            var artistInput:PsychUIInputText = new PsychUIInputText(textX, textY, 120, pack.metadata.artist, 8);
            artistInput.cameras = state.cameras;
            artistInput.onChange = function(old:String, cur:String) pack.metadata.artist = cur;

            var charterInput:PsychUIInputText = new PsychUIInputText(textX + 190, textY, 120, pack.metadata.charter, 8);
            charterInput.cameras = state.cameras;
            charterInput.onChange = function(old:String, cur:String) pack.metadata.charter = cur;

            var artistTxt:FlxText = new FlxText(artistInput.x, artistInput.y - 15, 100, 'Artist/Composer:');
            artistTxt.cameras = state.cameras;
            var charterTxt:FlxText = new FlxText(charterInput.x, charterInput.y - 15, 100, 'Charter:');
            charterTxt.cameras = state.cameras;
            state.add(artistTxt);
            state.add(charterTxt);
            state.add(artistInput);
            state.add(charterInput);
          }));
          // trace(pack.chart);
          // trace(pack.metadata);
          // trace(chartName, chartFile, metadataFile);
        }
        catch (e:Exception)
        {
          showOutput('Error: ${e.message}', true);
          trace(e.stack);
        }
      });
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Psych to V-Slice...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      fileDialog.open('song.json', 'Open a Psych Engine Chart JSON', function() {
        var filePath:String = fileDialog.path.replace('/', '\\');
        var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('\\')));
        if (loadedChart == null || !Reflect.hasField(loadedChart, 'song')) // Check if chart is ACTUALLY a chart and valid
        {
          showOutput('Error: File loaded is not a Psych Engine 0.x.x/FNF 0.2.x.x chart.', true);
          return;
        }

        var pack:VSlicePackage = VSlice.export(loadedChart);
        if (pack.chart == null || pack.metadata == null)
        {
          showOutput('Error: Chart loaded is invalid.', true);
          return;
        }

        ClientPrefs.toggleVolumeKeys(false);
        openSubState(new BasePrompt('Metadata', function(state:BasePrompt) {
          var songName:String = Paths.formatToSongPath(pack.metadata.songName);
          var parentFolder:String = filePath.substring(0, filePath.lastIndexOf('\\') + 1);
          var artistInput, charterInput, difficultiesInput:PsychUIInputText = null;

          var btnX = 640;
          var btnY = 400;
          var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'Save', function() {
            try
            {
              var diffs:Array<String> = pack.metadata.playData.difficulties;
              if (diffs != null && diffs.length > 0)
              {
                var diffsFound:Array<String> = [];
                var defaultDiff:String = Paths.formatToSongPath(Difficulty.getDefault());
                for (diff in diffs)
                {
                  var diffPostfix:String = (diff != defaultDiff) ? '-$diff' : '';
                  var chartToFind:String = parentFolder + songName + diffPostfix + '.json';
                  if (FileSystem.exists(chartToFind))
                  {
                    var diffChart:SwagSong = Song.parseJSON(File.getContent(chartToFind), songName + diffPostfix);
                    if (diffChart != null)
                    {
                      var subpack:VSlicePackage = VSlice.export(diffChart);
                      var diffSpeed:Null<Float> = subpack.chart.scrollSpeed.get(diff);
                      var diffNotes:Array<VSliceNote> = subpack.chart.notes.get(diff);
                      if (diffSpeed != null && diffNotes != null)
                      {
                        pack.chart.scrollSpeed.set(diff, diffSpeed);
                        pack.chart.notes.set(diff, diffNotes);
                      }
                      // trace(diff, diffSpeed, diffNotes.length);
                    }
                  }
                  else
                    trace('File not found: $chartToFind');
                }

                var chartToFind:String = parentFolder + 'events.json';
                if (FileSystem.exists(chartToFind))
                {
                  var eventsChart:SwagSong = Song.parseJSON(File.getContent(chartToFind), 'events');
                  if (eventsChart != null)
                  {
                    var subpack:VSlicePackage = VSlice.export(eventsChart);
                    if (subpack.chart.events != null && subpack.chart.events.length > 0)
                    {
                      for (event in subpack.chart.events)
                      {
                        if (event == null) continue;
                        pack.chart.events.push(event);
                      }
                    }
                    @:privateAccess pack.chart.events.sort(VSlice.sortByTime);
                  }
                }

                fileDialog.openDirectory('Save V-Slice Chart/Metadata JSONs', function() {
                  overwriteSavedSomething = false;
                  var path:String = fileDialog.path.replace('/', '\\');
                  if (path.endsWith('\\')) path = path.substr(0, path.length - 1);
                  overwriteCheck('$path/$songName-chart.json', '$songName-chart.json', PsychJsonPrinter.print(pack.chart, ['events', 'notes', 'scrollSpeed']),
                    function() {
                      overwriteCheck('$path/$songName-metadata.json', '$songName-metadata.json',
                        PsychJsonPrinter.print(pack.metadata, ['characters', 'difficulties', 'timeChanges']), function() {
                          if (overwriteSavedSomething) showOutput('Files saved successfully to: $path!');
                      });
                    });
                });
              }
              else
                showOutput('Error: You need atleast one difficulty to export.', true);
            }
            catch (e:Exception)
            {
              showOutput('Error: ${e.message}', true);
              trace(e.stack);
            }
            state.close();
          });
          btn.normalStyle.bgColor = FlxColor.GREEN;
          btn.normalStyle.textColor = FlxColor.WHITE;
          btn.cameras = state.cameras;
          state.add(btn);

          var btn:PsychUIButton = new PsychUIButton(btnX + 100, btnY, 'Cancel', state.close);
          btn.cameras = state.cameras;
          state.add(btn);

          var textX = FlxG.width / 2 - 180;
          var textY = 360;
          artistInput = new PsychUIInputText(textX, textY, 120, pack.metadata.artist, 8);
          artistInput.cameras = state.cameras;
          artistInput.onChange = function(old:String, cur:String) pack.metadata.artist = cur;

          charterInput = new PsychUIInputText(textX + 150, textY, 120, pack.metadata.charter, 8);
          charterInput.cameras = state.cameras;
          charterInput.onChange = function(old:String, cur:String) pack.metadata.charter = cur;

          var diffs:Array<String> = pack.metadata.playData.difficulties;
          if (diffs == null || diffs.length < 0) pack.metadata.playData.difficulties = diffs = ['easy', 'normal', 'hard'];
          difficultiesInput = new PsychUIInputText(textX, textY + 42, 160, diffs.join(', '), 8);
          difficultiesInput.cameras = state.cameras;
          difficultiesInput.forceCase = LOWER_CASE;
          difficultiesInput.onChange = function(old:String, cur:String) {
            pack.metadata.playData.difficulties = cur.split(',');

            var diffs:Array<String> = pack.metadata.playData.difficulties;
            for (num => diff in diffs)
              diffs[num] = Paths.formatToSongPath(diff);

            while (diffs.contains('')) // Clear invalids cuz people might be stupid
              diffs.remove('');
          }

          var artistTxt:FlxText = new FlxText(artistInput.x, artistInput.y - 15, 100, 'Artist/Composer:');
          artistTxt.cameras = state.cameras;
          var charterTxt:FlxText = new FlxText(charterInput.x, charterInput.y - 15, 100, 'Charter:');
          charterTxt.cameras = state.cameras;
          var difficultiesTxt:FlxText = new FlxText(difficultiesInput.x, difficultiesInput.y - 15, 100, 'Difficulties:');
          difficultiesTxt.cameras = state.cameras;
          state.add(artistTxt);
          state.add(charterTxt);
          state.add(difficultiesTxt);
          state.add(artistInput);
          state.add(charterInput);
          state.add(difficultiesInput);
        }));
      });
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  V-Slice to Psych...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      fileDialog.open('chart.json', 'Open a V-Slice Chart file', function() {
        var chart:VSliceChart = cast Json.parse(fileDialog.data);
        if (chart == null || chart.version == null || chart.notes == null || chart.scrollSpeed == null)
        {
          showOutput('Error: File loaded is not a valid FNF V-Slice chart.', true);
          return;
        }

        fileDialog.open('metadata.json', 'Open a V-Slice Metadata file', function() {
          var metadata:VSliceMetadata = cast Json.parse(fileDialog.data);
          if (metadata == null
            || metadata.version == null
            || metadata.playData == null
            || metadata.songName == null
            || metadata.playData.difficulties == null
            || metadata.timeChanges == null
            || metadata.timeChanges.length < 1)
          {
            showOutput('Error: File loaded is not a valid FNF V-Slice metadata.', true);
            return;
          }

          try
          {
            var pack:PsychPackage = VSlice.convertToPsych(chart, metadata);
            if (pack.difficulties != null)
            {
              fileDialog.openDirectory('Save Converted Psych JSONs', function() {
                var path:String = fileDialog.path.replace('/', '\\');
                if (!path.endsWith('\\')) path += '\\';

                var diffs:Array<String> = metadata.playData.difficulties.copy();
                var defaultDiff:String = Paths.formatToSongPath(Difficulty.getDefault());
                function nextChart()
                {
                  while (diffs.length > 0)
                  {
                    var diffName:String = diffs[0];
                    diffs.remove(diffName);
                    if (!pack.difficulties.exists(diffName)) continue;

                    var diffPostfix:String = (diffName != defaultDiff) ? '-$diffName' : '';
                    var chartData:SwagSong = pack.difficulties.get(diffName);
                    var chartName:String = Paths.formatToSongPath(chartData.songId) + diffPostfix + '.json';
                    overwriteCheck(path + chartName, chartName, PsychJsonPrinter.print(chartData, ['sectionNotes', 'events']), nextChart, true);
                    return;
                  }

                  if (pack.events != null)
                  {
                    overwriteCheck(path + 'events.json', 'events.json', PsychJsonPrinter.print(pack.events, ['events']), function() {
                      if (overwriteSavedSomething) showOutput('Files saved successfully to: ${fileDialog.path}!');
                    }, true);
                  }
                  else if (overwriteSavedSomething) showOutput('Files saved successfully to: ${fileDialog.path}!');
                }

                overwriteSavedSomething = false;
                nextChart();
              });
            }
            else
              showOutput('Error: No difficulties found.');
          }
          catch (e:Exception)
          {
            showOutput('Error: ${e.message}', true);
            trace(e.stack);
          }
        });
      });
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Update (Legacy)...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      fileDialog.open(function() {
        var oldSong = PlayState.SONG;
        try
        {
          var filePath:String = fileDialog.path.replace('/', '\\');
          filePath = filePath.substring(filePath.lastIndexOf('\\') + 1, filePath.lastIndexOf('.'));

          var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, filePath, '');
          if (loadedChart == null || !Reflect.hasField(loadedChart, 'song')) // Check if chart is ACTUALLY a chart and valid
          {
            showOutput('Error: File loaded is not a Psych Engine 0.x.x/FNF 0.2.x.x chart.', true);
            return;
          }

          var fmt:String = loadedChart.format;
          if (fmt == null || fmt.length < 1) fmt = loadedChart.format = 'unknown';

          if (!fmt.startsWith('psych_v1'))
          {
            loadedChart.format = 'psych_v1_convert';
            Song.convert(loadedChart);
            File.saveContent(fileDialog.path, PsychJsonPrinter.print(loadedChart, ['sectionNotes', 'events']));
            showOutput('Updated "$filePath" from format "$fmt" to "psych_v1" successfully!');
          }
          else
            showOutput('Chart is already up-to-date! Format: "$fmt"', true);

          Song.processSongDataToSCEData(loadedChart);
        }
        catch (e:Exception)
        {
          showOutput('Error: ${e.message}', true);
          trace(e.stack);
        }
      });
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Preview (F12)', openEditorPlayState, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Playtest (Enter)', goToPlayState, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Exit', function() {
      PlayState.chartingMode = false;
      MusicBeatState.switchState(new states.editors.MasterEditorMenu());
      FlxG.sound.playMusic(Paths.music('freakyMenu'));
      FlxG.mouse.visible = false;
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);
  }

  var lockedEvents:Bool = false;

  function addEditTab()
  {
    var tab = upperBox.getTab('Edit');
    var tab_group = tab.menu;
    var btnX = tab.x - upperBox.x;
    var btnY = 1;
    var btnWid = Std.int(tab.width);

    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Undo', function() undo, btnWid); // TO DO: Add functionality
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Redo', function() redo, btnWid); // TO DO: Add functionality
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Select All', function() {
      var sel = selectedNotes;
      selectedNotes = curRenderedNotes.members.copy();
      addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
      onSelectNote();
      trace('Notes selected: ' + selectedNotes.length);
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    if (SHOW_EVENT_COLUMN)
    {
      btnY++;
      btnY += 20;
      var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Lock Events', btnWid);
      btn.onClick = function() {
        lockedEvents = !lockedEvents;
        if (lockedEvents) btn.text.text = '  Unlock Events';
        else
          btn.text.text = '  Lock Events';
        eventLockOverlay.visible = lockedEvents;

        if (selectedNotes.length >= 1)
        {
          var sel = selectedNotes;
          var onlyNotes = selectedNotes.filter((note:MetaNote) -> !note.isEvent);
          resetSelectedNotes();
          selectedNotes = onlyNotes;
          addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
          if (selectedNotes.length == 1) onSelectNote();
        }
        softReloadNotes();
      };
      btn.text.alignment = LEFT;
      tab_group.add(btn);
    }

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Autosave Settings...', btnWid);
    btn.onClick = function() {
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;
      openSubState(new BasePrompt(400, 160, 'Autosave Settings', function(state:BasePrompt) {
        var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
        btn.cameras = state.cameras;
        state.add(btn);

        var checkbox:PsychUICheckBox = null;
        var timeStepper:PsychUINumericStepper = null;

        timeStepper = new PsychUINumericStepper(state.bg.x + 50, state.bg.y + 90, 1, autoSaveCap, 1, 30, 0);
        timeStepper.onValueChange = function() {
          autoSaveTime = 0;
          checkbox.checked = true;
          autoSaveCap = chartEditorSave.data.autoSave = Std.int(timeStepper.value);
        };
        timeStepper.cameras = state.cameras;

        checkbox = new PsychUICheckBox(timeStepper.x + 80, timeStepper.y, 'Enabled', 60, function() {
          autoSaveTime = 0;
          autoSaveCap = chartEditorSave.data.autoSave = checkbox.checked ? Std.int(timeStepper.value) : 0;
        });
        checkbox.checked = (autoSaveCap > 0);
        checkbox.cameras = state.cameras;

        var maxFileStepper:PsychUINumericStepper = new PsychUINumericStepper(checkbox.x + 140, checkbox.y, 1, backupLimit, 0, 50, 0);
        maxFileStepper.onValueChange = function() {
          autoSaveTime = 0;
          checkbox.checked = true;
          chartEditorSave.data.backupLimit = backupLimit = Std.int(maxFileStepper.value);
        };
        maxFileStepper.cameras = state.cameras;

        var txt1:FlxText = new FlxText(timeStepper.x, timeStepper.y - 15, 100, 'Time (in minutes):');
        txt1.cameras = state.cameras;
        var txt2:FlxText = new FlxText(maxFileStepper.x, maxFileStepper.y - 15, 100, 'File Limit:');
        txt2.cameras = state.cameras;

        state.add(txt1);
        state.add(txt2);
        state.add(checkbox);
        state.add(timeStepper);
        state.add(maxFileStepper);
      }));
    };
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Clear All Notes', function() {
      var func:Void->Void = function() {
        resetSelectedNotes();
        addUndoAction(DELETE_NOTE, {notes: notes.copy()});
        notes = [];
        loadSection();
      }

      if (!ignoreProgressCheckBox.checked) openSubState(new Prompt('Delete all Notes in the song?', func));
      else
        func();
    }, btnWid);
    btn.normalStyle.bgColor = FlxColor.RED;
    btn.normalStyle.textColor = FlxColor.WHITE;
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    if (SHOW_EVENT_COLUMN)
    {
      btnY += 20;
      var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Clear All Events', function() {
        var func:Void->Void = function() {
          resetSelectedNotes();
          addUndoAction(DELETE_NOTE, {events: events.copy()});

          events = [];
          loadSection();
        }

        if (!ignoreProgressCheckBox.checked) openSubState(new Prompt('Delete all Events in the song?', func));
        else
          func();
      }, btnWid);
      btn.normalStyle.bgColor = FlxColor.RED;
      btn.normalStyle.textColor = FlxColor.WHITE;
      btn.text.alignment = LEFT;
      tab_group.add(btn);
    }
  }

  var showLastGridButton:PsychUIButton;
  var showNextGridButton:PsychUIButton;
  var noteTypeLabelsButton:PsychUIButton;
  var vortexEditorButton:PsychUIButton;

  function addViewTab()
  {
    var tab = upperBox.getTab('View');
    var tab_group = tab.menu;
    var btnX = tab.x - upperBox.x;
    var btnY = 1;
    var btnWid = Std.int(tab.width);

    if (chartEditorSave.data.waveformEnabled != null) waveformEnabled = chartEditorSave.data.waveformEnabled;
    if (chartEditorSave.data.waveformTarget != null) waveformTarget = chartEditorSave.data.waveformTarget;
    if (chartEditorSave.data.waveformColor != null) waveformSprite.color = CoolUtil.colorFromString(chartEditorSave.data.waveformColor);

    showLastGridButton = new PsychUIButton(btnX, btnY, '', function() {
      showPreviousSection = !showPreviousSection;
      updateGridVisibility();
    }, btnWid);
    showLastGridButton.text.alignment = LEFT;
    tab_group.add(showLastGridButton);

    btnY += 20;
    showNextGridButton = new PsychUIButton(btnX, btnY, '', function() {
      showNextSection = !showNextSection;
      updateGridVisibility();
    }, btnWid);
    showNextGridButton.text.alignment = LEFT;
    tab_group.add(showNextGridButton);

    btnY++;
    btnY += 20;
    noteTypeLabelsButton = new PsychUIButton(btnX, btnY, '', function() {
      showNoteTypeLabels = !showNoteTypeLabels;
      updateGridVisibility();
    }, btnWid);
    noteTypeLabelsButton.text.alignment = LEFT;
    tab_group.add(noteTypeLabelsButton);

    btnY++;
    btnY += 20;
    vortexEditorButton = new PsychUIButton(btnX, btnY, vortexEnabled ? '  Vortex Editor ON' : '  Vortex Editor OFF', function() {
      vortexEnabled = !vortexEnabled;
      chartEditorSave.data.vortex = vortexEnabled;
      vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
      vortexEditorButton.text.text = vortexEnabled ? '  Vortex Editor ON' : '  Vortex Editor OFF';
      for (note in strumLineNotes)
      {
        note.playAnim('static');
        note.resetAnim = 0;
      }
      prevGridBg.vortexLineEnabled = gridBg.vortexLineEnabled = nextGridBg.vortexLineEnabled = vortexEnabled;
    }, btnWid);
    vortexEditorButton.text.alignment = LEFT;
    tab_group.add(vortexEditorButton);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Waveform...', function() {
      ClientPrefs.toggleVolumeKeys(false);
      openSubState(new BasePrompt(320, 200, 'Waveform Settings', function(state:BasePrompt) {
        upperBox.isMinimized = true;
        upperBox.bg.visible = false;

        var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
        btn.cameras = state.cameras;
        state.add(btn);

        var check:PsychUICheckBox = new PsychUICheckBox(state.bg.x + 40, state.bg.y + 80, 'Enabled', 60);
        check.onClick = function() {
          chartEditorSave.data.waveformEnabled = waveformEnabled = check.checked;
          updateWaveform();
        };
        check.cameras = state.cameras;
        check.checked = waveformEnabled;
        state.add(check);

        var waveformC:String = '0000FF';
        if (chartEditorSave.data.waveformColor != null) waveformC = chartEditorSave.data.waveformColor;

        var input:PsychUIInputText = new PsychUIInputText(check.x, check.y + 50, 60, waveformC, 10);
        input.onChange = function(old:String, cur:String) {
          chartEditorSave.data.waveformColor = cur;
          waveformSprite.color = CoolUtil.colorFromString(cur);
        }
        input.maxLength = 6;
        input.filterMode = ONLY_HEXADECIMAL;
        input.cameras = state.cameras;
        input.forceCase = UPPER_CASE;

        var options:Array<WaveformTarget> = [INST, PLAYER, OPPONENT];
        var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(check.x + 120, check.y, ['Instrumental', 'Main Vocals', 'Opponent Vocals']);
        radioGrp.cameras = state.cameras;
        radioGrp.onClick = function() {
          waveformTarget = chartEditorSave.data.waveformTarget = options[radioGrp.checked];
          updateWaveform();
        };
        radioGrp.checked = options.indexOf(waveformTarget);
        state.add(radioGrp);

        var txt1:FlxText = new FlxText(input.x, input.y - 15, 80, 'Color (Hex):');
        txt1.cameras = state.cameras;
        state.add(txt1);
        state.add(input);
      }));
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Go to...', function() {
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;
      openSubState(new BasePrompt(420, 200, 'Go to Time/Section:', function(state:BasePrompt) {
        var curTime:Float = Conductor.songPosition;
        var currentSec:Int = curSec;

        var timeStepper:PsychUINumericStepper = new PsychUINumericStepper(state.bg.x + 100, state.bg.y + 90, 1, Math.floor(curTime) / 1000, 0,
          FlxG.sound.music.length / 1000 - 0.01, 2, 80);
        timeStepper.cameras = state.cameras;
        var sectionStepper:PsychUINumericStepper = new PsychUINumericStepper(timeStepper.x + 160, timeStepper.y, 1, currentSec, 0,
          PlayState.SONG.notes.length - 1, 0);
        sectionStepper.cameras = state.cameras;

        var txt1:FlxText = new FlxText(timeStepper.x, timeStepper.y - 15, 100, 'Time (in seconds):');
        var txt2:FlxText = new FlxText(sectionStepper.x, sectionStepper.y - 15, 100, 'Section:');
        txt1.cameras = state.cameras;
        txt2.cameras = state.cameras;
        state.add(txt1);
        state.add(txt2);
        state.add(timeStepper);
        state.add(sectionStepper);

        var timeTxt:FlxText = new FlxText(15, state.bg.y + state.bg.height - 75, 230, '', 16);
        timeTxt.alignment = CENTER;
        timeTxt.screenCenter(X);
        timeTxt.cameras = state.cameras;
        state.add(timeTxt);
        function updateTime()
        {
          var tm:String = FlxStringUtil.formatTime(curTime / 1000, true);
          var ln:String = FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true);
          timeTxt.text = '$tm / $ln';
        }
        updateTime();

        timeStepper.onValueChange = function() {
          curTime = timeStepper.value * 1000;
          for (i => time in cachedSectionTimes)
          {
            if (time <= curTime) currentSec = i;
            else
              break;
          }
          updateTime();
        };
        sectionStepper.onValueChange = function() {
          currentSec = Std.int(sectionStepper.value);
          curTime = cachedSectionTimes[currentSec] + 0.000001;
          updateTime();
        };

        var btn:PsychUIButton = new PsychUIButton(0, timeTxt.y + 30, 'Go To', function() {
          curSec = currentSec;
          FlxG.sound.music.time = FlxMath.bound(curTime, 0, FlxG.sound.music.length - 1);
          loadSection();
          state.close();
        });
        btn.cameras = state.cameras;
        btn.screenCenter(X);
        btn.x -= 60;
        state.add(btn);

        var btn:PsychUIButton = new PsychUIButton(0, btn.y, 'Cancel', state.close);
        btn.cameras = state.cameras;
        btn.screenCenter(X);
        btn.x += 60;
        state.add(btn);
      }));
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY++;
    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Theme...', function() {
      if (!fileDialog.completed) return;
      upperBox.isMinimized = true;
      upperBox.bg.visible = false;

      openSubState(new BasePrompt('Chart Editor Theme', function(state:BasePrompt) {
        var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
        btn.cameras = state.cameras;
        state.add(btn);

        var btnY = 390;
        var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Light', changeTheme.bind(LIGHT));
        btn.screenCenter(X);
        btn.x -= 125;
        btn.cameras = state.cameras;
        state.add(btn);

        var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Default', changeTheme.bind(DEFAULT));
        btn.screenCenter(X);
        btn.cameras = state.cameras;
        state.add(btn);

        var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Dark', changeTheme.bind(DARK));
        btn.screenCenter(X);
        btn.x += 125;
        btn.cameras = state.cameras;
        state.add(btn);
      }));
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);

    btnY += 20;
    var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Reset UI Boxes', function() {
      mainBox.setPosition(mainBoxPosition.x, mainBoxPosition.y);
      eventBox.setPosition(eventBoxPosition.x, eventBoxPosition.y);
      infoBox.setPosition(infoBoxPosition.x, infoBoxPosition.y);
      UIEvent(PsychUIBox.DROP_EVENT, btn); // to force a save
    }, btnWid);
    btn.text.alignment = LEFT;
    tab_group.add(btn);
  }

  function updateChartData()
  {
    for (secNum => section in PlayState.SONG.notes)
      PlayState.SONG.notes[secNum].sectionNotes = [];

    notes.sort(PlayState.sortByTime);
    var noteSec:Int = 0;
    var nextSectionTime:Float = cachedSectionTimes[noteSec + 1];
    var curSectionTime:Float = cachedSectionTimes[noteSec];

    for (num => note in notes)
    {
      if (note == null) continue;

      while (cachedSectionTimes[noteSec + 1] <= note.strumTime)
      {
        noteSec++;
        nextSectionTime = cachedSectionTimes[noteSec + 1];
        curSectionTime = cachedSectionTimes[noteSec];
      }

      var arr:Array<Dynamic> = PlayState.SONG.notes[noteSec].sectionNotes;
      // trace('Added note with time ${note.songData[0]} at section $noteSec');
      arr.push(note.songData);
    }

    events.sort(PlayState.sortByTime);
    PlayState.SONG.events = [];
    for (event in events)
      PlayState.SONG.events.push(event.songData);
  }

  function saveChart(canQuickSave:Bool = true)
  {
    updateChartData();
    var chartData:String = PsychJsonPrinter.print(PlayState.SONG, ['sectionNotes', 'events']);
    if (canQuickSave && Song.chartPath != null)
    {
      File.saveContent(Song.chartPath, chartData);
      showOutput('Chart saved successfully to: ${Song.chartPath}');
    }
    else
    {
      var chartName:String = Paths.formatToSongPath(PlayState.SONG.songId) + '.json';
      if (Song.chartPath != null) chartName = Song.chartPath.substr(Song.chartPath.lastIndexOf('\\')).trim();
      fileDialog.save(chartName, chartData, function() {
        var newPath:String = fileDialog.path;
        Song.chartPath = newPath.replace('/', '\\');
        reloadNotesDropdowns();
        showOutput('Chart saved successfully to: $newPath');
      }, null, function() showOutput('Error on saving chart!', true));
    }
  }

  inline function getCurChartSection()
  {
    return PlayState.SONG.notes != null ? PlayState.SONG.notes[curSec] : null;
  }

  function updateNotesRGB()
  {
    PlayState.SONG.options.disableNoteRGB = noRGBCheckBox.checked ? true : false;

    for (note in notes)
    {
      if (note == null) continue;

      note.setShaderEnabled(noRGBCheckBox.checked ? false : true);
      if (note.rgbShader.enabled)
      {
        var data = backend.NoteTypesConfig.loadNoteTypeData(note.noteType);
        if (data == null || data.length < 1) continue;

        for (line in data)
        {
          var prop:String = line.property.join('.');
          if (prop == 'rgbShader.enabled') note.setShaderEnabled(line.value);
        }
      }
    }
  }

  function updateStrumsRGB()
  {
    PlayState.SONG.options.disableStrumRGB = noStrumRGBCheckBox.checked ? true : false;
    for (note in strumLineNotes)
      note.rgbShader.enabled = noStrumRGBCheckBox.checked ? true : false;
  }

  function updateSplashesRGB()
    PlayState.SONG.options.disableSplashRGB = noSplashRGBCheckBox.checked ? true : false;

  function updateGridVisibility()
  {
    showLastGridButton.text.text = showPreviousSection ? '  Hide Last Section' : '  Show Last Section';
    showNextGridButton.text.text = showNextSection ? '  Hide Next Section' : '  Show Next Section';

    prevGridBg.visible = (curSec > 0 && showPreviousSection);
    nextGridBg.visible = (curSec < PlayState.SONG.notes.length - 1 && showNextSection);

    noteTypeLabelsButton.text.text = showNoteTypeLabels ? '  Hide Note Labels' : '  Show Note Labels';
    for (num => text in MetaNote.noteTypeTexts)
      text.visible = showNoteTypeLabels;
    softReloadNotes();
  }

  function adaptNotesToNewTimes(oldTimes:Array<Float>)
  {
    undoActions = [];
    setSongPlaying(false);
    var gridLerp:Float = FlxMath.bound((scrollY + FlxG.height / 2 - gridBg.y) / gridBg.height, 0.000001, 0.999999);
    notes.sort(PlayState.sortByTime);
    _cacheSections();

    var noteSec:Int = 0;
    var oldNextSectionTime:Float = oldTimes[noteSec + 1];
    var oldCurSectionTime:Float = oldTimes[noteSec];
    var nextSectionTime:Float = cachedSectionTimes[noteSec + 1];
    var curSectionTime:Float = cachedSectionTimes[noteSec];

    for (num => note in notes)
    {
      if (note == null || note.strumTime <= 0) continue;

      while (noteSec + 2 < oldTimes.length && oldTimes[noteSec + 1] <= note.strumTime)
      {
        noteSec++;
        oldNextSectionTime = oldTimes[noteSec + 1];
        oldCurSectionTime = oldTimes[noteSec];
        nextSectionTime = cachedSectionTimes[noteSec + 1];
        curSectionTime = cachedSectionTimes[noteSec];

        if (noteSec + 1 >= cachedSectionTimes.length)
        {
          trace('failsafe, cancel early and delete notes after this');
          var changedSelected:Bool = false;
          for (i in num...notes.length)
          {
            var n = notes[num];
            if (n != null)
            {
              if (selectedNotes.contains(n))
              {
                selectedNotes.remove(n);
                changedSelected = true;
              }
              notes.remove(n);
              note.destroy();
            }
          }
          if (changedSelected) onSelectNote();
          loadSection();
          return;
        }
        // trace('changed section: $noteSec, $oldNextSectionTime, $oldCurSectionTime, $nextSectionTime, $curSectionTime');
      }

      var shouldBound:Bool = (note.strumTime >= oldCurSectionTime && note.strumTime < oldNextSectionTime);
      var strumTime:Float = note.strumTime;

      var ratio:Float = (nextSectionTime - curSectionTime) / (oldNextSectionTime - oldCurSectionTime);
      var adaptedStrumTime:Float = ((note.strumTime - oldCurSectionTime) * ratio) + curSectionTime;
      note.setStrumTime(adaptedStrumTime);
      if (shouldBound) note.setStrumTime(FlxMath.bound(note.strumTime, curSectionTime, nextSectionTime));

      positionNoteYOnTime(note, noteSec);
    }

    for (event in events)
    {
      var secNum:Int = 0;
      for (time in cachedSectionTimes)
      {
        if (time > event.strumTime) break;
        secNum++;
      }
      positionNoteYOnTime(event, secNum);
    }

    var time:Float = FlxMath.remapToRange(gridLerp, 0, 1, cachedSectionTimes[curSec], cachedSectionTimes[curSec + 1]);
    if (Math.isNaN(time))
    {
      time = 0;
      curSec = 0;
    }

    if (FlxG.sound.music != null && time >= FlxG.sound.music.length)
    {
      time = FlxG.sound.music.length - 1;
      curSec = PlayState.SONG.notes.length - 1;
    }
    FlxG.sound.music.time = time;
    Conductor.songPosition = time;
    forceDataUpdate = true;
    loadSection();
  }

  public function UIEvent(id:String, sender:Dynamic)
  {
    trace(id, sender);
    switch (id)
    {
      case PsychUIButton.CLICK_EVENT, PsychUIDropDownMenu.CLICK_EVENT:
        ignoreClickForThisFrame = true;

      case PsychUIBox.CLICK_EVENT:
        ignoreClickForThisFrame = true;
        if (sender == upperBox) updateUpperBoxBg();

      case PsychUIBox.MINIMIZE_EVENT:
        if (sender == upperBox)
        {
          upperBox.bg.visible = !upperBox.isMinimized;
          updateUpperBoxBg();
        }

      case PsychUIBox.DROP_EVENT:
        chartEditorSave.data.mainBoxPosition = [mainBox.x, mainBox.y];
        chartEditorSave.data.eventBoxPosition = [eventBox.x, eventBox.y];
        chartEditorSave.data.infoBoxPosition = [infoBox.x, infoBox.y];
    }
  }

  function updateUpperBoxBg()
  {
    if (upperBox.selectedTab != null)
    {
      var menu = upperBox.selectedTab.menu;
      upperBox.bg.x = upperBox.x + upperBox.selectedIndex * (upperBox.width / upperBox.tabs.length);
      upperBox.bg.setGraphicSize(menu.width, menu.height + 21);
      upperBox.bg.updateHitbox();
    }
  }

  function openEditorPlayState()
  {
    setSongPlaying(false);
    chartEditorSave.flush(); // just in case a random crash happens before loading
    openSubState(new EditorPlayState(cast notes, [vocals, opponentVocals]));
    upperBox.isMinimized = true;
    upperBox.visible = mainBox.visible = infoBox.visible = eventBox.visible = false;
  }

  function goToPlayState()
  {
    persistentUpdate = false;
    FlxG.mouse.visible = false;
    chartEditorSave.flush();

    setSongPlaying(false);
    updateChartData();
    StageData.loadDirectory(PlayState.SONG);
    LoadingState.loadAndSwitchState(new PlayState());
    ClientPrefs.toggleVolumeKeys(true);
  }

  override function openSubState(SubState:FlxSubState)
  {
    if (!persistentUpdate) setSongPlaying(false);
    super.openSubState(SubState);
  }

  override function closeSubState()
  {
    ClientPrefs.toggleVolumeKeys(true);
    super.closeSubState();
    upperBox.isMinimized = true;
    upperBox.visible = mainBox.visible = infoBox.visible = eventBox.visible = true;
    upperBox.bg.visible = false;
    updateAudioVolume();
  }

  override function destroy()
  {
    Note.globalRgbShaders = [];
    backend.NoteTypesConfig.clearNoteTypesData();

    for (num => text in MetaNote.noteTypeTexts)
      text.destroy();

    MetaNote.noteTypeTexts = [];
    fileDialog.destroy();
    super.destroy();
  }

  function loadFileList(mainFolder:String, ?optionalList:String = null, ?fileTypes:Array<String> = null)
  {
    if (fileTypes == null) fileTypes = ['.json'];

    var fileList:Array<String> = [];
    if (optionalList != null)
    {
      for (file in Mods.mergeAllTextsNamed(optionalList))
      {
        file = file.trim();
        if (file.length > 0 && !fileList.contains(file)) fileList.push(file);
      }
    }

    #if MODS_ALLOWED
    for (directory in Mods.directoriesWithFile(Paths.getSharedPath(), mainFolder))
    {
      for (file in FileSystem.readDirectory(directory))
      {
        var path = haxe.io.Path.join([directory, file.trim()]);
        if (!FileSystem.isDirectory(path) && !file.startsWith('readme.'))
        {
          for (fileType in fileTypes)
          {
            var fileToCheck:String = file.substr(0, file.length - fileType.length);
            if (fileToCheck.length > 0 && path.endsWith(fileType) && !fileList.contains(fileToCheck))
            {
              fileList.push(fileToCheck);
              break;
            }
          }
        }
      }
    }
    #end
    return fileList;
  }

  function loadCharacterFile(char:String):CharacterFile
  {
    if (char != null)
    {
      try
      {
        var path:String = Paths.getPath('data/characters/' + char + '.json', TEXT);
        #if MODS_ALLOWED
        var unparsedJson = File.getContent(path);
        #else
        var unparsedJson = OpenFlAssets.getText(path);
        #end
        return cast Json.parse(unparsedJson);
      }
      catch (e:Dynamic) {}
    }
    return null;
  }

  var overwriteSavedSomething:Bool = false;

  function overwriteCheck(savePath:String, overwriteName:String, saveData:String, continueFunc:Void->Void = null, ?continueOnCancel:Bool = false)
  {
    if (FileSystem.exists(savePath))
    {
      openSubState(new Prompt('Overwrite: "$overwriteName"?', function() {
        overwriteSavedSomething = true;
        File.saveContent(savePath, saveData);
        if (continueFunc != null) continueFunc();
      },
        continueOnCancel ? (function() if (continueFunc != null) continueFunc()) : null));
    }
    else
    {
      overwriteSavedSomething = true;
      File.saveContent(savePath, saveData);
      if (continueFunc != null) continueFunc();
    }
  }

  // Undo/Redo stuff
  var undoActions:Array<UndoStruct> = [];
  var currentUndo:Int = 0;

  function addUndoAction(action:UndoAction, data:Dynamic)
  {
    function destroyFromArr(arr:Array<MetaNote>)
    {
      if (arr == null || arr.length < 1) return;

      for (note in arr)
        if (note != null) note.destroy();
    }

    switch (action)
    {
      case ADD_NOTE, SELECT_NOTE:
        FlxG.sound.play(Paths.sound('chartingSounds/noteLay'), 0.7);
      case DELETE_NOTE:
        FlxG.sound.play(Paths.sound('chartingSounds/noteErase'), 0.7);
      case MOVE_NOTE:
        FlxG.sound.play(Paths.sound('chartingSounds/noteLay'));
    }

    // trace('pushed action: $action');
    if (currentUndo > 0) undoActions = undoActions.slice(currentUndo);
    currentUndo = 0;
    undoActions.insert(0, {action: action, data: data});
    while (undoActions.length > 15)
    {
      var lastAction:UndoStruct = undoActions.pop();
      if (lastAction != null)
      {
        switch (lastAction.action)
        {
          case DELETE_NOTE:
            destroyFromArr(lastAction.data.notes);
            destroyFromArr(lastAction.data.events);
          case MOVE_NOTE:
            destroyFromArr(lastAction.data.originalNotes);
            destroyFromArr(lastAction.data.originalEvents);
          default:
        }
      }
    }
  }

  function undo()
  {
    if (isMovingNotes || currentUndo >= undoActions.length)
    {
      FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
      return;
    }

    var action:UndoStruct = undoActions[currentUndo];
    switch (action.action)
    {
      case ADD_NOTE:
        actionRemoveNotes(action.data.notes, action.data.events);

      case DELETE_NOTE:
        actionPushNotes(action.data.notes, action.data.events);

      case MOVE_NOTE:
        actionRemoveNotes(action.data.movedNotes, action.data.movedEvents);
        actionPushNotes(action.data.originalNotes, action.data.originalEvents);

      case SELECT_NOTE:
        resetSelectedNotes();
        selectedNotes = action.data.old;
        onSelectNote();
    }
    showOutput('Undo #${currentUndo + 1}: ${action.action}');
    FlxG.sound.play(Paths.sound('chartingSounds/undo'), 0.7);
    // FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
    currentUndo++;
  }

  function redo()
  {
    if (isMovingNotes || currentUndo < 1)
    {
      FlxG.sound.play(Paths.sound('cancelMenu'), 0.4);
      return;
    }

    currentUndo--;
    var action:UndoStruct = undoActions[currentUndo];
    switch (action.action)
    {
      case ADD_NOTE:
        actionPushNotes(action.data.notes, action.data.events);

      case DELETE_NOTE:
        actionRemoveNotes(action.data.notes, action.data.events);

      case MOVE_NOTE:
        actionRemoveNotes(action.data.originalNotes, action.data.originalEvents);
        actionPushNotes(action.data.movedNotes, action.data.movedEvents);

      case SELECT_NOTE:
        resetSelectedNotes();
        selectedNotes = action.data.current;
        onSelectNote();
    }
    showOutput('Redo #${currentUndo + 1}: ${action.action}');
    FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
  }

  function actionPushNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
  {
    resetSelectedNotes();
    if (dataNotes != null && dataNotes.length > 0)
    {
      for (note in dataNotes)
      {
        if (note != null)
        {
          notes.push(note);
          selectedNotes.push(note);
        }
      }
      notes.sort(PlayState.sortByTime);
    }
    if (dataEvents != null && dataEvents.length > 0)
    {
      for (event in dataEvents)
      {
        if (event != null)
        {
          events.push(event);
          selectedNotes.push(event);
        }
      }
      events.sort(PlayState.sortByTime);
    }
    softReloadNotes();
  }

  function actionRemoveNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
  {
    if (dataNotes != null && dataNotes.length > 0) for (note in dataNotes)
      if (note != null)
      {
        notes.remove(note);
        selectedNotes.remove(note);
      }

    if (dataEvents != null && dataEvents.length > 0) for (event in dataEvents)
      if (event != null)
      {
        events.remove(event);
        selectedNotes.remove(event);
      }

    softReloadNotes();
  }

  function actionReplaceNotes(oldNote:MetaNote, newNote:MetaNote)
  {
    for (act in undoActions)
    {
      for (field in Reflect.fields(act.data))
      {
        var fld:Array<MetaNote> = cast Reflect.field(act.data, field);
        if (fld != null && fld.length > 0) for (num => actNote in fld)
          if (actNote == oldNote) fld[num] = newNote;
      }
    }
  }

  // Ported from the old chart editor
  var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];

  function updateWaveform()
  {
    #if (lime_cffi && !macro)
    if (curSec < 0 || curSec >= cachedSectionTimes.length || !waveformEnabled)
    {
      waveformSprite.visible = false;
      return;
    }

    waveformSprite.visible = true;
    waveformSprite.y = gridBg.y;
    var width:Int = Std.int(GRID_SIZE * GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS);
    var height:Int = Std.int(gridBg.height);
    if (Std.int(waveformSprite.height) != height && waveformSprite.pixels != null)
    {
      waveformSprite.pixels.dispose();
      waveformSprite.pixels.disposeImage();
      waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
    }
    waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);

    wavData[0][0].resize(0);
    wavData[0][1].resize(0);
    wavData[1][0].resize(0);
    wavData[1][1].resize(0);

    var sound:FlxSound = switch (waveformTarget)
    {
      case INST:
        FlxG.sound.music;
      case PLAYER:
        vocals;
      case OPPONENT:
        opponentVocals;
      default:
        null;
    }
    @:privateAccess
    if (sound != null && sound._sound != null && sound._sound.__buffer != null)
    {
      var bytes:Bytes = sound._sound.__buffer.data.toBytes();
      wavData = waveformData(sound._sound.__buffer, bytes, cachedSectionTimes[curSec] - Conductor.offset, cachedSectionTimes[curSec + 1] - Conductor.offset,
        1, wavData, height);
    }

    // Draws
    var gSize:Int = Std.int(GRID_SIZE * 8);
    var hSize:Int = Std.int(gSize / 2);
    var size:Float = 1;

    var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);
    var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);

    var length:Int = leftLength > rightLength ? leftLength : rightLength;

    for (index in 0...length)
    {
      var lmin:Float = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
      var lmax:Float = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

      var rmin:Float = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
      var rmax:Float = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

      waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), index * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.WHITE);
    }
    #else
    waveformSprite.visible = false;
    #end
  }

  function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>,
      ?steps:Float):Array<Array<Array<Float>>>
  {
    #if (lime_cffi && !macro)
    if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

    var khz:Float = (buffer.sampleRate / 1000);
    var channels:Int = buffer.channels;

    var index:Int = Std.int(time * khz);

    var samples:Float = ((endTime - time) * khz);

    if (steps == null) steps = 1280;

    var samplesPerRow:Float = samples / steps;
    var samplesPerRowI:Int = Std.int(samplesPerRow);

    var gotIndex:Int = 0;

    var lmin:Float = 0;
    var lmax:Float = 0;

    var rmin:Float = 0;
    var rmax:Float = 0;

    var rows:Float = 0;

    var simpleSample:Bool = true; // samples > 17200;
    var v1:Bool = false;

    if (array == null) array = [[[0], [0]], [[0], [0]]];

    while (index < (bytes.length - 1))
    {
      if (index >= 0)
      {
        var byte:Int = bytes.getUInt16(index * channels * 2);

        if (byte > 65535 / 2) byte -= 65535;

        var sample:Float = (byte / 65535);

        if (sample > 0) if (sample > lmax) lmax = sample;
        else if (sample < 0) if (sample < lmin) lmin = sample;

        if (channels >= 2)
        {
          byte = bytes.getUInt16((index * channels * 2) + 2);

          if (byte > 65535 / 2) byte -= 65535;

          sample = (byte / 65535);

          if (sample > 0)
          {
            if (sample > rmax) rmax = sample;
          }
          else if (sample < 0)
          {
            if (sample < rmin) rmin = sample;
          }
        }
      }

      v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
      while (simpleSample ? v1 : rows >= samplesPerRow)
      {
        v1 = false;
        rows -= samplesPerRow;

        gotIndex++;

        var lRMin:Float = Math.abs(lmin) * multiply;
        var lRMax:Float = lmax * multiply;

        var rRMin:Float = Math.abs(rmin) * multiply;
        var rRMax:Float = rmax * multiply;

        if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
        else
          array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

        if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
        else
          array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

        if (channels >= 2)
        {
          if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
          else
            array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

          if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
          else
            array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
        }
        else
        {
          if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
          else
            array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

          if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
          else
            array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
        }

        lmin = 0;
        lmax = 0;

        rmin = 0;
        rmax = 0;
      }

      index++;
      rows++;
      if (gotIndex > steps) break;
    }

    return array;
    #else
    return [[[0], [0]], [[0], [0]]];
    #end
  }
}
