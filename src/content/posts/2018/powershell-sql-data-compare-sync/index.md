---
title: "Syncing database data with PowerShell and  SQL Data Compare"
date: 2018-08-17T20:41:00+00:00
tags: ["powershell", "SQL", "redgate-sql-data-compare"]
author: "Me"
showToc: false
TocOpen: false
draft: false
hidemeta: true
comments: false
# url: powershell-sql-data-compare-sync
type: posts

resources:
- src: 'enumtable.png'
---

The database team at my current job had successfully integrated the databases into source control using [Redgate SQL Source Control](https://www.red-gate.com/products/sql-development/sql-source-control/). Developers now have a local instance of the databases linked to Source Control and for them to add or change things it's a breeze.

The "adding databases into source control" statement is comprised of basically adding all the objects to source control. E.g. Tables, Views, Procedures and so on. Apart from adding database objects, there were also a couple of Tables identified as "Enum" tables. These tables are those that all of us developers are very familiar with. They usually contain lookup data, like Statuses and Countries.

{{< img "*enumtable*" "An example of an Enum table" >}}

**The problem started here**: We have several data centers and these enum data should be, of course, the same everywhere. At this point, when someone wanted a new value available in production, they would add it, `commit` and `push`. Then, open a ticket with the database team so they could deploy the new value everywhere. As you are probably thinking, this is.. let's say, not very efficient.

To solve that we built a tool to manage this set of Enum/Configuration data. This tool is responsible for creating and sending this data everywhere. This was great since our tool now synchronizes the changes to all production db's and to one internal "master". This improved drastically the productivity for everyone. 

But, there was one downside: The developer's local instances were now outdated!. Since the enum tables are now managed by an external tool, there was no need to keep them in source control. And if they are not in source control developers can't just do `git pull` and expect to get the data anymore.


## The solution

Use Redgate SQL Data Compare! Maybe not everyone knows but SQL Data Compare also works via the [command line](https://documentation.red-gate.com/sdc13/using-the-command-line). Basically everything you can do using the UI you can do using the command line, which is awesome!

### Our requirements:

1. Develop a solution that works seamlessly and that requires minimal effort from the developers
2. That would be easy to change once more Enum tables are removed from source control


Having that in mind, what we came up was: A **PowerShell** script that uses SQL Data Compare to "sync" the dev's local instance with the master database managed by our central tool.

### Challenges:

The PowerShell script more or less solved requirement **#1**. Developers would still have to run the script, but that can be easily solved by scheduling a task on Windows Task Scheduler. So requirement 1 - Solved!

Requirement **#2** was a little more tricky though. Summarizing, we had to compare 3 databases and each had different configurations (which Table to compare and so on). Also important was: As we take more Enum data out of source control, we needed a way to easily add the new tables in the comparison so developers could get fresh data again.

Fortunately, SQL Data Compare command line offers a way to use a `.xml` file to specify the parameters and configuration relevant to each database. There's a nice documentation with a few examples on how to [use XML to specify command line arguments](https://documentation.red-gate.com/sdc13/using-the-command-line/examples-using-the-command-line/using-xml-to-specify-command-line-arguments)

We took leverage of the `.xml` configuration files and created one for each database we needed to compare. This is nice because:

1. You can (and should!) put it on source control. So changes are made in a safe way
2. It separates each database with its own set of configurations and tables
3. Allows the PowerShell script to be "generic" and database agnostic.


## Code:

Basically the PowerShell script accepts just one argument. The name of the `.xml` configuration file. An example of such configuration file looks like this:

```xml
<?xml version="1.0"?> 
<commandline>
    <database1>myapp-db</database1>
    <server1>DB-MASTER</server1>
    <database2>myapp-db</database2>
    <server2>(local)\DevInstance</server2>
    <verbose/>
    <include>Table</include>
    <include>Identical</include>
    <include>Table:\[AppStatus\]</include>
    <sync/>
</commandline>
```

I'm not going into too much details of what each node do since the documentation already offers everything you need to know: [Switches used in the command line](https://documentation.red-gate.com/sdc13/using-the-command-line/command-line-syntax/switches-used-in-the-command-line) and [Options used in the command line](https://documentation.red-gate.com/sdc13/using-the-command-line/command-line-syntax/options-used-in-the-command-line)

### The final script looks like this:

```shell
param (   
    [Parameter(Mandatory = $true)]
    [string]
    $compareConfigFile
)

<# Get the Installation path of a given program
Gladly copied from: 
https://info.sapien.com/index.php/scripting/scripting-how-tos/how-to-find-installation-directory 
#> 
function Get-InstallPath
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [SupportsWildcards()]
        [string]
        $ProgramName
    )
    
    $result = @()
    if ($inst = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\*\Products\*\InstallProperties" -ErrorAction SilentlyContinue) 
    {
        $inst | Where-Object {
            ($DisplayName = $_.getValue('DisplayName')) -like "*$ProgramName*"
        } |
        ForEach-Object     {
            $result += [PSCustomObject]@{
                'DisplayName' = $displayName
                'Publisher' = $_.getValue('Publisher')
                'InstallPath' = $_.getValue('InstallLocation')
            }
        }
    }
    else
    {
        Write-Error "Cannot get the InstallProperties registry keys.";
    }
    
    if ($result)
    {
        return $result;
    }
    else
    {
        Write-Error "Cannot get the InstallProperties registry key for $ProgramName";
    }
}

try {

    if (!(Test-Path $compareConfigFile)) 
    {
        Throw "Could not find the specified xml config file: $compareConfigFile";
    }

    Write-Host "################ Initilizing SQL Data Compare Script #################";
    Write-Host "";

    Write-Host "Info: " -ForegroundColor Blue -NoNewline; Write-Host "Looking for SQL Data Compare on the machine...";
    $sqlDataCompareFolderName = "SQL Data Compare";
    $sqlDataCompareExecutableName = "SQLDataCompare.exe";
    
    # Gets the installation path from registry for SQL Data Compare (the version number at the end makes impossible to hardcode)
    $sqlCompareInstallPath = (Get-InstallPath -ProgramName $sqlDataCompareFolderName).InstallPath;
    $fullExecutablePath = Join-Path -path $sqlCompareInstallPath -childpath $sqlDataCompareExecutableName;

    # Should be there, but just as a sanity check
    if (!(Test-Path  "$fullExecutablePath")) 
    {
        Throw "SQL Data Compare was not found in the machine.";
    }

    Write-Host "Success: " -ForegroundColor Green -NoNewline; Write-Host "SQL Data Compare found at: $fullExecutablePath";
    Write-Host "";

    Write-Host "Info: " -ForegroundColor Blue -NoNewline; Write-Host "Starting SQL Data Compare using the following XML config file: $compareConfigFile";    
    Write-Host "";

    & "$fullExecutablePath" /Argfile:$compareConfigFile;

    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "Database updated successfully." -ForegroundColor Green;
    }
    else 
    {
        Write-Host "Error: Database updated failed. See the above errors. " -ForegroundColor Red;        
    }
}

Catch {
    $ErrorMessage = $_;
    Write-Output $ErrorMessage;
    exit 1;
}
```

One problem I had to solve was: The SQL Data Compare installation folder contains the version number at the end: `C:\Program Files (x86)\Red Gate\SQL Data Compare 13`. This makes it hard to find the `SQLDataCompare.exe` because I can't guarantee which version is installed. 

That's what the function `Get-InstallPath` solves: it looks at the Windows Registry and tries to find the installation path for `SQL Data Compare`. Note that I used `-like "*$ProgramName*"` to solve the version problem on the installation folder. I gladly copied and slightly adapted the code from [June Blender's](https://twitter.com/juneb_get_help) Blog post: [How to find an installation directory](https://info.sapien.com/index.php/scripting/scripting-how-tos/how-to-find-installation-directory)

The rest is pretty straightforward. It calls the function and checks if SQL Data Compare is installed on the machine. Then it validates if the `.xml` file provided exists. Finally at line `83` it invokes `SQLDataCompare.exe` passing the path to the `.xml` file. 

And that's it! You have an updated database again :)


**Disclosure 1**: This was the solution that was the fastest to build and that brought immediate value to us. It might not be the most perfect one though. In the end, we had to choose the approach that [would bring the most value with minimal efforts](https://www.codeproject.com/Articles/824234/Pareto-Programming). Also, I'm  a PowerShell noob so please,  if you find something that can be improved let me know in the comments! 

**Disclosure 2**: This post is basically about Redgate SQL Data Compare but this is not a promoted post nor I'm benefiting from it. We already use their products in our office and this was just a way of sharing our use case.

Hope this was helpful.
