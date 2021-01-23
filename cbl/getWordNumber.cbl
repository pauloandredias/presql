*>==============================================================================
identification division.
*>==============================================================================
function-id.    getWordNumber.
author.         pauloandredias@me.com
date-written.   January, 20th. 2021
*>-------------------------------------------------------------------------------
*>  This function returns a word inside a string based on the word number informed
*>  as an argument. It was compiled by GnuCOBOL version 3.1.1.0.
*> 
*>  This program is free software; you can redistribute it and/or modify
*>  it under the terms of the GNU General Public License as published by
*>  the Free Software Foundation; either version 2, or (at your option)
*>  any later version.
*>  
*>  This program is distributed in the hope that it will be useful,
*>  but WITHOUT ANY WARRANTY; without even the implied warranty of
*>  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*>  GNU General Public License for more details.
*>-------------------------------------------------------------------------------

*>==============================================================================
environment division.
*>==============================================================================
configuration section.
repository.
    function getWordCount
    function getWord
    function all intrinsic.

*>==============================================================================
data division.
*>==============================================================================
working-storage section.
01 workingString    pic x(65535) value spaces.
01 subscript        binary-short unsigned value zeros.
01 maxWordNumber    binary-short unsigned value zeros.

linkage section.
01 fullString       pic x any length.
01 wordToFind       pic x any length.
01 wordNumberFound  binary-short unsigned.

*>==============================================================================
procedure division using fullString, wordToFind returning wordNumberFound.
*>==============================================================================
0-main.

    move fullString to workingString
    move getWordCount(fullString) to maxWordNumber
    move zeros to wordNumberFound

    perform varying subscript from 1 by 1 until subscript > maxWordNumber
        if getWord(fullString, subscript) = wordToFind  
            move subscript to wordNumberFound
            exit perform
        end-if
    end-perform
    
    *> display "getWordNumber: [" trim(fullString) "] [" trim(wordToFind) "] [" wordNumberFound "] [" maxWordNumber "]"
    goback.

end function getWordNumber.
