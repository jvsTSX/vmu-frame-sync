# VMU Frame Sync
This small example routine uses the base timer in direct quartz mode to provide your application a perfect vertical sync with the LCD
## Requirements
- Your app must run on the 1MHz mode, anything slower is not guaranteed to work
- You must not be previously using the Base Timer for anything other than RTC interrupts, this routine allows you to keep a seconds-rate RTC just fine (bit 5 of Flags)
- Have at least 3 bytes of RAM to spare (the other bytes are for the example program)
