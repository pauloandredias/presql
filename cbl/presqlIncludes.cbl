*>===============================================================================
identification division.
*>===============================================================================
program-id. presqlIncludes.
*>-------------------------------------------------------------------------------
*> GnuCOBOL SQL pre-compiler
*> Copyright (c) 2021 Paulo Andre Dias (pauloandredias@me.com)
*>
*> This program is part of the "presql" pre-compiler, and is responsible for the
*> expansion of all copybooks mentioned in include statements inside the declare
*> section.
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
    function getWordNumber
    function getWord
    function all intrinsic.

input-output section.
file-control.
    select inputSource assign to inputSourceFileName
    organization is line sequential
    file status is inputSourceFileStatus.

    select copybookSource assign to copybookSourceFileName
    organization is line sequential
    file status is copybookSourceFileStatus.

    select outputSource assign to outputSourceFileName  
    organization is line sequential
    file status is outputSourceFileStatus.

*>===============================================================================
data division.
*>===============================================================================
file section.
fd inputSource.
01 inputSourceLine.
    03 filler                   pic x(255).

fd copybookSource.
01 copybookSourceLine.
    03 filler                   pic x(255).

fd outputSource.
01 outputSourceLine.
    03 filler                   pic x(255).

*>------------------------------------------------------------------------------    
working-storage section.
*>------------------------------------------------------------------------------    
01 fileControlsThatAreNotInLinkage.
    03 outputSourceFileStatus pic x(002)  value spaces.  
    03 copybookSourceFileName   pic x(255)  value spaces.  
    03 copybookSourceFileStatus pic x(002)  value spaces.
        88 copybookSourceEof    value "10".
    
01 flags.
    03 errorFlag                pic 9(001)  value zeros.
        88 itIsOkSoFar          value 0     false 1.
        88 thereWasAnError      value 1     false 0.
    03  declareSectionState     pic 9(001)  value zeros.
        88 insideDeclare        value 1     false 0.
        88 afterDeclare         value 2     false 0.
    03  execSqlState            pic 9(001)  value zeros.
        88 insideExecSql        value 1     false 0.
    03  lineState               pic 9(001)  value zeros.
        88 toggledToComment     value 1     false 0.
    03  copybookProcessing      pic 9(001)  value zeros.
        88 copybookWasFound     value 1     false 0.

01 miscellaneous.
    03  wordNumberOfCopybookName  binary-short unsigned value zeros.
    03  copybookExtensionIndexMax binary-short unsigned value 4.
    03  copybookName              pic x(255) value spaces.

01 copybooksExtensions.
    03 filler                   pic x(004)  value ".cpy".
    03 filler                   pic x(004)  value ".CPY".
    03 filler                   pic x(004)  value ".dcl".
    03 filler                   pic x(004)  value ".DCL".
01 filler redefines copybooksExtensions.
    03 copybookExtension        pic x(004)  occurs 4 indexed by copybookExtensionIndex.

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

01  copybookControls.
    03 copybookDirCount         pic 9(002)  comp-5 value zeros.
    03 copybookDirMax           pic 9(002)  comp-5 value 20.
    03 copybookDirName          pic x(255)  occurs 20.

01 includeResults.
    03 outputSourceFileName     pic x(255)  value spaces.
    03 returnCode               pic 9(001)  value zeros.
        88 everythingWasFine    value 0     false 1.
        88 somethingWentWrong   value 1     false 0.

*>==================================================================================================
procedure division using sourceFileControls, runningOptions, copybookControls, includeResults. 
*>==================================================================================================
0-main.

    perform 1-open-files
    if itIsOkSoFar    
        read inputSource next record at end set inputSourceEof to true end-read
        perform 2-search-includes until inputSourceEof
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
            display MODULE-ID " (ERROR): Opening " trim(inputSourceFileName) " failed with file-status " inputSourceFileStatus upon stderr
            set thereWasAnError to true
            exit paragraph
        else
            if runningModeIsVerbose
                display MODULE-ID " (info): Opening " trim(inputSourceFileName) 
            end-if
        end-if            
    end-if

    string trim(inputSourceFileName) ".presql.step1" into outputSourceFileName  

    open output outputSource
    if outputSourceFileStatus not = "00"
        display MODULE-ID " (ERROR): Opening " trim(outputSourceFileName  ) " failed with file-status " outputSourceFileStatus upon stderr
        set thereWasAnError to true
        exit paragraph
    else
        if runningModeIsVerbose
            display MODULE-ID " (info): Opening " trim(outputSourceFileName  )
        end-if
    end-if.

