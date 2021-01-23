*>===============================================================================
identification division.
*>===============================================================================
program-id. presql.
*>-------------------------------------------------------------------------------
*> GnuCOBOL SQL pre-compiler
*> Copyright (c) 2021 Paulo Andre Dias (pauloandredias@me.com)
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
    function all intrinsic.

*>===============================================================================
data division.
*>===============================================================================

*>------------------------------------------------------------------------------    
working-storage section.
*>------------------------------------------------------------------------------    
01 sourceFileControls.
    03  inputSourceFileName     pic x(255)  value spaces.
    03  inputSourceFileStatus   pic x(002)  value spaces.
        88 inputSourceEof       value "10"  false "00".
        88 inputSourceNotFound  value "35"  false "00".
    03  outputSourceFileName    pic x(255)  value spaces.
    03  outputSourceFileStatus  pic x(002)  value spaces.  

01 argumentControls.
    03 argumentCount            pic 9(003)  value zeros.
    03 argumentNumber           pic 9(003)  value zeros.
    03 argumentText             pic x(255)  value spaces.
    03 argumentState            pic x(002)  value spaces.
        88 argumentIs-s         value "-s"  false spaces. *> Specify the input source program
        88 argumentIs-o         value "-o"  false spaces. *> Specify the output source program
        88 argumentIs-i         value "-i"  false spaces. *> Inform a copybook directory to consider on include commands
        88 argumentIs-q         value "-q"  false spaces. *> Use double quotes in strings
        88 argumentIs-f         value "-f"  false spaces. *> Read and write cobol sources in fixed format (free format is default)
        88 argumentIs-v         value "-v"  false spaces. *> Verbose running mode

01  copybookControls.
    03 copybookDirCount         pic 9(002)  comp-5 value zeros.
    03 copybookDirMax           pic 9(002)  comp-5 value zeros.
    03 copybookDirName          pic x(255)  occurs 20.

01 runningOptions.
    03 quoteCharacter           pic x(001)  value "'".
    03 sourceFormat             pic 9(001)  value zeros.
        88 sourceFormatIsFree   value 0     false 1.
        88 sourceFormatIsFixed  value 1     false 0.
    03 runningMode              pic 9(001)  value zeros.
        88 runningModeIsQuiet   value 0     false 1.
        88 runningModeIsVerbose value 1     false 0.

01 miscellaneous.
    03 errorFlag                pic 9(001)  value zeros.
        88 itIsOkSoFar          value 0     false 1.
        88 thereWasAnError      value 1     false 0.

01  sqlcaLines.
    03  filler                  pic x(080) value "01 sqlca.".
	03  filler                  pic x(080) value "    05 sqlstate pic x(5).".
	03  filler                  pic x(080) value "       88  sql-success               value %%00000%%.".
	03  filler                  pic x(080) value "       88  sql-right-trunc           value %%01004%%.".
	03  filler                  pic x(080) value "       88  sql-nodata                value %%02000%%.".
	03  filler                  pic x(080) value "       88  sql-duplicate             value %%23000%% thru %%23999%%.".
	03  filler                  pic x(080) value "       88  sql-multiple-rows         value %%21000%%.".
	03  filler                  pic x(080) value "       88  sql-null-no-ind           value %%22002%%.".
	03  filler                  pic x(080) value "       88  sql-invalid-cursor-state  value %%24000%%.". 
	03  filler                  pic x(080) value "    05 filler                        pic  x(001).".
	03  filler                  pic x(080) value "    05 sqlversn                      pic  9(002) value 02.".
	03  filler                  pic x(080) value "    05 sqlcode                       pic s9(009) comp-5.".
	03  filler                  pic x(080) value "    05 sqlerrm.".
	03  filler                  pic x(080) value "        49 sqlerrml                  pic s9(004) comp-5.".
	03  filler                  pic x(080) value "        49 sqlerrmc                  pic  x(486).".
    03  filler                  pic x(080) value "    05 sqlerrd                       pic s9(009) comp-5 occurs 6.".
01  filler redefines sqlcaLines.
    03 sqlcaLine                pic x(080) occurs 16.

