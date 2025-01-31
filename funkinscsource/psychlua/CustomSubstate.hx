package psychlua;

import flixel.FlxObject;

class CustomSubstate extends MusicBeatSubState
{
  public static var name:String = 'unnamed';
  public static var instance:CustomSubstate;

  #if LUA_ALLOWED
  public static function implement(funk:FunkinLua)
  {
    funk.set("openCustomSubstate", openCustomSubstate);
    funk.set("closeCustomSubstate", closeCustomSubstate);
    funk.set("insertToCustomSubstate", insertToCustomSubstate);
  }
  #end

  public static function openCustomSubstate(name:String, ?pauseGame:Bool = false)
  {
    if (pauseGame)
    {
      FlxG.camera.followLerp = 0;
      PlayState.instance.persistentUpdate = false;
      PlayState.instance.persistentDraw = true;
      PlayState.instance.paused = true;
      if (FlxG.sound.music != null) FlxG.sound.music.pause();
      if (PlayState.instance.vocals != null) PlayState.instance.vocals.pause();
      if (PlayState.instance.opponentVocals != null && PlayState.instance.splitVocals) PlayState.instance.opponentVocals.pause();
    }
    PlayState.instance.openSubState(new CustomSubstate(name));
    PlayState.instance.setOnHScript('customSubstate', instance);
    PlayState.instance.setOnHScript('customSubstateName', name);
    PlayState.instance.setOnHSI('customSubstate', instance);
    PlayState.instance.setOnHSI('customSubstateName', instance);
    PlayState.instance.setOnSCHS('customSubstate', instance);
    PlayState.instance.setOnSCHS('customSubstateName', instance);
  }

  public static function closeCustomSubstate()
  {
    if (instance != null)
    {
      PlayState.instance.closeSubState();
      instance = null;
      return true;
    }
    return false;
  }

  public static function insertToCustomSubstate(tag:String, ?pos:Int = -1)
  {
    if (instance != null)
    {
      var tagObject:FlxObject = cast(MusicBeatState.getVariables(), FlxObject);
      if (tagObject != null)
      {
        if (pos < 0) instance.add(tagObject);
        else
          instance.insert(pos, tagObject);
        return true;
      }
    }
    return false;
  }

  override function create()
  {
    instance = this;
    PlayState.instance.setOnHScript('customSubstate', instance);
    PlayState.instance.setOnHSI('customSubstate', instance);
    PlayState.instance.setOnSCHS('customSubstate', instance);

    PlayState.instance.callOnScripts('onCustomSubstateCreate', [name]);
    super.create();
    PlayState.instance.callOnScripts('onCustomSubstateCreatePost', [name]);
  }

  public function new(name:String)
  {
    CustomSubstate.name = name;
    PlayState.instance.setOnHScript('customSubstateName', name);
    PlayState.instance.setOnHSI('customSubstateName', name);
    PlayState.instance.setOnSCHS('customSubstateName', name);
    super();
    cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
  }

  override function update(elapsed:Float)
  {
    PlayState.instance.callOnScripts('onCustomSubstateUpdate', [name, elapsed]);
    super.update(elapsed);
    PlayState.instance.callOnScripts('onCustomSubstateUpdatePost', [name, elapsed]);
  }

  override function destroy()
  {
    PlayState.instance.callOnScripts('onCustomSubstateDestroy', [name]);
    name = 'unnamed';

    PlayState.instance.setOnHScript('customSubstate', null);
    PlayState.instance.setOnHScript('customSubstateName', name);
    PlayState.instance.setOnHSI('customSubstate', null);
    PlayState.instance.setOnHSI('customSubstateName', name);
    PlayState.instance.setOnSCHS('customSubstate', null);
    PlayState.instance.setOnSCHS('customSubstateName', name);
    super.destroy();
  }
}
