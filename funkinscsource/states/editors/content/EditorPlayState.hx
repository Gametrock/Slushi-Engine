package states.editors.content;

import backend.song.Song;
import backend.song.SongData;
import backend.Rating;
import objects.note.Note;
import objects.note.NoteSplash;
import objects.note.StrumArrow;
import objects.note.Strumline;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.animation.FlxAnimationController;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import backend.Rating;

class EditorPlayState extends MusicBeatSubState
{
  // Borrowed from original PlayState
  var finishTimer:FlxTimer = null;
  var noteKillOffset:Float = 350;
  var spawnTime:Float = 2000;
  var startingSong:Bool = true;
  var playbackRate:Float = 1;
  var vocals:FlxSound;
  var opponentVocals:FlxSound;
  var inst:FlxSound;

  var notes:FlxTypedGroup<Note>;
  var unspawnNotes:Array<Note> = [];

  var strumLineNotes:Strumline;
  var opponentStrums:Strumline;
  var playerStrums:Strumline;
  var grpNoteSplashes:FlxTypedGroup<NoteSplash>;

  var combo:Int = 0;
  var lastRating:FlxSprite;
  var lastCombo:FlxSprite;
  var lastScore:Array<FlxSprite> = [];
  var keysArray:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];

  var songHits:Int = 0;
  var songMisses:Int = 0;
  var songLength:Float = 0;
  var songSpeed:Float = 1;

  var showCombo:Bool = false;
  var showComboNum:Bool = true;
  var showRating:Bool = true;
  // Originals
  var startOffset:Float = 0;
  var startPos:Float = 0;
  var timerToStart:Float = 0;
  var scoreTxt:FlxText;
  var dataTxt:FlxText;
  var guitarHeroSustains:Bool = false;
  var _noteList:Array<Note>;

  public function new(noteList:Array<Note>, allVocals:Array<FlxSound>)
  {
    super();

    /* setting up some important data */
    this.vocals = allVocals[0];
    this.opponentVocals = allVocals[1];
    this._noteList = noteList;
    this.startPos = Conductor.songPosition;
    Conductor.songPosition = startPos;
    playbackRate = FlxG.sound.music.pitch;
  }

  override function create()
  {
    Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * playbackRate;
    Conductor.songPosition -= startOffset;
    startOffset = Conductor.crochet;
    timerToStart = startOffset;
    cachePopUpScore();
    guitarHeroSustains = ClientPrefs.data.newSustainBehavior;
    if (ClientPrefs.data.hitsoundVolume > 0) Paths.sound('hitsound');
    /* setting up Editor PlayState stuff */
    var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.antialiasing = ClientPrefs.data.antialiasing;
    bg.scrollFactor.set();
    bg.color = 0xFF101010;
    bg.alpha = 0.9;
    add(bg);

    /**** NOTES ****/
    strumLineNotes = new Strumline(8);
    add(strumLineNotes);
    grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
    add(grpNoteSplashes);

    var splash:NoteSplash = new NoteSplash(true);
    grpNoteSplashes.add(splash);
    splash.alpha = 0.000001; // cant make it invisible or it won't allow precaching
    opponentStrums = new Strumline(4);
    playerStrums = new Strumline(4);

    generateStaticArrows(0);
    generateStaticArrows(1);

    /***************/

    scoreTxt = new FlxText(10, FlxG.height - 50, FlxG.width - 20, "", 20);
    scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    scoreTxt.scrollFactor.set();
    scoreTxt.borderSize = 1.25;
    scoreTxt.visible = !ClientPrefs.data.hideHud;
    add(scoreTxt);

    dataTxt = new FlxText(10, 580, FlxG.width - 20, "Section: 0", 20);
    dataTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    dataTxt.scrollFactor.set();
    dataTxt.borderSize = 1.25;
    add(dataTxt);
    var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press ESC to Go Back to Chart Editor', 16);
    tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    tipText.borderSize = 2;
    tipText.scrollFactor.set();
    add(tipText);
    RatingWindow.createRatings();
    FlxG.mouse.visible = false;

    generateSong();
    _noteList = null;
    FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
    FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

    #if DISCORD_ALLOWED
    // Updating Discord Rich Presence (with Time Left)
    DiscordClient.changePresence('Playtesting on Chart Editor', PlayState.SONG.song, null, true, songLength);
    #end
    updateScore();
    super.create();
    cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
  }

  override function update(elapsed:Float)
  {
    if (controls.BACK || FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.F12)
    {
      endSong();
      super.update(elapsed);
      return;
    }

    if (startingSong)
    {
      timerToStart -= elapsed * 1000;
      Conductor.songPosition = startPos - timerToStart;
      if (timerToStart < 0) startSong();
    }
    else
    {
      Conductor.songPosition += elapsed * 1000 * playbackRate;
      if (Conductor.songPosition >= 0)
      {
        var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
        Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 2.5));
        if (timeDiff > 1000 * playbackRate) Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
      }
    }
    if (unspawnNotes[0] != null)
    {
      var time:Float = unspawnNotes[0].spawnTime * playbackRate;
      if (songSpeed < 1) time /= songSpeed;
      if (unspawnNotes[0].multSpeed < 1) time /= unspawnNotes[0].multSpeed;
      while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
      {
        var dunceNote:Note = unspawnNotes[0];
        notes.insert(0, dunceNote);
        dunceNote.spawned = true;
        var index:Int = unspawnNotes.indexOf(dunceNote);
        unspawnNotes.splice(index, 1);
      }
    }
    keysCheck();
    if (notes.length > 0)
    {
      var fakeCrochet:Float = (60 / PlayState.SONG.bpm) * 1000;
      notes.forEachAlive(function(daNote:Note) {
        var strumGroup:FlxTypedGroup<StrumArrow> = playerStrums;
        if (!daNote.mustPress) strumGroup = opponentStrums;
        var strum:StrumArrow = strumGroup.members[daNote.noteData];
        daNote.followStrumArrow(strum, fakeCrochet, daNote.noteScrollSpeed / playbackRate);
        if (!daNote.mustPress && daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote) opponentNoteHit(daNote);
        if (daNote.isSustainNote && strum.sustainReduce) daNote.clipToStrumArrow(strum);
        // Kill extremely late notes and cause misses
        if (Conductor.songPosition - daNote.strumTime > noteKillOffset)
        {
          if (daNote.mustPress && !daNote.ignoreNote && (daNote.tooLate || !daNote.wasGoodHit)) noteMiss(daNote);
          daNote.active = daNote.visible = false;
          invalidateNote(daNote);
        }
      });
    }

    var time:Float = CoolUtil.floorDecimal((Conductor.songPosition - ClientPrefs.data.noteOffset) / 1000, 1);
    var songLen:Float = CoolUtil.floorDecimal(songLength / 1000, 1);
    dataTxt.text = 'Time: $time / $songLen' + '\n\nSection: $curSection' + '\nBeat: $curBeat' + '\nStep: $curStep';
    super.update(elapsed);
  }

  var lastBeatHit:Int = -1;

  override function beatHit()
  {
    if (lastBeatHit >= curBeat)
    {
      // trace('BEAT HIT: ' + curBeat + ', LAST HIT: ' + lastBeatHit);
      return;
    }
    notes.sort(FlxSort.byY, ClientPrefs.data.downScroll ? FlxSort.ASCENDING : FlxSort.DESCENDING);
    super.beatHit();
    lastBeatHit = curBeat;
  }

  override function sectionHit()
  {
    if (PlayState.SONG.notes[curSection] != null)
    {
      if (PlayState.SONG.notes[curSection].changeBPM) Conductor.bpm = PlayState.SONG.notes[curSection].bpm;
    }
    super.sectionHit();
  }

  override function destroy()
  {
    FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
    FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
    FlxG.mouse.visible = true;
    super.destroy();
  }

  function startSong():Void
  {
    startingSong = false;
    FlxG.sound.music.onComplete = finishSong;
    FlxG.sound.music.volume = vocals.volume = opponentVocals.volume = 1;
    FlxG.sound.music.play();
    vocals.play();
    opponentVocals.play();
    FlxG.sound.music.time = vocals.time = opponentVocals.time = startPos - Conductor.offset;
    // Song duration in a float, useful for the time left feature
    songLength = FlxG.sound.music.length;
  }

  // Borrowed from PlayState
  function generateSong()
  {
    // FlxG.log.add(ChartParser.parse());
    songSpeed = PlayState.SONG.speed;
    var songSpeedType:String = ClientPrefs.getGameplaySetting('scrolltype');
    switch (songSpeedType)
    {
      case "multiplicative":
        songSpeed = PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
      case "constant":
        songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
    }
    noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
    var songData = PlayState.SONG;
    Conductor.bpm = songData.bpm;
    FlxG.sound.music.volume = vocals.volume = opponentVocals.volume = 0;
    notes = new FlxTypedGroup<Note>();
    add(notes);

    opponentStrums.scrollSpeed = songSpeed;
    playerStrums.scrollSpeed = songSpeed;

    var oldNote:Note = null;
    for (note in _noteList)
    {
      if (note == null || note.strumTime < startPos) continue;

      var idx:Int = _noteList.indexOf(note);
      if (idx != 0)
      {
        // CLEAR ANY POSSIBLE GHOST NOTES
        for (evilNote in unspawnNotes)
        {
          var matches:Bool = (note.noteData == evilNote.noteData
            && note.mustPress == evilNote.mustPress
            && note.noteType == evilNote.noteType);
          if (matches && Math.abs(note.strumTime - evilNote.strumTime) == 0.0)
          {
            evilNote.destroy();
            unspawnNotes.remove(evilNote);
            // continue;
          }
        }
      }

      var swagNote:Note = new Note(note.strumTime, note.noteData, false, PlayState.SONG.options.arrowSkin, oldNote, this, songSpeed,
        note.mustPress ? playerStrums : opponentStrums, false);
      swagNote.setupNote(note.mustPress, note.mustPress ? 1 : 0, 0, note.noteType);
      swagNote.sustainLength = note.sustainLength;
      swagNote.gfNote = note.gfNote;
      swagNote.scrollFactor.set();
      unspawnNotes.push(swagNote);

      var roundSus:Int = Math.floor(swagNote.sustainLength / Conductor.stepCrochet);
      if (roundSus > 0)
      {
        for (susNote in 0...roundSus + 1)
        {
          oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

          var sustainNote:Note = new Note(note.strumTime + (Conductor.stepCrochet * susNote), note.noteData, true, PlayState.SONG.options.arrowSkin, oldNote,
            this, songSpeed, note.mustPress ? playerStrums : opponentStrums, false);
          sustainNote.setupNote(swagNote.mustPress, swagNote.mustPress ? 1 : 0, 0, swagNote.noteType);
          sustainNote.gfNote = swagNote.gfNote;
          sustainNote.scrollFactor.set();
          sustainNote.parent = swagNote;
          unspawnNotes.push(sustainNote);
          swagNote.tail.push(sustainNote);
          sustainNote.correctionOffset = swagNote.height / 2;
          if (!PlayState.isPixelStage)
          {
            if (oldNote.isSustainNote)
            {
              oldNote.scale.y *= Note.SUSTAIN_SIZE / oldNote.frameHeight;
              oldNote.scale.y /= playbackRate;
              oldNote.updateHitbox();
            }
            if (ClientPrefs.data.downScroll) sustainNote.correctionOffset = 0;
          }
          else if (oldNote.isSustainNote)
          {
            oldNote.scale.y /= playbackRate;
            oldNote.updateHitbox();
          }
          if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
          else if (ClientPrefs.data.middleScroll)
          {
            sustainNote.x += 310;
            if (sustainNote.noteData > 1) // Up and Right
              sustainNote.x += FlxG.width / 2 + 25;
          }
        }
      }
      if (swagNote.mustPress)
      {
        swagNote.x += FlxG.width / 2; // general offset
      }
      else if (ClientPrefs.data.middleScroll)
      {
        swagNote.x += 310;
        if (swagNote.noteData > 1) // Up and Right
        {
          swagNote.x += FlxG.width / 2 + 25;
        }
      }
      oldNote = swagNote;
    }
    unspawnNotes.sort(PlayState.sortByTime);
  }

  private function generateStaticArrows(player:Int):Void
  {
    var strumLineX:Float = ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X;
    var strumLineY:Float = ClientPrefs.data.downScroll ? (FlxG.height - 150) : 50;
    for (i in 0...4)
    {
      // FlxG.log.add(i);
      var targetAlpha:Float = 1;
      if (player < 1)
      {
        if (ClientPrefs.data.middleScroll) targetAlpha = 0.35;
      }
      var babyArrow:StrumArrow = new StrumArrow(strumLineX, strumLineY, i, player);
      babyArrow.downScroll = ClientPrefs.data.downScroll;
      babyArrow.alpha = targetAlpha;
      if (player == 1) playerStrums.add(babyArrow);
      else
      {
        if (ClientPrefs.data.middleScroll)
        {
          babyArrow.x += 310;
          if (i > 1)
          { // Up and Right
            babyArrow.x += FlxG.width / 2 + 25;
          }
        }
        opponentStrums.add(babyArrow);
      }
      strumLineNotes.add(babyArrow);
      babyArrow.postAddedToGroup();
    }
  }

  public function finishSong():Void
  {
    if (ClientPrefs.data.noteOffset <= 0)
    {
      endSong();
    }
    else
    {
      finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
        endSong();
      });
    }
  }

  public function endSong()
  {
    notes.forEachAlive(function(note:Note) invalidateNote(note));
    for (note in unspawnNotes)
      if (note != null) invalidateNote(note);
    FlxG.sound.music.pause();
    vocals.pause();
    opponentVocals.pause();
    if (finishTimer != null) finishTimer.destroy();
    Conductor.songPosition = FlxG.sound.music.time = vocals.time = opponentVocals.time = startPos - Conductor.offset;
    close();
  }

  public function getRatesScore(rate:Float, score:Float):Float
  {
    var rateX:Float = 1;
    var lastScore:Float = score;
    var pr = rate - 0.05;
    if (pr < 1.00) pr = 1;

    while (rateX <= pr)
    {
      if (rateX > pr) break;
      lastScore = score + ((lastScore * rateX) * 0.022);
      rateX += 0.05;
    }

    var actualScore = Math.round(score + (Math.floor((lastScore * pr)) * 0.022));

    return actualScore;
  }

  private function cachePopUpScore()
  {
    for (rating in Rating.timingWindows)
      Paths.cacheBitmap(rating.name.toLowerCase());

    for (i in 0...10)
      Paths.image('num' + i);
  }

  private function popUpScore(note:Note = null):Void
  {
    var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition);
    // trace(noteDiff, ' ' + Math.abs(note.strumTime - Conductor.songPosition));
    vocals.volume = 1;
    var placement:String = Std.string(combo);
    var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
    coolText.screenCenter();
    coolText.x = FlxG.width * 0.35;
    var rating:FlxSprite = new FlxSprite();
    var score:Float = 350;
    // tryna do MS based judgment due to popular demand
    var daRating:RatingWindow = Rating.judgeNote(noteDiff / playbackRate, false);
    note.rating = daRating;
    score = daRating.scoreBonus;
    daRating.count++;

    note.canSplash = ((!note.noteSplashData.disabled && ClientPrefs.splashOption('Player') && daRating.doNoteSplash)
      && !PlayState.SONG.options.notITG);
    if (note.canSplash) spawnNoteSplashOnNote(note);

    if (playbackRate >= 1.05) score = getRatesScore(playbackRate, score);

    songHits++;
    updateScore();

    var pixelShitPart1:String = "";
    var pixelShitPart2:String = '';
    rating.loadGraphic(Paths.image(pixelShitPart1 + daRating.name.toLowerCase() + pixelShitPart2));
    rating.screenCenter();
    rating.x = coolText.x - 40;
    rating.y -= 60;
    rating.acceleration.y = 550 * playbackRate * playbackRate;
    rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
    rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
    rating.visible = (!ClientPrefs.data.hideHud && showRating);
    rating.x += ClientPrefs.data.comboOffset[0];
    rating.y -= ClientPrefs.data.comboOffset[1];
    var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'combo' + pixelShitPart2));
    comboSpr.screenCenter();
    comboSpr.x = coolText.x;
    comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
    comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
    comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
    comboSpr.x += ClientPrefs.data.comboOffset[0];
    comboSpr.y -= ClientPrefs.data.comboOffset[1];
    comboSpr.y += 60;
    comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
    insert(members.indexOf(strumLineNotes), rating);

    if (!ClientPrefs.data.comboStacking)
    {
      if (lastRating != null) lastRating.kill();
      lastRating = rating;
    }
    rating.setGraphicSize(Std.int(rating.width * 0.7));
    rating.updateHitbox();
    comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
    comboSpr.updateHitbox();
    var seperatedScore:Array<Int> = [];
    if (combo >= 1000)
    {
      seperatedScore.push(Math.floor(combo / 1000) % 10);
    }
    seperatedScore.push(Math.floor(combo / 100) % 10);
    seperatedScore.push(Math.floor(combo / 10) % 10);
    seperatedScore.push(combo % 10);
    var daLoop:Int = 0;
    var xThing:Float = 0;
    if (showCombo)
    {
      insert(members.indexOf(strumLineNotes), comboSpr);
    }
    if (!ClientPrefs.data.comboStacking)
    {
      if (lastCombo != null) lastCombo.kill();
      lastCombo = comboSpr;
    }
    if (lastScore != null)
    {
      while (lastScore.length > 0)
      {
        lastScore[0].kill();
        lastScore.remove(lastScore[0]);
      }
    }
    for (i in seperatedScore)
    {
      var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelShitPart1 + 'num' + Std.int(i) + pixelShitPart2));
      numScore.screenCenter();
      numScore.x = coolText.x + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
      numScore.y += 80 - ClientPrefs.data.comboOffset[3];

      if (!ClientPrefs.data.comboStacking) lastScore.push(numScore);
      numScore.setGraphicSize(Std.int(numScore.width * 0.5));
      numScore.updateHitbox();
      numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
      numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
      numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
      numScore.visible = !ClientPrefs.data.hideHud;
      // if (combo >= 10 || combo == 0)
      if (showComboNum) insert(members.indexOf(strumLineNotes), numScore);
      FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate,
        {
          onComplete: function(tween:FlxTween) {
            numScore.destroy();
          },
          startDelay: Conductor.crochet * 0.002 / playbackRate
        });
      daLoop++;
      if (numScore.x > xThing) xThing = numScore.x;
    }
    comboSpr.x = xThing + 50;
    /*
      trace(combo);
      trace(seperatedScore);
     */
    coolText.text = Std.string(seperatedScore);
    // add(coolText);
    FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate,
      {
        startDelay: Conductor.crochet * 0.001 / playbackRate
      });
    FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate,
      {
        onComplete: function(tween:FlxTween) {
          coolText.destroy();
          comboSpr.destroy();
          rating.destroy();
        },
        startDelay: Conductor.crochet * 0.002 / playbackRate
      });
  }

  private function onKeyPress(event:KeyboardEvent):Void
  {
    var eventKey:FlxKey = event.keyCode;
    var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);
    // trace('Pressed: ' + eventKey);
    if (!controls.controllerMode)
    {
      #if debug
      // Prevents crash specifically on debug without needing to try catch shit
      @:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return;
      #end

      if (FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
    }
  }

  private function keyPressed(key:Int)
  {
    if (key < 0) return;
    // more accurate hit time for the ratings?
    var lastTime:Float = Conductor.songPosition;
    if (Conductor.songPosition >= 0) Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
    // obtain notes that the player can hit
    var plrInputNotes:Array<Note> = notes.members.filter(function(n:Note) return n != null && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit
      && !n.blockHit && !n.isSustainNote && n.noteData == key);
    plrInputNotes.sort(PlayState.sortHitNotes);
    var shouldMiss:Bool = !ClientPrefs.data.ghostTapping;
    if (plrInputNotes.length != 0)
    { // slightly faster than doing `> 0` lol
      var funnyNote:Note = plrInputNotes[0]; // front note
      // trace('✡⚐🕆☼ 💣⚐💣');
      if (plrInputNotes.length > 1)
      {
        var doubleNote:Note = plrInputNotes[1];
        if (doubleNote.noteData == funnyNote.noteData)
        {
          // if the note has a 0ms distance (is on top of the current note), kill it
          if (Math.abs(doubleNote.strumTime - funnyNote.strumTime) < 1.0) invalidateNote(doubleNote);
          else if (doubleNote.strumTime < funnyNote.strumTime)
          {
            // replace the note if its ahead of time (or at least ensure "doubleNote" is ahead)
            funnyNote = doubleNote;
          }
        }
      }
      goodNoteHit(funnyNote);
    }
    // more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
    Conductor.songPosition = lastTime;
    var spr:StrumArrow = playerStrums.members[key];
    if (spr != null && spr.animation.curAnim.name != 'confirm')
    {
      spr.playAnim('pressed');
      spr.resetAnim = 0;
    }
  }

  private function onKeyRelease(event:KeyboardEvent):Void
  {
    var eventKey:FlxKey = event.keyCode;
    var key:Int = PlayState.getKeyFromEvent(keysArray, eventKey);
    // trace('Pressed: ' + eventKey);
    if (!controls.controllerMode && key > -1) keyReleased(key);
  }

  private function keyReleased(key:Int)
  {
    var spr:StrumArrow = playerStrums.members[key];
    if (spr != null)
    {
      spr.playAnim('static');
      spr.resetAnim = 0;
    }
  }

  // Hold notes
  private function keysCheck():Void
  {
    // HOLDING
    var holdArray:Array<Bool> = [];
    var pressArray:Array<Bool> = [];
    var releaseArray:Array<Bool> = [];
    for (key in keysArray)
    {
      holdArray.push(controls.pressed(key));
      if (controls.controllerMode)
      {
        pressArray.push(controls.justPressed(key));
        releaseArray.push(controls.justReleased(key));
      }
    }
    // TO DO: Find a better way to handle controller inputs, this should work for now
    if (controls.controllerMode && pressArray.contains(true)) for (i in 0...pressArray.length)
      if (pressArray[i]) keyPressed(i);
    // rewritten inputs???
    if (notes.length > 0)
    {
      for (n in notes)
      { // I can't do a filter here, that's kinda awesome
        var canHit:Bool = (n != null && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);
        if (guitarHeroSustains) canHit = canHit && n.parent != null && n.parent.wasGoodHit;
        if (canHit && n.isSustainNote)
        {
          var released:Bool = !holdArray[n.noteData];

          if (!released) goodNoteHit(n);
        }
      }
    }
    // TO DO: Find a better way to handle controller inputs, this should work for now
    if (controls.controllerMode && releaseArray.contains(true)) for (i in 0...releaseArray.length)
      if (releaseArray[i]) keyReleased(i);
  }

  function opponentNoteHit(note:Note):Void
  {
    if (PlayState.SONG.needsVoices && opponentVocals.length <= 0) vocals.volume = 1;
    var strum:StrumArrow = opponentStrums.members[Std.int(Math.abs(note.noteData))];
    if (strum != null)
    {
      strum.playAnim('confirm', true);
      strum.resetAnim = Conductor.stepCrochet * 1.25 / 1000 / playbackRate;
    }
    note.hitByOpponent = true;
    if (!note.isSustainNote) invalidateNote(note);
  }

  function goodNoteHit(note:Note):Void
  {
    if (note.wasGoodHit) return;
    note.wasGoodHit = true;
    if (note.hitsound != null && note.hitsoundVolume > 0 && !note.hitsoundDisabled) FlxG.sound.play(Paths.sound(note.hitsound), note.hitsoundVolume);
    if (note.hitCausesMiss)
    {
      noteMiss(note);
      if (!note.noteSplashData.disabled && !note.isSustainNote) spawnNoteSplashOnNote(note);
      if (!note.isSustainNote) invalidateNote(note);
      return;
    }
    if (!note.isSustainNote)
    {
      combo++;
      if (combo > 9999) combo = 9999;
      popUpScore(note);
    }
    var spr:StrumArrow = playerStrums.members[note.noteData];
    if (spr != null) spr.playAnim('confirm', true);
    vocals.volume = 1;
    if (!note.isSustainNote) invalidateNote(note);
  }

  function noteMiss(daNote:Note):Void
  { // You didn't hit the key and let it go offscreen, also used by Hurt Notes
    // Dupe note remove
    notes.forEachAlive(function(note:Note) {
      if (daNote != note
        && daNote.mustPress
        && daNote.noteData == note.noteData
        && daNote.isSustainNote == note.isSustainNote
        && Math.abs(daNote.strumTime - note.strumTime) < 1) invalidateNote(daNote);
    });
    if (daNote != null && guitarHeroSustains && daNote.parent == null)
    {
      if (daNote.tail.length > 0)
      {
        daNote.alpha = 0.35;
        for (childNote in daNote.tail)
        {
          childNote.alpha = daNote.alpha;
          childNote.missed = true;
          childNote.canBeHit = false;
          childNote.ignoreNote = true;
          childNote.tooLate = true;
        }
        daNote.missed = true;
        daNote.canBeHit = false;
      }
      if (daNote.missed) return;
    }
    if (daNote != null && guitarHeroSustains && daNote.parent != null && daNote.isSustainNote)
    {
      if (daNote.missed) return;

      var parentNote:Note = daNote.parent;
      if (parentNote.wasGoodHit && parentNote.tail.length > 0)
      {
        for (child in parentNote.tail)
          if (child != daNote)
          {
            child.missed = true;
            child.canBeHit = false;
            child.ignoreNote = true;
            child.tooLate = true;
          }
      }
    }
    // score and data
    songMisses++;
    updateScore();
    vocals.volume = 0;
    combo = 0;
  }

  public function invalidateNote(note:Note):Void
  {
    note.kill();
    notes.remove(note, true);
    note.destroy();
  }

  function spawnNoteSplashOnNote(note:Note)
  {
    if (note != null)
    {
      var strum:StrumArrow = playerStrums.members[note.noteData];
      if (strum != null) spawnNoteSplash(note, note.noteData, strum);
    }
  }

  public function spawnNoteSplash(?note:Note = null, data:Int, strum:StrumArrow)
  {
    var splash:NoteSplash = new NoteSplash(false);
    splash.babyArrow = strum;
    splash.spawnSplashNote(note, false);
    grpNoteSplashes.add(splash);
  }

  function updateScore()
    scoreTxt.text = 'Hits: $songHits | Misses: $songMisses';
}
