# VMU Frame Sync
This small example program uses the base timer in direct quartz mode to provide your application a perfect vertical sync with the LCD

<br><p align="left"><img src="https://github.com/jvsTSX/vmu-frame-sync/blob/main/repo_images/5_shades.png?" alt="The game's user interface with annotations" width="657" height="743"/>

## Requirements For Your App
- Run on the 1MHz mode, anything slower is not guaranteed to work
- You must not be previously using the Base Timer for anything other than RTC interrupts, this routine allows you to keep a seconds-rate RTC just fine (bit 5 of Flags)
- Have at least 3 bytes of RAM to spare (the other bytes are for the example program)

## Controls
- **D-pad Left/Right**: Change the image.
- **D-pad Up/Down**: Change the display mode between 3-shade, 5-shade and checkerboarded variants, different modes may have different images.
- **Mode Button**: Exit back to the BIOS
- **Sleep Button**: Enter an initial delay value before drawing to the screen. This is useless for checkerboarded modes, but affects the unevenly bright zones on the progressive modes. When inside this mode just press the sleep button to exit it, D-pad now selects the delay number with Right/Left selecting the low number and Up/Down the high number.

## Specifics
This program runs entirely off the 1MHz clock after it finishes initializing the LCD to ensure sync, THIS MEANS IT USES A LOT OF BATTERY POWER, a triple-A adapter or USB power mod is recommended.
- **Size**: 26 Blocks (of 512 bytes each), or 13312 bytes
- **Version**: This is a test app, so no exact versions (note that i am not using the github release versions, the build is also part of the repo if you don't want to build it)

## Emulation Support
- Elysian VMU won't run this at the correct rate, but it will run it still, just very slow.
- VM2 works fine (Chris fixed it!), a bit flickery but the effect still works very well.