01 odbcSubprograms.
	03  filler                  pic x(080) value "77 ocsql                             pic x(008) value %%ocsql%%.".
	03  filler                  pic x(080) value "77 ocsqldis                          pic x(008) value %%ocsqldis%%.".
	03  filler                  pic x(080) value "77 ocsqlpre                          pic x(008) value %%ocsqlpre%%.".
	03  filler                  pic x(080) value "77 ocsqlexe                          pic x(008) value %%ocsqlexe%%.".
	03  filler                  pic x(080) value "77 ocsqlrbk                          pic x(008) value %%ocsqlrbk%%.".
	03  filler                  pic x(080) value "77 ocsqlcmt                          pic x(008) value %%ocsqlcmt%%.".
	03  filler                  pic x(080) value "77 ocsqlimm                          pic x(008) value %%ocsqlimm%%.".
	03  filler                  pic x(080) value "77 ocsqlocu                          pic x(008) value %%ocsqlocu%%.".
	03  filler                  pic x(080) value "77 ocsqlccu                          pic x(008) value %%ocsqlccu%%.".
	03  filler                  pic x(080) value "77 ocsqlftc                          pic x(008) value %%ocsqlftc%%.".
01  filler redefines odbcSubprograms.
    03 odbcSubprogram           pic x(080) occurs 10.

01 otherSqlVariables.
    03  filler                  pic x(080) value "01 sqlv.".
    03  filler                  pic x(080) value "   03 sql-arrsz                      pic s9(007) comp-5 value 6.".
    03  filler                  pic x(080) value "   03 sql-count                      pic s9(007) comp-5.".
    03  filler                  pic x(080) value "   03 sql-addr                       pointer occurs 6.".
    03  filler                  pic x(080) value "   03 sql-len                        pic s9(007) comp-5 occurs 6.".
    03  filler                  pic x(080) value "   03 sql-type                       pic  x(001) occurs 6.".
    03  filler                  pic x(080) value "   03 sql-prec                       pic  x(001) occurs 6.".                  
01  filler redefines otherSqlVariables.
    03 otherSqlVariable         pic x(080) occurs 7.

*>===============================================================================
procedure division.
*>===============================================================================
0-main.

    perform 1-get-arguments
    if itIsOkSoFar    
        perform 2-open-sources
        if itIsOkSoFar           
            read inputSource next record at end set inputSourceEof to true end-read
            perform 3-split-sql-statements until inputSourceEof
            perform 4-close-sources
            if itIsOkSoFar
                perform 2-open-sources
                if itIsOkSoFar
                    read inputSource next record at end set inputSourceEof to true end-read
                    perform 5-generate-output-source until inputSourceEof
                    perform 4-close-sources
                end-if    
            end-if
        end-if
    end-if      

    if thereWasAnError
        move 12 to return-code
    else
        move zeros to return-code
    end-if

    stop run.

*>------------------------------------------------------------------------------    
*> Receive and validate arguments from command line
*>------------------------------------------------------------------------------    
1-get-arguments.

    accept argumentCount from argument-number
    if argumentCount = zeros
        display MODULE-ID " (ERROR): No arguments found" upon stderr
        set thereWasAnError to true
        exit paragraph
    end-if

    perform 11-read-command-line
        varying argumentNumber from 1 by 1
          until argumentNumber > argumentCount    

    if thereWasAnError 
        exit paragraph  
    else
        if runningModeIsVerbose
            display MODULE-ID " (info): Input program.........: " trim(inputSourceFileName)
            display MODULE-ID " (info): Output program........: " trim(outputSourceFileName)
            display MODULE-ID " (info): Source format.........: " sourceFormat
            display MODULE-ID " (info): Quote Character.......: " quoteCharacter
        end-if
    end-if.

