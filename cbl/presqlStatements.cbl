*>===============================================================================
identification division.
*>===============================================================================
program-id. presqlStatements.
*>-------------------------------------------------------------------------------
*> GnuCOBOL SQL pre-compiler
*> Copyright (c) 2021 Paulo Andre Dias (pauloandredias@me.com)
*>
*> This program is part of the presql pre-compiler and is responsible for
*> extracting all sql statements of the procedure division. 
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

*>===============================================================================
environment division.
*>===============================================================================
configuration section.
repository.
    function getWord
    function getWordCount
    function getWordNumber
    function all intrinsic.

input-output section.
file-control.
    select inputSource assign to inputSourceFileName
    organization is line sequential
    file status is inputSourceFileStatus.

    select outputSource assign to outputSourceFileName
    organization is line sequential
    file status is outputSourceFileStatus.

    select sqlStatementFile assign to sqlStatementFileName
    organization is line sequential
    file status is sqlStatementFileStatus.


*>===============================================================================
data division.
*>===============================================================================
file section.
fd inputSource.
01 inputSourceLine.
    03 filler                   pic x(255).

fd outputSource.
01 outputSourceLine.
    03 filler                   pic x(255).

fd sqlStatementFile.
01 sqlStatementLine.
    03 filler                   pic x(255).

*>------------------------------------------------------------------------------    
working-storage section.
*>------------------------------------------------------------------------------    
01 flags.
    03 errorFlag                pic 9(001)  value zeros.
        88 itIsOkSoFar          value 0     false 1.
        88 thereWasAnError      value 1     false 0.
    03  programState            pic 9(001)  value zeros.
        88 insideProcedure      value 1     false 0.
    03  execSqlState            pic 9(001)  value zeros.
        88 insideExecSql        value 1     false 0.
    03  lineState               pic 9(001)  value zeros.
        88 toggledToComment     value 1     false 0.

01  sqlStatements.
    03 sqlStatementFileName     pic x(255) value spaces.
    03 sqlStatementFileStatus   pic x(002) value spaces.
    03 sqlStatement             pic x(65535) value spaces.
    03 tmpWord                  pic x(255) value spaces.
    03 wordsInLine              binary-short unsigned value zeros.
    03 wordCount                binary-short unsigned value zeros.
    03 sqlStatementPointer      binary-short unsigned value zeros.
    03 sqlStatementNumber       pic 9(003) value zeros.

01 miscellaneous.
    03 outputSourceFileStatus   pic x(002) value spaces.

*>------------------------------------------------------------------------------    
linkage section.
*>------------------------------------------------------------------------------    
01 sourceFileControls.
    03  inputSourceFileName     pic x(255)  value spaces.
    03  inputSourceFileStatus   pic x(002)  value spaces.
        88 inputSourceEof       value "10"  false "00".
        88 inputSourceNotFound  value "35"  false "00".

01 runningOptions.
    03 quoteCharacter           pic x(001)  value "'".
    03 sourceFormat             pic 9(001)  value zeros.
        88 sourceFormatIsFree   value 0     false 1.
        88 sourceFormatIsFixed  value 1     false 0.
    03 runningMode              pic 9(001)  value zeros.
        88 runningModeIsQuiet   value 0     false 1.
        88 runningModeIsVerbose value 1     false 0.

01 thisProgramResults.
    03 outputSourceFileName   pic x(255)  value spaces.
    03 returnCode               pic 9(001)  value zeros.
        88 everythingWasFine    value 0     false 1.
        88 somethingWentWrong   value 1     false 0.

*>==================================================================================================
procedure division using sourceFileControls, runningOptions, thisProgramResults. 
*>==================================================================================================
0-main.

    perform 1-open-files
    if itIsOkSoFar    
        read inputSource next record at end set inputSourceEof to true end-read
        perform 2-search-statements until inputSourceEof or thereWasAnError
        perform 3-close-files
    end-if      

    if thereWasAnError
        set somethingWentWrong to true
    else
        set everythingWasFine to true
    end-if

    goback.

*>------------------------------------------------------------------------------    
*> Open input and output source programs
*>------------------------------------------------------------------------------    
1-open-files.

    open input inputSource
    if inputSourceNotFound
        display MODULE-ID " (ERROR): Program " trim(inputSourceFileName) " not found" upon stderr
        set thereWasAnError to true
        exit paragraph
    else    
        if inputSourceFileStatus not = "00"
            display MODULE-ID " (ERROR): Open " trim(inputSourceFileName) " failed with file-status " inputSourceFileStatus upon stderr
            set thereWasAnError to true
            exit paragraph
        else
            if runningModeIsVerbose
                display MODULE-ID " (info): Opening " trim(inputSourceFileName) 
            end-if
        end-if            
    end-if

    move substitute(inputSourceFileName, ".presql.step1", ".presql.step2") to outputSourceFileName 

    open output outputSource
    if outputSourceFileStatus not = "00"
        display MODULE-ID " (ERROR): Open " trim(outputSourceFileName) " failed with file-status " outputSourceFileStatus upon stderr
        set thereWasAnError to true
        exit paragraph
    else
        if runningModeIsVerbose
            display MODULE-ID " (info): Opening " trim(outputSourceFileName)
        end-if
    end-if.

