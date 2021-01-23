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
    03 copybookDirMax           pic 9(002)  comp-5 value 20.
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

01 subprograms.
    03 presqlExpand             pic x(030)  value "presqlExpand".
    03 presqlHostVariables      pic x(030)  value "presqlHostVariables".

01 expandResults.
    03 expandedSourceFileName   pic x(255)  value spaces.
    03 returnCode               pic 9(001)  value zeros.
        88 everythingWasFine    value 0     false 1.
        88 somethingWentWrong   value 1     false 0.

01 hostVariablesResults.
    03 hostVariablesFileName    pic x(255)  value spaces.
    03 returnCode               pic 9(001)  value zeros.
        88 everythingWasFine    value 0     false 1.
        88 somethingWentWrong   value 1     false 0.

*>===============================================================================
procedure division.
*>===============================================================================
0-main.

    perform 1-get-arguments
    if itIsOkSoFar    
        perform 2-run-the-job
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
            display MODULE-ID " (info): Copybook Directories..:" 
            perform varying copybookDirCount from 1 by 1 until copybookDirCount > copybookDirMax
                if copybookDirName(copybookDirCount) not = spaces
                    display "    (" copybookDirCount ") " trim(copybookDirName(copybookDirCount))
                end-if
            end-perform
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
*> The precompiling process is done by several small subprograms
*>------------------------------------------------------------------------------    
2-run-the-job.

    *> Expand the includes inside declare section
    call presqlExpand using sourceFileControls, runningOptions, copybookControls, expandResults
    if somethingWentWrong in expandResults
        display MODULE-ID " (ERROR): Something went wrong when trying to expand includes" upon stderr
        set thereWasAnError to true
        exit paragraph
    else

    move expandedSourceFileName to inputSourceFileName
    
    *> Generates a table with the host variables
    call presqlHostVariables using sourceFileControls, runningOptions, hostVariablesResults
    if somethingWentWrong in hostVariablesResults
        display MODULE-ID " (ERROR): Something went wrong when trying to extract host variables" upon stderr
        set thereWasAnError to true
        exit paragraph
    end-if.