*>------------------------------------------------------------------------------    
*> Locates include instructions, opens the correspondent copybook (trying each
*> diretory and each possible extension) and insert its lines into the expanded
*> source code
*>------------------------------------------------------------------------------    
2-search-includes.

    *> If declare section was already processed, just copy the original line
    if not afterDeclare
        *> Comment lines will be ignored
        if (sourceFormatIsFixed and inputSourceLine(7:1) not = "*") or
           (sourceFormatIsFree and trim(inputSourceLine)(1:2) not = "*>")
            if getWordNumber(inputSourceLine, "exec") > zeros and
               getWordNumber(inputSourceLine, "sql") > zeros
                set insideExecSql to true
                perform 21-toggle-to-comment
                set toggledToComment to true
            end-if
            if insideExecSql
                if getWordNumber(inputSourceLine, "begin") > zeros and
                   getWordNumber(inputSourceLine, "declare") > zeros and
                   getWordNumber(inputSourceLine, "section") > zeros
                    if runningModeIsVerbose
                        display MODULE-ID " (info): Begin Declare Section was found"
                    end-if
                    set insideDeclare to true
                    perform 21-toggle-to-comment
                    move "#presqlBeginDeclareSection" to outputSourceLine
                    perform 23-insert-tag-line
                else
                    if getWordNumber(inputSourceLine, "include") > zeros
                        if runningModeIsVerbose
                            display MODULE-ID " (info): An include was found"
                        end-if
                        perform 21-toggle-to-comment
                        move "#presqlIncludes" to outputSourceLine
                        perform 23-insert-tag-line                        
                        perform 22-look-for-copybook
                    else
                        if getWordNumber(inputSourceLine, "end") > zeros and
                           getWordNumber(inputSourceLine, "declare") > zeros and
                           getWordNumber(inputSourceLine, "section") > zeros
                            if runningModeIsVerbose
                                display MODULE-ID " (info): End Declare Section was found"
                            end-if
                            perform 21-toggle-to-comment
                            move "#presqlEndDeclareSection" to outputSourceLine
                            perform 23-insert-tag-line  
                            set insideDeclare to false                                                  
                        end-if  
                    end-if
                end-if
                if getWordNumber(inputSourceLine, "end-exec") > 0 or
                   getWordNumber(inputSourceLine, "end-exec.") > 0 
                    if runningModeIsVerbose
                        display MODULE-ID " (info): End Exec was found"
                    end-if
                    perform 21-toggle-to-comment
                    set insideExecSql to false
                    if not insideDeclare
                        set afterDeclare to true
                    end-if
                end-if
            else    
                write outputSourceLine from inputSourceLine
            end-if
        else
            write outputSourceLine from inputSourceLine
        end-if
    else
        write outputSourceLine from inputSourceLine
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
*> Will look for the copybook considering all directories informed as arguments
*> and all possible copybook extensions. It expects that the copybook name
*> is in the same line of the include command.
*>------------------------------------------------------------------------------    
22-look-for-copybook.

    add 1 to getWordNumber(inputSourceLine, "include") giving wordNumberOfCopybookName
    move getWord(inputSourceLine, wordNumberOfCopybookName) to copybookName

    if runningModeIsVerbose
        display MODULE-ID " (info): Copybook name is " trim(copybookName) 
    end-if

    set copybookWasFound to false
    perform 221-try-all-copybook-directories
        varying copybookDirCount from 1 by 1 
               until copybookDirCount > copybookDirMax 
                  or copybookDirName(copybookDirCount) = spaces
                  or copybookWasFound

    if not copybookWasFound
        display MODULE-ID " (ERROR): Copybook " trim(copybookName) " was not found in any directory with any possible extensions"
        set thereWasAnError to true
        exit paragraph
    end-if.

*>------------------------------------------------------------------------------    
*> For each copybook directory informed as arguments try with all possible
*> copybook extensions.
*>------------------------------------------------------------------------------    
221-try-all-copybook-directories.

    perform 2211-try-all-copybook-extensions 
            varying copybookExtensionIndex from 1 by 1 
              until copybookExtensionIndex > copybookExtensionIndexMax
                 or copybookExtension(copybookExtensionIndex) = spaces
                 or copybookWasFound.

*>------------------------------------------------------------------------------    
*> Concatenate a copybook diretory with the copybook name mentioned by the
*> include command plus one of the possible extensions and tries to open the
*> file. If successful, will import all the records of the copybook into the
*> expanded source.
*>------------------------------------------------------------------------------    
2211-try-all-copybook-extensions.

    move concatenate(trim(copybookDirName(copybookDirCount)), 
                     "/", 
                     trim(copybookName), 
                     copybookExtension(copybookExtensionIndex)) to copybookSourceFileName
    
    if runningModeIsVerbose
        display MODULE-ID " (info): Looking for copybook in " trim(copybookSourceFileName) 
    end-if
    
    open input copybookSource
    if copybookSourceFileStatus = "00"
        read copybookSource next record at end set copybookSourceEof to true end-read
        perform until copybookSourceEof
            write outputSourceLine from copybookSourceLine
            read copybookSource next record at end set copybookSourceEof to true end-read
        end-perform
        close copybookSource
        set copybookWasFound to true
        if runningModeIsVerbose
            display MODULE-ID " (info): Copybook " trim(copybookName) " was imported"
        end-if
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
        display MODULE-ID " (info): Closing " trim(outputSourceFileName  )
    end-if.
            
   