*>------------------------------------------------------------------------------    
*> Locates exec sql statements, copy their contents to an external file, toggle
*> their lines to a comment and tag the source making the next steps easier
*>------------------------------------------------------------------------------    
2-search-statements.

    *> Comments and blank lines will just be copied to the output file
    if (sourceFormatIsFixed and inputSourceLine(7:1) = "*") or
       (sourceFormatIsFree and trim(inputSourceLine)(1:2) = "*>") or
       (inputSourceLine = spaces)
       write outputSourceLine from inputSourceLine
    else
        if getWordNumber(inputSourceLine, "procedure") > zeros and
           getWordNumber(substitute(inputSourceLine, ".", " "), "division") > zeros
           set insideProcedure to true
        end-if
        *> if before procedure division just copy the line to the output file
        if not insideProcedure
            write outputSourceLine from inputSourceLine
        else
            *> Check if it is an "exec sql" 
            if getWordNumber(inputSourceLine, "exec") > zeros and
               getWordNumber(inputSourceLine, "sql") > zeros
                set insideExecSql to true
                perform 21-toggle-to-comment
                set toggledToComment to true
                move spaces to sqlStatement
            end-if
            *> if it is not inside an "exec sql" just copy the line to the output file
            if not insideExecSql
                write outputSourceLine from inputSourceLine
            else
                *> Join all the words of the statements until end-exec
                move getWordCount(inputSourceLine) to wordsInLine
                perform varying wordCount from 1 by 1 until wordCount > wordsInLine
                    move getWord(inputSourceLine, wordCount) to tmpWord
                    move concatenate(trim(sqlStatement), " ", trim(tmpWord)) to sqlStatement
                end-perform
                perform 21-toggle-to-comment
                if getWordNumber(inputSourceLine, "end-exec") > 0 or
                   getWordNumber(inputSourceLine, "end-exec.") > 0
                    perform 21-toggle-to-comment
                    set insideExecSql to false
                    *> Write the statement to an external file that will be used later
                    perform 22-save-the-statement
                    if thereWasAnError
                        exit paragraph
                    else
                        move concatenate("#presqlStatement ", sqlStatementNumber) to outputSourceLine
                        perform 23-insert-tag-line
                    end-if
                end-if
            end-if
        end-if
    end-if
        
    read inputSource next record at end set inputSourceEof to true end-read
    set toggledToComment to false.

*>------------------------------------------------------------------------------    
*> This paragraph will transform the original line to a comment line. The line
*> might be toggled before (i.e when exec sql and end-exec are in the same line).
*> For this reason, the program checks the conditional name "toggledToComment".
*>------------------------------------------------------------------------------    
21-toggle-to-comment.

    if not toggledToComment     
        if sourceFormatIsFixed
            move concatenate("      *", inputSourceLine(8:)) to outputSourceLine
        else
            move concatenate("*> ", inputSourceLine) to outputSourceLine
        end-if
        write outputSourceLine
        set toggledToComment to true
    end-if.

*>------------------------------------------------------------------------------    
*> Write the sql statement to an external file that will be used in a later step
*>------------------------------------------------------------------------------    
22-save-the-statement.

    add 1 to sqlStatementNumber

    move concatenate(trim(substitute(inputSourceFileName, ".presql.step1", ".presql.stmt.")), sqlStatementNumber) to sqlStatementFileName

    open output sqlStatementFile
    if sqlStatementFileStatus not = "00"
        display MODULE-ID " (ERROR): It was not possible to open file " trim(sqlStatementFileName) ". File Status is " sqlStatementFileStatus upon stderr
        set thereWasAnError to true
        exit paragraph
    else
        if runningModeIsVerbose
            display MODULE-ID " (info): Opening file " trim(sqlStatementFileName) 
        end-if
    end-if

    if runningModeIsVerbose
        display MODULE-ID " (info): Writing statement " sqlStatementNumber " [" trim(sqlStatement) "]"
    end-if

    *> Split the statement each 255 characters
    perform varying sqlStatementPointer from 1 by 255 until sqlStatementPointer > stored-char-length(sqlStatement)
        move sqlStatement(sqlStatementPointer:255) to sqlStatementLine
        write sqlStatementLine
    end-perform

    close sqlStatementFile.
    if runningModeIsVerbose
        display MODULE-ID " (info): Closing file " trim(sqlStatementFileName) 
    end-if.

*>------------------------------------------------------------------------------    
*> Theses tags will facilitate the work of the next programs
*>------------------------------------------------------------------------------    
23-insert-tag-line.

    if sourceFormatIsFixed
        move concatenate("      *", outputSourceLine) to outputSourceLine
    else
        move concatenate("*> ", outputSourceLine) to outputSourceLine
    end-if

    write outputSourceLine.

*>------------------------------------------------------------------------------    
*> Close input and output program
*>------------------------------------------------------------------------------    
3-close-files.

    close inputSource 
    if runningModeIsVerbose
        display MODULE-ID " (info): Closing " trim(inputSourceFileName)
    end-if

    close outputSource
    if runningModeIsVerbose
        display MODULE-ID " (info): Closing " trim(outputSourceFileName)
    end-if.
            
   