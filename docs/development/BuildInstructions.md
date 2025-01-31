# How to build Slushi Engine:

## Windows:

1. Install [Haxe](https://haxe.org/)
2. Install [Git](https://git-scm.com/)
3. Clone the repository, create a folder for it, and navigate to it, then run the following command: ```git clone https://github.com/Slushi-Github/Slushi-Engine.git```


Setup [Visual Studio](https://aka.ms/vs/17/release/vs_BuildTools.exe) dependencies:

select "Individual Components" and make sure to download the following: 

    "MSVC v143 VS 2022 C++ x64/x86" and "Windows 10/11 SDK"

Setup Haxe libs of the engine:

In you project folder first run the following commands: 

    haxelib install hmm
    haxelib run hmm setup
    hmm install

Setup Hxcpp: 

(This step is optional, hmm install the official Hxcpp library)

SLE use own Hxcpp library, first, install Hxcpp from git, with the following command:

    haxelib git hxcpp https://github.com/Slushi-Github/SLE-hxcpp

Then, navigate to the Hxcpp folder (``yourProject/.haxelib/hxcpp/git/tools/hxcpp/``) and run the following command: 

    haxe compile.hxml

if you try compilate skiping this step, the compiler will mention this step, and the option to automatically execute that command.

Setup Lime with the following command: ``haxelib run lime setup``

Build the engine with the following command: ``lime test windows``

## Linux:
1. Install Haxe, read the [Haxe installation guide for Linux](https://haxe.org/download/linux/) and follow the steps
2. Install Git (they are already installed by default on Linux distros usually)
3. Clone the repository, create a folder for it, and navigate to it, then run the following command: ```git clone https://github.com/Slushi-Github/Slushi-Engine.git```


Setup Haxe libs of the engine:

In you project folder first run the following commands: 

    haxelib install hmm
    haxelib run hmm setup
    hmm install

Setup Hxcpp: 

(This step is optional, hmm install the official Hxcpp library)

SLE use own Hxcpp library, first, install Hxcpp from git, with the following command:

    haxelib git hxcpp https://github.com/Slushi-Github/SLE-hxcpp

Then, navigate to the Hxcpp folder (``yourProject/.haxelib/hxcpp/git/tools/hxcpp/``) and run the following command: 

    haxe compile.hxml

if you try compilate skiping this step, the compiler will mention this step, and the option to automatically execute that command.

Setup Lime with the following command: ``haxelib run lime setup``

Build the engine with the following command: ``lime test linux``