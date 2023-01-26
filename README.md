# Space Invaders in Lua

This is a lua implementation of the famous Space Invaders. I have tried to keep it as close as possible to the original game, have tried to create
similar looking sprites, similar color schemes, and same type of movement. Bonus redship is also available, yaay!.

![GIF](https://github.com/djmgit/space-invaders/blob/master/doc_assets/spaceinvaders.gif)

## Getting the game (archives/binaries)

### for Linux

You can follow one of the two ways to run SpaceInvaders on Linux.

Using the tar archive:

- Download SpaceInvaders.tar.gz and extract the contents.

- Run the ```launch``` present in the root using ```./launch```

Using AppImage:

- Download SpaceInvaders.AppImage

- Make it executable using ```chmod +x SpaceInvaders.AppImage```

- Simply double click it to run it.

### for MacOS

- Download SpaceInvaders-macos-zipped.zip and extract the contents.

- Run SpaceInvaders.app by clinking on it. You will have to mark it as exception in case MacOS does not trust it.

### Windows

- Download SpaceInavders_winx64.zip and extract its contents.

- Run SpaceInvaders.exe by double clicking it.
## How to run from source

This project uses love2d which is a very popular game framework in Lua. You will need to have love2d on your system. You can follow love2d's
official documentation to get it on your system. Once done, you can follow the below steps:

- Open this repository in terminal

- Execute ```love .```

- Love2d window with the game running in it should open.

## What all have been used to make this

- The programming language used is Lua.

- The game library/engine used is Love2d

- For handling and playing animations I have used <a href="https://github.com/kikito/anim8">anim8</a>

- For working with game map I have used <a href="https://github.com/karai17/Simple-Tiled-Implementation">Simple-Tiled-Implementation</a>

- For creating the game map I have used <a href="https://www.mapeditor.org/">Tiled</a>. Do note that this game does not use tiles. However I used
  a game map for easy placement of game sprites on the screen. That way I dont have to dynamically calculate their starting position since they
  are already available in the map.

- For creating the sprites and sprite sheets, I have used Gimp.

- For producing the sounds I have used my old melodica. A melodica is a wind instrument with keyboard like keys mounted on top of it. I recorded the sound
  using my mobile phone.

- For editting the recorded sounds I used <a href="https://www.audacityteam.org/">Audacity</a>
