*>==============================================================================
identification division.
*>==============================================================================
function-id.    getWordCount.
author.         pauloandredias@me.com
date-written.   January, 20th. 2021
*>-------------------------------------------------------------------------------
*>  This function returns the number of words in a string informed as an 
*>  argument. It was compiled by GnuCOBOL version 3.1.1.0.
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
    function all intrinsic.

*>==============================================================================
data division.
*>==============================================================================
working-storage section.
01 subscript        binary-short unsigned value zeros.
01 stringState      pic 9(001)  value zeros.
    88 wasSpace                 value 1 false 0.

linkage section.
01 fullString       pic x any length.
01 wordsCounted     binary-short unsigned.

*>==============================================================================
procedure division using fullString returning wordsCounted.
*>==============================================================================
0-main.

    *> Functions do not accept IS INITIAL clause on function-id
    move zeros to subscript
    move zeros to stringState
    move zeros to wordsCounted

    perform varying subscript from 1 by 1 until subscript > length(fullString)
        if fullString(subscript:1) = spaces 
            set wasSpace to true
        else    
            if subscript = 1
                add 1 to wordsCounted
            else    
                if wasSpace 
                    add 1 to wordsCounted
                    set wasSpace to false
                end-if
            end-if
        end-if
    end-perform

    goback.

end function getWordCount.
