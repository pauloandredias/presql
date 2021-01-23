*>==============================================================================
identification division.
*>==============================================================================
function-id.    getWord.
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
    function all intrinsic.

*>==============================================================================
data division.
*>==============================================================================
working-storage section.
01 workingString    pic x(65535) value spaces.
01 maxWordNumber    binary-short value zeros.
01 wordPosition     binary-short value zeros.

linkage section.
01 fullString       pic x any length.
01 wordNumber       binary-short unsigned.
01 wordRetrieved    pic x(00255).

*>==============================================================================
procedure division using fullString, wordNumber returning wordRetrieved.
*>==============================================================================
0-main.

    move trim(fullString) to workingString
    move getWordCount(fullString) to maxWordNumber
    move zeros to wordPosition

    if wordNumber >= 1 and wordNumber <= maxWordNumber  
        perform wordNumber times    
            unstring workingString
                delimited by spaces
                into wordRetrieved count wordPosition 
            move trim(workingString(wordPosition + 1:)) to workingString
        end-perform
    end-if
    
    goback.

end function getWord.