*>------------------------------------------------------------------------------    
*> Read arguments from command-line and sets the proper running option
*>------------------------------------------------------------------------------    
11-read-command-line.

    display argumentNumber upon argument-number
    accept argumentText from argument-value
    evaluate argumentText
        when "-s" set argumentIs-s to true
        when "-o" set argumentIs-o to true
        when "-i" set argumentIs-i to true
        when "-f" set argumentIs-f to true
                  set sourceFormatIsFixed to true
        when "-q" set argumentIs-q to true
                  move '"' to quoteCharacter        
        when "-v" set argumentIs-v  to true
                  set runningModeIsVerbose to true
        when other
            if argumentIs-s        
                move argumentText to inputSourceFileName
                set argumentIs-s to false
            else    
                if argumentIs-o
                    move argumentText to outputSourceFileName
                    set argumentIs-o to false
                else    
                    if argumentIs-i
                        add 1 to copybookDirCount
                        if copybookDirCount > copybookDirMax
                            display MODULE-ID " (ERROR): More than " copybookDirMax " copybook directories were informed." upon stderr
                            set thereWasAnError to true
                            exit paragraph
                        end-if
                        move argumentText to copybookDirName(copybookDirCount)
                        *> Any additional directories informed after -i will be added to the internal table.
                        *> That's why there is not set to false here.
                    else
                        display MODULE-ID " (ERROR): Unexpected argument " trim(argumentText) upon stderr
                        set thereWasAnError to true
                        exit paragraph
                    end-if
                end-if
            end-if
    end-evaluate.
    
*>------------------------------------------------------------------------------    
*> Open input and output source programs
*>------------------------------------------------------------------------------    
2-open-sources.

    open input inputSource
    if inputSourceNotFound
        display MODULE-ID " (ERROR): Program " trim(inputSourceFileName) " not found" upon stderr
        set thereWasAnError to true
        exit paragraph
    else    
        if inputSourceFileStatus not = "00"
            display MODULE-ID " (ERROR): Opening program " trim(inputSourceFileName) " failed with file-status " inputSourceFileStatus upon stderr
            set thereWasAnError to true
            exit paragraph
        else
            if runningModeIsVerbose
                display MODULE-ID " (info): Opening input program " trim(inputSourceFileName) 
            end-if
        end-if            
    end-if

    open output outputSource
    if inputSourceFileStatus not = "00"
        display MODULE-ID " (ERROR): Opening program " trim(outputSourceFileName) " failed with file-status " outputSourceFileStatus upon stderr
        set thereWasAnError to true
        exit paragraph
    else
        if runningModeIsVerbose
            display MODULE-ID " (info): Opening output program " trim(inputSourceFileName)
        end-if
    end-if.

*>------------------------------------------------------------------------------    
*> SQL Statements will be translated and saved in a temporary file so it can be
*> joined to the output source in a later step
*>------------------------------------------------------------------------------    
3-split-sql-statements.

    perform 31-look-for-exec-sql

    if weFoundBeginDeclareSection
        perform 32-insert-sql-additional-variables
    else
        if weFoundInclude
            perform 33-expand-copybook
        else
            if weFoundSelectInto
                perform 34-translate-select-into
            else    
                if weFoundDeclareCursor
                    perform 35-translate-declare-cursor
                else
                    if weFoundOpenCursor
                        perform 36-translate-open-cursor
                    else
                        if weFoundFetchCursor
                            perform 37-translate-fetch-cursor
                        else
                            if weFoundUpdate
                                perform 38-translate-update
                            else
                                if weFoundInsert
                                    perform 39-translate-insert
                                else
                                    if weFoundDelete
                                        perform 3a-translate-delete
                                    end-if
                                end-if
                            end-if
                        end-if
                    end-if
                end-if
            end-if
        end-if
    end-if

    perform 31-find-begin-declare-section
    if thereWasAnError
        display MODULE-ID " (ERROR): Begin Declare Section not found"
        exit paragraph

    
*>------------------------------------------------------------------------------    
*> Close input and output program
*>------------------------------------------------------------------------------    
4-close-sources.

    close inputSource 
    if runningModeIsVerbose
        display MODULE-ID " (info): Closing input program " trim(inputSourceFileName)
    end-if

    close outputSource
    if runningModeIsVerbose
        display MODULE-ID " (info): Closing output program " trim(outputSourceFileName)
    end-if.
            
   