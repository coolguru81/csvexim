#File to log all script execution errors
$error_log = "error.txt"

#File to log all sqlcmd execution errors
$sql_error_log = "sql_error.txt"

#Directory to store all .sql script files
$scripts_dir = "Scripts"

#Directory where all .csv exports are created
$output_dir = "Output"

#Defines the scripts working directory - It can be fully qualified path like c:\data\
$working_dir = ".\"

#Define the shared folder path where copy of output files need to be made
$shared_path = "\\localhost\E$\test"

#SQL Server connection parameters
#SQL Server instance name
$sql_servername = "localhost\SQLExpress"
#SQL Server instance port
$sql_port = 1433

#SQLCMD process executable.
$process = "sqlcmd.exe"

#Function to write log
function Write-Log{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String]
        $Message
    )
    $timestamp = Get-Date   
    Add-Content $error_log "$($timestamp):$($Message)"
}

#Function that actually executes SQLCMD and creates CSV export
function Start-DataExtraction{
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ScriptFilePath,
        [Parameter(Mandatory=$true)]
        [String]
        $OutputFilePath
    )
    $Error.Clear()
    Write-Log "Attempting execution of script $($ScriptFilePath)..."

    #Build argument list for sqlcmd
    $argument_list = "-E -S $($sql_servername),$($sql_port) -i $($ScriptFilePath) -o $($OutputFilePath) -w 1024 -W -h -1 -s,"

    Write-Log "Starting $($process) with arguments: $($argument_list)"

    Start-Process -FilePath $process -ArgumentList $argument_list -RedirectStandardError $sql_error_log

    if($Error)
    {
        Write-Log "Error occured"
        $Error | ForEach-Object { Write-Log $_.ToString()}
    }
    else{
        Write-Log "Output file $($OutputFilePath) generated."
    }
     
}

#Function that serves as a starting point for data processing. This discovers SQL Scripts
#and executes SQLCMD for each script
function Start-DataProcessing{

    Write-Log "Processing started..."
    
    #check if script directory exists
    if(!(Test-Path -Path $scripts_dir))
    {
        Write-Log "Scripts directory does not exist. Create $($scripts_dir) directory inside $($working_dir) directory. Aborting processing."
        return        
    }
    #check if script contains .sql files
    $scripts_list = Get-ChildItem -Path $scripts_dir -Filter "*.sql"

    if($scripts_list.Count -eq 0 )
    {
        Write-Log "No sql scripts present in $($scripts_dir) directory. Aborting processing."
        return        
    }
    #check if script directory exists
    if(!(Test-Path -Path $output_dir))
    {
        Write-Log "Output directory does not exist. Create $($output_dir) directory inside $($working_dir) directory. Aborting processing."
        return        
    }

    Write-Log "Scripts found - $($scripts_list.Count). Starting data extraction..."

    #for each script run sqlcmd and populate output in csv
    foreach ($script_name in $scripts_list) {
        #Create fully qualified script path
        $scriptFilePath = Join-Path -Path (Join-Path -Path $working_dir -ChildPath $scripts_dir) -ChildPath $script_name

        #Capturing current timestamp
        $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")

        #Create a unique output file name
        $output_filename = "$($script_name.ToString().Split('.')[0])_$($timestamp).csv"

        #Create fully qualified output file path
        $outputFilePath = Join-Path -Path (Join-Path -Path $working_dir -ChildPath $output_dir) -ChildPath $output_filename

        #Invoke data extraction function with script and output paths
        Start-DataExtraction -ScriptFilePath $scriptFilePath -OutputFilePath $outputFilePath
    }

    Write-Log "Processing ended."
}

#Function to copy output files from output dir to shared folder
function Start-FileCopy{
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $OutputFilePath,
        [Parameter(Mandatory=$true)]
        [String]
        $SharedPath
    )

    Write-Log "Starting copy of files from $($OutputFilePath) to $($SharedPath)"

    #check if output file path contains any .csv files
    $output_file_list = Get-ChildItem -Path $OutputFilePath -Filter "*.csv"

    if($output_file_list.Count -eq 0 )
    {
        Write-Log "No csv files present in $($OutputFilePath) directory. Aborting copy."
        return        
    }

    #check if shared path is valid
    if(!(Test-Path -Path $SharedPath))
    {
        Write-Log "$($SharedPath) is not valid or accessible. Aborting copy."
        return        
    }
    else{
        Write-Log "$($output_file_list.Count) csv files found in output path."
    }

    #All valid. Copy each file and delete in output if copy successful
    foreach($output_file in $output_file_list){
        $Error.Clear()
        #Generate fully qualified output file path
        $output_file_path = Join-Path -Path $OutputFilePath -ChildPath $output_file

        Write-Log "Starting copy of $($output_file_path) to $($SharedPath)"

        #Copy the file to shared path
        Copy-Item -Path $output_file_path -Destination $SharedPath

        if($Error){
            Write-Log "Error occured while copying $($output_file_path) to $($SharedPath)"
        }
        else{
            Write-Log "Successfully copied $($output_file_path) to $($SharedPath)"
            
            #Delete the output file
            Remove-Item -Path $output_file_path
        }
    }

}

#Starting point that invokes the entire process
Start-DataProcessing

#Introducing a time delay to let file creation finish
Start-Sleep -Seconds 30

#Start Copying files to shared path
$outputFilePath = Join-Path -Path $working_dir -ChildPath $output_dir

Start-FileCopy -OutputFilePath $outputFilePath -SharedPath $shared_path

    